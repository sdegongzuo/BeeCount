import 'dart:convert';
import 'dart:io';

import 'package:beecount/providers/billing_rule_update_providers.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/billing/rules/billing_rule_storage.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductionBillingRuleUpdateGateway', () {
    late Directory tempDir;
    late BillingRuleStorage storage;
    late RuntimeBillingRuleRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rule_gateway_test_');
      storage = BillingRuleStorage(tempDir);
      repository = RuntimeBillingRuleRepository(
        storageLoader: () async => storage,
      );
    });

    ProductionBillingRuleUpdateGateway gatewayFor(
      BillingRuleUpdateConfiguration configuration, {
      BillingRuleManifestLoader? manifestLoader,
      BillingRulePackageDownloader? packageDownloader,
      BillingRuleSmokeTest? smokeTest,
      BillingRuleUpgradeEvaluation? goldenEvaluation,
      BillingRulePersonalRegression? personalRegression,
      BillingRuleUpdateClock? clock,
    }) {
      final service = BillingRuleUpdateService(
        ruleStorage: storage,
        configuration: configuration,
        manifestLoader: manifestLoader,
        rulePackageDownloader: packageDownloader,
        smokeTest: smokeTest,
        upgradeEvaluation: goldenEvaluation ?? (_) async => true,
        personalRegression: personalRegression ??
            (_) async => const BillingRulePersonalRegressionResult.passed(),
        personalRuleArchiver: (_) async {},
        onActiveSnapshotChanged: repository.invalidateActiveSnapshot,
        clock: clock,
      );
      return ProductionBillingRuleUpdateGateway(
        configuration: configuration,
        service: service,
        publicRepository: repository,
        storage: storage,
      );
    }

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('禁用配置经生产网关手动检查仍然零网络访问', () async {
      await storage.activeFile.writeAsString(_validToml('active'));
      var networkCalls = 0;
      final configuration = BillingRuleUpdateConfiguration.fromValues(
        manifestUrl: '',
        currentAppVersion: '1.0.0',
      );
      final gateway = gatewayFor(
        configuration,
        manifestLoader: (_) async {
          networkCalls++;
          return '';
        },
      );

      final result = await gateway.checkNow();
      final diagnostics = await gateway.diagnostics();

      expect(result.status, BillingRuleUpdateStatus.disabled);
      expect(networkCalls, 0);
      expect(diagnostics.activeVersion, 'active');
      expect(diagnostics.lastCheckStatus, BillingRuleUpdateStatus.disabled);
    });

    test('生产网关手动检查依次通过基础、黄金和个人回归门禁', () async {
      await storage.activeFile.writeAsString(_validToml('active'));
      final remote = _validToml('remote');
      final events = <String>[];
      final configuration = _enabledConfiguration();
      final gateway = gatewayFor(
        configuration,
        manifestLoader: (_) async => _manifest(remote),
        packageDownloader: (_) async => remote,
        smokeTest: (_) async {
          events.add('smoke');
          return true;
        },
        goldenEvaluation: (_) async {
          events.add('golden');
          return true;
        },
        personalRegression: (_) async {
          events.add('personal');
          return const BillingRulePersonalRegressionResult.passed();
        },
      );

      final result = await gateway.checkNow();
      final diagnostics = await gateway.diagnostics();

      expect(result.status, BillingRuleUpdateStatus.activated);
      expect(events, ['smoke', 'golden', 'personal']);
      expect(diagnostics.activeVersion, 'remote');
      expect(diagnostics.lastCheckStatus, BillingRuleUpdateStatus.activated);
    });

    test('损坏的 previous 经生产诊断禁止回滚', () async {
      await storage.activeFile.writeAsString(_validToml('active'));
      await storage.previousFile.writeAsString('not valid toml');
      final gateway = gatewayFor(_enabledConfiguration());

      final diagnostics = await gateway.diagnostics();

      expect(diagnostics.previousVersion, isNull);
      expect(diagnostics.diskStateVerified, isFalse);
      expect(diagnostics.canRollback, isFalse);
    });

    test('resume 自动检查经生产网关遵守失败短退避并恢复重试', () async {
      await storage.activeFile.writeAsString(_validToml('active'));
      var now = DateTime.utc(2026, 7, 17, 10);
      var networkCalls = 0;
      final gateway = gatewayFor(
        _enabledConfiguration(),
        clock: () => now,
        manifestLoader: (_) async {
          networkCalls++;
          throw const SocketException('offline');
        },
      );

      expect(
        (await gateway.checkIfDue()).status,
        BillingRuleUpdateStatus.failed,
      );
      expect(
        (await gateway.checkIfDue()).status,
        BillingRuleUpdateStatus.notDue,
      );
      now = now.add(const Duration(minutes: 16));
      expect(
        (await gateway.checkIfDue()).status,
        BillingRuleUpdateStatus.failed,
      );
      expect(networkCalls, 2);
    });
  });
}

BillingRuleUpdateConfiguration _enabledConfiguration() =>
    BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: 'https://rules.test/manifest.json',
      currentAppVersion: '1.0.0',
    );

String _manifest(String toml) => jsonEncode({
      'latest': {
        'schemaVersion': 1,
        'rulesVersion': 'remote',
        'minAppVersion': '0.0.1',
        'url': 'https://rules.test/remote.toml',
        'sha256': sha256.convert(utf8.encode(toml)).toString(),
      },
    });

String _validToml(String version) => '''
schemaVersion = 1
rulesVersion = "$version"

[[templates]]
id = "gateway_rule"
enabled = true
priority = 100

[templates.match]
keywordsAll = ["金额"]

[[templates.extract]]
field = "amount"
type = "regex"
pattern = '\\d+(?:\\.\\d{1,2})?'
parser = "signedAmount"
''';
