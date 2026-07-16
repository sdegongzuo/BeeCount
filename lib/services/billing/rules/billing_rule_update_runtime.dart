import '../../../data/db.dart';
import '../regression_sample_store.dart';
import 'billing_rule_engine_impl.dart';
import 'billing_rule_repository.dart';
import 'billing_rule_runtime_evaluator.dart';
import 'billing_rule_update_configuration.dart';
import 'billing_rule_update_service.dart';
import 'personal_rule_lifecycle_service.dart';

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
  );
}
