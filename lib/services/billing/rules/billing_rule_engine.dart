import 'billing_rule_models.dart';
import 'billing_rule_trace.dart';

typedef BillingRuleTraceSink = void Function(BillingRuleTrace trace);

abstract class BillingRuleRepository {
  Future<BillingRuleSet> loadBuiltInRuleSet();

  Future<BillingRuleSet> loadActiveRuleSet();

  Future<BillingRuleSet?> loadDebugOverrideRuleSet();

  Future<void> validateRuleSet(BillingRuleSet ruleSet);
}

abstract class BillingRuleEngine {
  Future<BillingRuleResult> evaluate({
    required BillingRuleSet ruleSet,
    required String ocrText,
    OcrPreprocessResult? preprocessResult,
    String? sourcePackage,
    String? sourcePaymentChannel,
    BillingRuleTraceSink? traceSink,
  });
}
