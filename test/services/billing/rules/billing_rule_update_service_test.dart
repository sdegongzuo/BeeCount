import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/billing/rules/billing_rule_manifest.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingRuleManifest', () {
    test('parses latest remote rule metadata', () {
      final manifest = BillingRuleManifest.fromJson({
        'latest': {
          'schemaVersion': 1,
          'rulesVersion': '2026.07.04.1',
          'minAppVersion': '0.0.1',
          'url': 'https://example.com/rules.toml',
          'sha256': 'a' * 64,
        },
      });

      expect(manifest.latest.schemaVersion, 1);
      expect(manifest.latest.rulesVersion, '2026.07.04.1');
      expect(manifest.latest.minAppVersion, '0.0.1');
      expect(manifest.latest.url.toString(), 'https://example.com/rules.toml');
      expect(manifest.latest.sha256, 'a' * 64);
    });

    test('rejects unknown manifest schema versions', () {
      expect(
        () => BillingRuleManifest.fromJson({
          'latest': {
            'schemaVersion': 2,
            'rulesVersion': '2026.07.04.1',
            'minAppVersion': '0.0.1',
            'url': 'https://example.com/rules.toml',
            'sha256': 'a' * 64,
          },
        }),
        throwsA(isA<BillingRuleManifestException>()),
      );
    });
  });

  group('BillingRuleUpdateService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rule_update_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects hash mismatch without touching active rules', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: '0' * 64),
        remoteToml: remoteToml,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.hashMismatch);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
      expect(await File('${tempDir.path}/billing_rules.previous.toml').exists(),
          isFalse);
    });

    test('rejects invalid TOML without touching active rules', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = 'schemaVersion = 1\nrulesVersion = "broken"\n';
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.invalidRulePackage);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('rejects smoke test failure without touching active rules', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        smokeTest: (_) async => false,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.smokeTestFailed);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('requires golden evaluation and local personal regression', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      var regressionCalls = 0;
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        upgradeEvaluation: (_) async => false,
        personalRegression: (_) async {
          regressionCalls++;
          return const BillingRulePersonalRegressionResult.passed();
        },
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.goldenEvaluationFailed);
      expect(regressionCalls, 0);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('keeps old snapshot when a personal sample regresses', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.rejected(
          explanation: 'sample corrected-7 changed amount',
        ),
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.personalRegressionFailed);
      expect(result.message, contains('corrected-7'));
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('archives equivalent personal rules after activation', () async {
      final remoteToml = _validToml(rulesVersion: 'remote');
      List<String>? archived;
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.passed(
          equivalentPersonalRuleIds: ['personal-amount'],
          conflictExplanation: 'personal merchant rule retained',
        ),
        personalRuleArchiver: (ids) async => archived = ids,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.activated);
      expect(result.message, contains('personal merchant rule retained'));
      expect(archived, ['personal-amount']);
    });

    test('restores old public snapshot when equivalent archival fails',
        () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.passed(
          equivalentPersonalRuleIds: ['personal-amount'],
        ),
        personalRuleArchiver: (_) async => throw StateError('database busy'),
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('interruption before atomic switch leaves old snapshot active',
        () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        beforeAtomicSwitch: () => throw StateError('interrupted'),
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('network failure leaves old snapshot active', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final service = BillingRuleUpdateService(
        storageDirectory: tempDir,
        manifestLoader: (_) async => throw const SocketException('offline'),
        upgradeEvaluation: (_) async => true,
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.passed(),
        personalRuleArchiver: (_) async {},
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
    });

    test('activates valid remote rules and preserves previous rules', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      await active.writeAsString(_validToml(rulesVersion: 'active'));
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.activated);
      expect(result.rulesVersion, 'remote');
      expect(await active.readAsString(), contains('rulesVersion = "remote"'));
      expect(
        await File('${tempDir.path}/billing_rules.previous.toml')
            .readAsString(),
        contains('rulesVersion = "active"'),
      );
    });

    test('skips daily update check when the last check is recent', () async {
      var manifestCalls = 0;
      final remoteToml = _validToml(rulesVersion: 'remote');
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        clock: () => DateTime.utc(2026, 7, 4, 10),
        onManifestLoad: () => manifestCalls++,
      );

      final firstResult = await service.checkForUpdateIfDue();
      final secondResult = await service.checkForUpdateIfDue();

      expect(firstResult.status, BillingRuleUpdateStatus.activated);
      expect(secondResult.status, BillingRuleUpdateStatus.notDue);
      expect(manifestCalls, 1);
      expect(
        await File(
          '${tempDir.path}/billing_rules.last_check.json',
        ).readAsString(),
        contains('2026-07-04T10:00:00.000Z'),
      );
    });

    test('runs daily update check after the interval has elapsed', () async {
      var manifestCalls = 0;
      final remoteToml = _validToml(rulesVersion: 'remote');
      final lastCheck = File('${tempDir.path}/billing_rules.last_check.json');
      await lastCheck.writeAsString(
        jsonEncode({'checkedAt': '2026-07-03T09:59:59.000Z'}),
      );
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: _sha256(remoteToml)),
        remoteToml: remoteToml,
        clock: () => DateTime.utc(2026, 7, 4, 10),
        onManifestLoad: () => manifestCalls++,
      );

      final result = await service.checkForUpdateIfDue();

      expect(result.status, BillingRuleUpdateStatus.activated);
      expect(manifestCalls, 1);
    });

    test('rolls back to the previous active rule package', () async {
      final active = File('${tempDir.path}/billing_rules.active.toml');
      final previous = File('${tempDir.path}/billing_rules.previous.toml');
      await active.writeAsString(_validToml(rulesVersion: 'remote'));
      await previous.writeAsString(_validToml(rulesVersion: 'active'));
      final service = _service(
        tempDir,
        manifest: _manifestJson(sha256: '0' * 64),
        remoteToml: '',
      );

      final result = await service.rollback();

      expect(result.status, BillingRuleUpdateStatus.rolledBack);
      expect(await active.readAsString(), contains('rulesVersion = "active"'));
      expect(
          await previous.readAsString(), contains('rulesVersion = "remote"'));
    });
  });
}

