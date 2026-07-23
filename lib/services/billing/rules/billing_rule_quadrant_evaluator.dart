import 'package:collection/collection.dart';

import '../payment_method_semantics.dart';
import 'billing_rule_engine.dart';
import 'billing_rule_engine_impl.dart';
import 'billing_rule_models.dart';

enum BillingRuleChangeKind {
  rule,
  normalization,
  ruleAndNormalization,
}

extension BillingRuleChangeKindWireName on BillingRuleChangeKind {
  String get wireName => switch (this) {
        BillingRuleChangeKind.rule => 'rule',
        BillingRuleChangeKind.normalization => 'normalization',
        BillingRuleChangeKind.ruleAndNormalization => 'rule_and_normalization',
      };
}

enum BillingRuleQuadrant { a, b, c, d }

enum BillingRuleUpgradeEffect {
  behaviorEquivalent,
  rule,
  normalization,
  ruleAndNormalization,
  interaction,
}

typedef BillingRuleEngineFactory = BillingRuleEngine Function(
  PaymentMethodSemantics semantics,
);

class BillingRuleQuadrantOutcome {
  final BillingRuleQuadrant quadrant;
  final BillingRuleResult result;

  const BillingRuleQuadrantOutcome({
    required this.quadrant,
    required this.result,
  });
}

class BillingRuleQuadrantReport {
  static const _equality = DeepCollectionEquality();

  final BillingRuleChangeKind changeKind;
  final BillingRuleQuadrantOutcome a;
  final BillingRuleQuadrantOutcome b;
  final BillingRuleQuadrantOutcome c;
  final BillingRuleQuadrantOutcome d;

  const BillingRuleQuadrantReport({
    required this.changeKind,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  Map<BillingRuleQuadrant, BillingRuleQuadrantOutcome> get outcomes => {
        BillingRuleQuadrant.a: a,
        BillingRuleQuadrant.b: b,
        BillingRuleQuadrant.c: c,
        BillingRuleQuadrant.d: d,
      };

  bool get hasRuleBehaviorChange => !_equivalent(a, b);

  bool get hasNormalizationBehaviorChange => !_equivalent(a, c);

  bool get isBehaviorEquivalent =>
      _equivalent(a, b) && _equivalent(a, c) && _equivalent(a, d);

  bool get hasInteractionAnomaly {
    if (isBehaviorEquivalent) return false;
    if (_equivalent(a, c)) return !_equivalent(b, d);
    if (_equivalent(a, b)) return !_equivalent(c, d);
    return !_equivalent(b, d) && !_equivalent(c, d);
  }

  BillingRuleUpgradeEffect get detectedEffect {
    if (isBehaviorEquivalent) {
      return BillingRuleUpgradeEffect.behaviorEquivalent;
    }
    if (hasInteractionAnomaly) {
      return BillingRuleUpgradeEffect.interaction;
    }
    if (hasRuleBehaviorChange && !hasNormalizationBehaviorChange) {
      return BillingRuleUpgradeEffect.rule;
    }
    if (!hasRuleBehaviorChange && hasNormalizationBehaviorChange) {
      return BillingRuleUpgradeEffect.normalization;
    }
    return BillingRuleUpgradeEffect.ruleAndNormalization;
  }

  static bool _equivalent(
    BillingRuleQuadrantOutcome left,
    BillingRuleQuadrantOutcome right,
  ) =>
      _equality.equals(
        _authoritativeBehavior(left.result),
        _authoritativeBehavior(right.result),
      );

  static Map<String, Object?> _authoritativeBehavior(
    BillingRuleResult result,
  ) =>
      {
        'amount': result.amount,
        'note': result.note,
        'time': result.time?.toIso8601String(),
        'paymentChannel': result.paymentChannel,
        'paymentMethod': result.paymentMethod,
        'counterparty': result.counterparty,
        'merchantFullName': result.merchantFullName,
        'acquirer': result.acquirer,
        'details': result.details,
        'fields': {
          for (final entry in result.fields.entries)
            entry.key: entry.value.value,
        },
      };
}

class BillingRuleQuadrantEvaluator {
  final BillingRuleEngineFactory? _engineFactory;

  const BillingRuleQuadrantEvaluator({
    BillingRuleEngineFactory? engineFactory,
  }) : _engineFactory = engineFactory;

  Future<BillingRuleQuadrantReport> evaluate({
    required BillingRuleChangeKind changeKind,
    required BillingRuleSet currentRuleSet,
    required BillingRuleSet candidateRuleSet,
    required PaymentMethodSemantics currentSemantics,
    required PaymentMethodSemantics candidateSemantics,
    required String ocrText,
    OcrPreprocessResult? preprocessResult,
    String? sourcePackage,
    String? sourceAppName,
    String? sourcePaymentChannel,
  }) async {
    Future<BillingRuleQuadrantOutcome> run(
      BillingRuleQuadrant quadrant,
      BillingRuleSet ruleSet,
      PaymentMethodSemantics semantics,
    ) async {
      final engine = _engineFactory?.call(semantics) ??
          BillingRuleEngineImpl(paymentMethodSemantics: semantics);
      final result = await engine.evaluate(
        ruleSet: ruleSet,
        ocrText: ocrText,
        preprocessResult: preprocessResult,
        sourcePackage: sourcePackage,
        sourceAppName: sourceAppName,
        sourcePaymentChannel: sourcePaymentChannel,
      );
      return BillingRuleQuadrantOutcome(
        quadrant: quadrant,
        result: result,
      );
    }

    final outcomes = await Future.wait([
      run(BillingRuleQuadrant.a, currentRuleSet, currentSemantics),
      run(BillingRuleQuadrant.b, candidateRuleSet, currentSemantics),
      run(BillingRuleQuadrant.c, currentRuleSet, candidateSemantics),
      run(BillingRuleQuadrant.d, candidateRuleSet, candidateSemantics),
    ]);
    return BillingRuleQuadrantReport(
      changeKind: changeKind,
      a: outcomes[0],
      b: outcomes[1],
      c: outcomes[2],
      d: outcomes[3],
    );
  }
}
