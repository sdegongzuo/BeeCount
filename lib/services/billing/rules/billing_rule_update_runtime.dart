import 'dart:async';

import '../../../data/db.dart';
import '../regression_sample_store.dart';
import 'billing_rule_engine_impl.dart';
import 'billing_rule_repository.dart';
import 'billing_rule_runtime_evaluator.dart';
import 'billing_rule_update_configuration.dart';
import 'billing_rule_update_service.dart';
import 'personal_rule_lifecycle_service.dart';

typedef ProductionBillingRuleUpdateInitializer
    = Future<BillingRuleUpdateService> Function({
  required BillingRuleUpdateConfiguration configuration,
  required BeeDatabase database,
});

/// 进程级公共规则恢复门。
///
/// 首个规则消费者启动前必须等待 [runAfterRecovery]；首帧后的网络日检和设置页
/// 则通过 [prepare] 复用同一服务，不重复恢复 journal。
class ProductionBillingRuleUpdateRuntime {
  final ProductionBillingRuleUpdateInitializer _initializer;
  Future<BillingRuleUpdateService>? _serviceFuture;

  ProductionBillingRuleUpdateRuntime({
    ProductionBillingRuleUpdateInitializer initializer =
        initializeProductionBillingRuleUpdateService,
  }) : _initializer = initializer;

  Future<BillingRuleUpdateService> prepare({
    required BillingRuleUpdateConfiguration configuration,
    required BeeDatabase database,
  }) {
    final existing = _serviceFuture;
    if (existing != null) return existing;
    final created = Future<BillingRuleUpdateService>.sync(
      () => _initializer(
        configuration: configuration,
        database: database,
      ),
    );
    _serviceFuture = created;
    return _clearFailedPreparation(created);
  }

  Future<BillingRuleUpdateService> _clearFailedPreparation(
    Future<BillingRuleUpdateService> created,
  ) async {
    try {
      return await created;
    } catch (_) {
      if (identical(_serviceFuture, created)) _serviceFuture = null;
      rethrow;
    }
  }

  Future<T> runAfterRecovery<T>({
    required BillingRuleUpdateConfiguration configuration,
    required BeeDatabase database,
    required FutureOr<T> Function() startConsumers,
  }) async {
    await prepare(configuration: configuration, database: database);
    return startConsumers();
  }
}

final productionBillingRuleUpdateRuntime = ProductionBillingRuleUpdateRuntime();

/// 组装生产远程规则更新服务，默认接入真实黄金评测和本机加密样本回归。
BillingRuleUpdateService createProductionBillingRuleUpdateService({
  required BillingRuleUpdateConfiguration configuration,
  required BeeDatabase database,
}) {
  final publicRepository = productionBillingRuleRepository();
  final personalRevisions = SqlitePersonalRuleRevisionStore(database);
  final evaluator = BillingRuleRuntimeEvaluator(
    engine: BillingRuleEngineImpl(),
    goldenCorpus: BundledBillingRuleGoldenCorpus(),
    regressionSamples: const RegressionSampleStore(),
    loadActivePublicRules: publicRepository.loadActiveRuleSet,
    loadBuiltInRules: publicRepository.loadBuiltInRuleSet,
    loadActivePersonalRules: personalRevisions.loadActiveRuleSet,
  );
  return BillingRuleUpdateService(
    configuration: configuration,
    upgradeEvaluation: evaluator.evaluateGolden,
    personalRegression: evaluator.evaluatePersonal,
    personalRuleReconciler: (result, publicRulesVersion) =>
        personalRevisions.reconcilePublicRules(
      result,
      publicRulesVersion: publicRulesVersion,
    ),
    personalRuleReconciliationVerifier: (result, publicRulesVersion) =>
        personalRevisions.isPublicReconciliationApplied(
      result,
      publicRulesVersion: publicRulesVersion,
    ),
  );
}

/// 组装生产更新服务并在任何检查、回滚或运行时读取前恢复未完成状态机。
Future<BillingRuleUpdateService> initializeProductionBillingRuleUpdateService({
  required BillingRuleUpdateConfiguration configuration,
  required BeeDatabase database,
}) async {
  final service = createProductionBillingRuleUpdateService(
    configuration: configuration,
    database: database,
  );
  final recovery = await service.reconcileInterruptedActivation();
  if (recovery.status == BillingRuleUpdateStatus.failed) {
    throw StateError(recovery.message ?? '公共规则启动恢复失败');
  }
  return service;
}
