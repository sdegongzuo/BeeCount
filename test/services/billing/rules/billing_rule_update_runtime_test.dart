import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_runtime.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生产组装默认使用真实黄金评测、加密样本回归和个人裁决落库', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = createProductionBillingRuleUpdateService(
      configuration: BillingRuleUpdateConfiguration.fromValues(
        manifestUrl: 'https://rules.test/manifest.json',
        currentAppVersion: '1.0.0',
      ),
      database: db,
    );
    const invalidCandidate = BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: 'candidate',
      paymentChannels: [],
      templates: [],
    );

    expect(await service.upgradeEvaluation(invalidCandidate), isFalse);
    final regression = await service.personalRegression(invalidCandidate);
    expect(regression.isPassed, isFalse);
    expect(service.personalRuleReconciler, isNotNull);
    expect(service.personalRuleReconciliationVerifier, isNotNull);
  });

  test('规则消费者必须等待恢复完成且后续入口复用同一服务', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final recovery = Completer<BillingRuleUpdateService>();
    var initializerCalls = 0;
    var consumersStarted = false;
    final runtime = ProductionBillingRuleUpdateRuntime(
      initializer: ({required configuration, required database}) {
        initializerCalls++;
        return recovery.future;
      },
    );
    final configuration = BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: '',
      currentAppVersion: '1.0.0',
    );
    final service = createProductionBillingRuleUpdateService(
      configuration: configuration,
      database: db,
    );

    final consumers = runtime.runAfterRecovery(
      configuration: configuration,
      database: db,
      startConsumers: () => consumersStarted = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(consumersStarted, isFalse);

    recovery.complete(service);
    await consumers;
    expect(consumersStarted, isTrue);
    expect(
      await runtime.prepare(configuration: configuration, database: db),
      same(service),
    );
    expect(initializerCalls, 1);
  });

  test('恢复失败不会缓存坏 Future，下一次准备可以重试', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final configuration = BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: '',
      currentAppVersion: '1.0.0',
    );
    final service = createProductionBillingRuleUpdateService(
      configuration: configuration,
      database: db,
    );
    var attempts = 0;
    final runtime = ProductionBillingRuleUpdateRuntime(
      initializer: ({required configuration, required database}) async {
        attempts++;
        if (attempts == 1) throw StateError('recovery failed');
        return service;
      },
    );

    await expectLater(
      runtime.prepare(configuration: configuration, database: db),
      throwsStateError,
    );
    expect(
      await runtime.prepare(configuration: configuration, database: db),
      same(service),
    );
    expect(attempts, 2);
  });
}