BillingRuleUpdateService _service(
  Directory tempDir, {
  required String manifest,
  required String remoteToml,
  BillingRuleSmokeTest? smokeTest,
  BillingRuleUpgradeEvaluation? upgradeEvaluation,
  BillingRulePersonalRegression? personalRegression,
  BillingRulePersonalRuleArchiver? personalRuleArchiver,
  void Function()? beforeAtomicSwitch,
  BillingRuleUpdateClock? clock,
  void Function()? onManifestLoad,
}) {
  return BillingRuleUpdateService(
    storageDirectory: tempDir,
    manifestLoader: (_) async {
      onManifestLoad?.call();
      return manifest;
    },
    rulePackageDownloader: (_) async => remoteToml,
    smokeTest: smokeTest ?? (_) async => true,
    upgradeEvaluation: upgradeEvaluation ?? (_) async => true,
    personalRegression: personalRegression ??
        (_) async => const BillingRulePersonalRegressionResult.passed(),
    personalRuleArchiver: personalRuleArchiver ?? (_) async {},
    beforeAtomicSwitch: beforeAtomicSwitch,
    clock: clock,
  );
}

String _manifestJson({required String sha256}) {
  return jsonEncode({
    'latest': {
      'schemaVersion': 1,
      'rulesVersion': 'remote',
      'minAppVersion': '0.0.1',
      'url': 'https://example.com/remote.toml',
      'sha256': sha256,
    },
  });
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

String _validToml({required String rulesVersion}) => '''
schemaVersion = 1
rulesVersion = "$rulesVersion"

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
''';
