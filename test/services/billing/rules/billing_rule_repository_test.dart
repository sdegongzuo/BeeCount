import 'dart:io' show File;

import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TomlBillingRuleRepository', () {
    test('loads built-in TOML asset as a validated rule set', () async {
      final repository = TomlBillingRuleRepository();

      final ruleSet = await repository.loadBuiltInRuleSet();

      expect(ruleSet.schemaVersion, 1);
      expect(ruleSet.rulesVersion, '2026.07.06.2');
      expect(ruleSet.source, 'asset:assets/rules/billing_rules.toml');
      expect(ruleSet.paymentChannels.map((channel) => channel.channel),
          containsAll(['微信支付', '抖音', '支付宝']));
      expect(
        ruleSet.paymentChannels
            .firstWhere((channel) => channel.channel == '微信支付')
            .packages,
        ['com.tencent.mm'],
      );
      final wechatTemplate = ruleSet.templates
          .firstWhere((template) => template.id == 'wechat_payment_detail_v1');
      expect(wechatTemplate.match.keywordsAll, contains('交易单号'));
      expect(ruleSet.templates.map((template) => template.id),
          contains('douyin_payment_detail_v1'));
      expect(ruleSet.templates.map((template) => template.id),
          contains('alipay_payment_detail_v1'));
      expect(
        wechatTemplate.extractors.map((rule) => rule.field),
        containsAll([
          'amount',
          'paymentChannel',
          'time',
          'merchantFullName',
          'paymentMethod',
          'details.transaction_no',
        ]),
      );
    });

    test('falls back to previous local rules when active rules are invalid',
        () async {
      final activeFile = _RuleFile('active.toml');
      final previousFile = _RuleFile('previous.toml');
      final repository = TomlBillingRuleRepository(
        activeRuleFile: activeFile,
        previousRuleFile: previousFile,
        fileLoader: _memoryRuleLoader({
          activeFile.path: _tomlWith('schemaVersion = 999'),
          previousFile.path: _validToml(rulesVersion: 'local.previous'),
        }),
      );

      final ruleSet = await repository.loadActiveRuleSet();

      expect(ruleSet.rulesVersion, 'local.previous');
      expect(ruleSet.source, previousFile.path);
    });

    test('falls back to built-in rules when active local rules are invalid',
        () async {
      final activeFile = _RuleFile('active.toml');
      final repository = TomlBillingRuleRepository(
        activeRuleFile: activeFile,
        assetBundle: _StringAssetBundle({
          TomlBillingRuleRepository.defaultBuiltInAssetPath:
              _validToml(rulesVersion: 'built.in'),
        }),
        fileLoader: _memoryRuleLoader({
          activeFile.path: _tomlWith('schemaVersion = 999'),
        }),
      );

      final ruleSet = await repository.loadActiveRuleSet();

      expect(ruleSet.rulesVersion, 'built.in');
      expect(
        ruleSet.source,
        'asset:${TomlBillingRuleRepository.defaultBuiltInAssetPath}',
      );
    });

    test('uses debug override rules before active local rules', () async {
      final debugFile = _RuleFile('debug.toml');
      final activeFile = _RuleFile('active.toml');
      final repository = TomlBillingRuleRepository(
        debugOverrideRuleFile: debugFile,
        activeRuleFile: activeFile,
        fileLoader: _memoryRuleLoader({
          debugFile.path: _validToml(rulesVersion: 'debug.override'),
          activeFile.path: _validToml(rulesVersion: 'active.local'),
        }),
      );

      final ruleSet = await repository.loadActiveRuleSet();
      final debugRuleSet = await repository.loadDebugOverrideRuleSet();

      expect(ruleSet.rulesVersion, 'debug.override');
      expect(ruleSet.source, debugFile.path);
      expect(debugRuleSet?.rulesVersion, 'debug.override');
    });

    test('rejects invalid schema version', () async {
      final repository = _repositoryFor(_tomlWith('schemaVersion = 2'));

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });

    test('rejects duplicate template ids', () async {
      final repository = _repositoryFor('''
schemaVersion = 1
rulesVersion = "test"

[[templates]]
id = "duplicate"

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"

[[templates]]
id = "duplicate"

[[templates.extract]]
field = "amount"
type = "regex"
pattern = '\\d+'
''');

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });

    test('rejects invalid field paths', () async {
      final repository = _repositoryFor(
        _tomlWith('field = "details.transaction.no"'),
      );

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });

    test('rejects unknown extractor types', () async {
      final repository = _repositoryFor(_tomlWith('type = "script"'));

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });

    test('rejects unknown parsers', () async {
      final repository = _repositoryFor(_tomlWith('parser = "eval"'));

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });

    test('rejects invalid regex patterns', () async {
      final repository = _repositoryFor(_tomlWith("pattern = '['"));

      await expectLater(
        repository.loadBuiltInRuleSet(),
        throwsA(isA<BillingRuleRepositoryException>()),
      );
    });
  });
}

BillingRuleFileLoader _memoryRuleLoader(Map<String, String> files) {
  return (file) async => files[file.path];
}

TomlBillingRuleRepository _repositoryFor(String toml) {
  return TomlBillingRuleRepository(
    assetBundle: _StringAssetBundle({
      TomlBillingRuleRepository.defaultBuiltInAssetPath: toml,
    }),
  );
}

String _validToml({String rulesVersion = 'test'}) => '''
schemaVersion = 1
rulesVersion = "$rulesVersion"

[[paymentChannels]]
channel = "微信支付"
packages = ["com.tencent.mm"]
appNameKeywords = ["微信"]

[[templates]]
id = "wechat_payment_detail_v1"
enabled = true
priority = 100

[templates.match]
sourcePackages = ["com.tencent.mm"]
keywordsAll = ["当前状态", "支付时间", "交易单号"]

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"

[[templates.extract]]
field = "amount"
type = "regex"
pattern = '\\d+(?:\\.\\d{1,2})?'
parser = "signedAmount"

[[templates.extract]]
field = "details.transaction_no"
type = "labelNextLine"
label = "交易单号"
pattern = '\\d{20,}'
''';

String _tomlWith(String replacement) {
  final toml = _validToml();
  if (replacement.startsWith('schemaVersion')) {
    return toml.replaceFirst('schemaVersion = 1', replacement);
  }
  if (replacement.startsWith('field')) {
    return toml.replaceFirst('field = "paymentChannel"', replacement);
  }
  if (replacement.startsWith('type')) {
    return toml.replaceFirst('type = "constant"', replacement);
  }
  if (replacement.startsWith('parser')) {
    return toml.replaceFirst('parser = "signedAmount"', replacement);
  }
  return toml.replaceFirst(
    "pattern = '\\d+(?:\\.\\d{1,2})?'",
    replacement,
  );
}

class _StringAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _StringAssetBundle(this.assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Missing test asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }
}

class _RuleFile implements File {
  @override
  final String path;

  _RuleFile(this.path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
