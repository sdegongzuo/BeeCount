import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/fast_billing_rule_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/billing/rules/billing_rule_storage.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late BillingRuleStorage storage;
  late _StringAssetBundle assets;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('runtime_rules_');
    storage = BillingRuleStorage(directory);
    assets = _StringAssetBundle({
      TomlBillingRuleRepository.defaultBuiltInAssetPath:
          _rules('built-in', marker: '内置规则'),
    });
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('存储对象统一声明活动、上一版与原子切换临时路径', () {
    expect(
        storage.activeFile.path, endsWith(BillingRuleStorage.activeFileName));
    expect(storage.previousFile.path,
        endsWith(BillingRuleStorage.previousFileName));
    expect(
        storage.pendingFile.path, endsWith(BillingRuleStorage.pendingFileName));
  });

  test('默认生产存储位于 application documents 且默认更新回调立即失效缓存', () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return directory.path;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final productionStorage = await productionBillingRuleStorage();
    expect(productionStorage.directory.path,
        '${directory.path}${Platform.pathSeparator}rules');
    await productionStorage.directory.create(recursive: true);
    final repository = productionBillingRuleRepository();
    expect((await repository.loadActiveRuleSet()).rulesVersion, '2026.07.06.2');
    final remote = _rules('production-v1', marker: '生产新规则');
    final updater = BillingRuleUpdateService(
      configuration: _testUpdateConfiguration,
      manifestLoader: (_) async => _manifest('production-v1', remote),
      rulePackageDownloader: (_) async => remote,
      smokeTest: (_) async => true,
      upgradeEvaluation: (_) async => true,
      personalRegression: (_) async =>
          const BillingRulePersonalRegressionResult.passed(),
      personalRuleArchiver: (_) async {},
    );

    expect((await updater.checkForUpdate()).status,
        BillingRuleUpdateStatus.activated);
    expect(
        (await repository.loadActiveRuleSet()).rulesVersion, 'production-v1');
  });

  test('活动快照常驻内存，显式失效后下一次读取立即切换', () async {
    await storage.activeFile.writeAsString(_rules('v1', marker: '版本一'));
    final repository = _repository(storage, assets);

    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v1');
    await storage.activeFile.writeAsString(_rules('v2', marker: '版本二'));
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v1');

    repository.invalidateActiveSnapshot();
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v2');
  });

  test('生产仓库工厂在同一进程返回唯一实例', () {
    expect(
      identical(
        productionBillingRuleRepository(),
        productionBillingRuleRepository(),
      ),
      isTrue,
    );
  });

  test('新进程仓库读取已激活文件，损坏时依次回退上一版和内置规则', () async {
    await storage.activeFile.writeAsString(_rules('v2', marker: '版本二'));
    expect(
        (await _repository(storage, assets).loadActiveRuleSet()).rulesVersion,
        'v2');

    await storage.previousFile.writeAsString(_rules('v1', marker: '版本一'));
    await storage.activeFile.writeAsString('not = [valid');
    expect(
        (await _repository(storage, assets).loadActiveRuleSet()).rulesVersion,
        'v1');

    await storage.previousFile.writeAsString('schemaVersion = 999');
    expect(
        (await _repository(storage, assets).loadActiveRuleSet()).rulesVersion,
        'built-in');
  });

  test('更新服务激活后自动失效缓存，生产 BillingJob 规则链处理下一张图片', () async {
    await storage.activeFile.writeAsString(_rules('v1', marker: '版本一'));
    final repository = _repository(storage, assets);
    final database = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final service = BillingJobService.createProductionRuleService(
      database,
      publicRuleRepository: repository,
    );

    expect((await _evaluate(service, '版本一')).result.amount, 1);

    final remote = _rules('v2', marker: '版本二');
    final updater = BillingRuleUpdateService(
      ruleStorage: storage,
      configuration: _testUpdateConfiguration,
      onActiveSnapshotChanged: repository.invalidateActiveSnapshot,
      manifestLoader: (_) async => jsonEncode({
        'latest': {
          'schemaVersion': 1,
          'rulesVersion': 'v2',
          'minAppVersion': '0.0.1',
          'url': 'https://rules.test/v2.toml',
          'sha256': sha256.convert(utf8.encode(remote)).toString(),
        },
      }),
      rulePackageDownloader: (_) async => remote,
      smokeTest: (_) async => true,
      upgradeEvaluation: (_) async => true,
      personalRegression: (_) async =>
          const BillingRulePersonalRegressionResult.passed(),
      personalRuleArchiver: (_) async {},
    );

    expect((await updater.checkForUpdate()).status,
        BillingRuleUpdateStatus.activated);
    expect((await _evaluate(service, '版本二')).result.amount, 1);
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v2');
  });

  test('回滚后同一运行时仓库立即读取上一版安全快照', () async {
    await storage.activeFile.writeAsString(_rules('v2', marker: '版本二'));
    await storage.previousFile.writeAsString(_rules('v1', marker: '版本一'));
    final repository = _repository(storage, assets);
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v2');

    final updater = BillingRuleUpdateService(
      ruleStorage: storage,
      configuration: _testUpdateConfiguration,
      onActiveSnapshotChanged: repository.invalidateActiveSnapshot,
      upgradeEvaluation: (_) async => true,
      personalRegression: (_) async =>
          const BillingRulePersonalRegressionResult.passed(),
      personalRuleArchiver: (_) async {},
    );

    expect(
        (await updater.rollback()).status, BillingRuleUpdateStatus.rolledBack);
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'v1');
  });

  test('首次激活后个人规则归档失败会恢复无 active 的内置快照', () async {
    final repository = _repository(storage, assets);
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'built-in');
    final remote = _rules('v1', marker: '版本一');
    final updater = BillingRuleUpdateService(
      ruleStorage: storage,
      configuration: _testUpdateConfiguration,
      onActiveSnapshotChanged: repository.invalidateActiveSnapshot,
      manifestLoader: (_) async => _manifest('v1', remote),
      rulePackageDownloader: (_) async => remote,
      smokeTest: (_) async => true,
      upgradeEvaluation: (_) async => true,
      personalRegression: (_) async =>
          const BillingRulePersonalRegressionResult.passed(
        equivalentPersonalRuleIds: ['personal-1'],
      ),
      personalRuleArchiver: (_) async => throw StateError('db busy'),
      personalRuleReconciliationVerifier: (_, __) async => false,
    );

    final result = await updater.checkForUpdate();

    expect(result.status, BillingRuleUpdateStatus.failed);
    expect(result.message, contains('built-in snapshot restored'));
    expect(await storage.activeFile.exists(), isFalse);
    expect(await storage.pendingFile.exists(), isFalse);
    expect(
      storage.directory
          .listSync()
          .whereType<File>()
          .any((file) => file.path.contains('.uncommitted-candidate.')),
      isTrue,
    );
    expect((await repository.loadActiveRuleSet()).rulesVersion, 'built-in');
  });
}

String _manifest(String version, String toml) => jsonEncode({
      'latest': {
        'schemaVersion': 1,
        'rulesVersion': version,
        'minAppVersion': '0.0.1',
        'url': 'https://rules.test/$version.toml',
        'sha256': sha256.convert(utf8.encode(toml)).toString(),
      },
    });

final _testUpdateConfiguration = BillingRuleUpdateConfiguration.fromValues(
  manifestUrl: 'https://rules.test/manifest.json',
  currentAppVersion: '1.0.0',
);

RuntimeBillingRuleRepository _repository(
        BillingRuleStorage storage, AssetBundle assets) =>
    RuntimeBillingRuleRepository(
      storageLoader: () async => storage,
      assetBundle: assets,
    );

Future<FastBillingRuleEvaluation> _evaluate(
        FastBillingRuleService service, String marker) =>
    service.evaluate(
      baseResult:
          OcrResult(rawText: '$marker\n金额\n1.00', allNumbers: const ['1.00']),
    );

String _rules(String version, {required String marker}) => '''
schemaVersion = 1
rulesVersion = "$version"

[[templates]]
id = "rule-$version"
baseConfidence = 0.95

[templates.match]
keywordsAll = ["$marker"]

[[templates.extract]]
field = "amount"
type = "labelNextLine"
label = "金额"
parser = "amount"
confidence = 0.95

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "测试"
confidence = 0.95
''';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      assets[key]!;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}
