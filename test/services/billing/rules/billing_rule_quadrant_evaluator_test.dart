import 'package:beecount/services/billing/payment_method_semantics.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_quadrant_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingRuleQuadrantEvaluator', () {
    test('runs real A/B/C/D evaluations and detects a rule-only change',
        () async {
      final report = await const BillingRuleQuadrantEvaluator().evaluate(
        changeKind: BillingRuleChangeKind.rule,
        currentRuleSet: _ruleSet('current', '旧支付方式'),
        candidateRuleSet: _ruleSet('candidate', '候选支付方式'),
        currentSemantics: const PaymentMethodSemantics(),
        candidateSemantics: const PaymentMethodSemantics(),
        ocrText: '账单',
      );

      expect(report.a.result.paymentMethod, '旧支付方式');
      expect(report.b.result.paymentMethod, '候选支付方式');
      expect(report.c.result.paymentMethod, '旧支付方式');
      expect(report.d.result.paymentMethod, '候选支付方式');
      expect(report.detectedEffect, BillingRuleUpgradeEffect.rule);
      expect(report.hasRuleBehaviorChange, isTrue);
      expect(report.hasNormalizationBehaviorChange, isFalse);
      expect(report.hasInteractionAnomaly, isFalse);
      expect(report.isBehaviorEquivalent, isFalse);
    });

    test('detects a normalization-only change', () async {
      final report = await const BillingRuleQuadrantEvaluator().evaluate(
        changeKind: BillingRuleChangeKind.normalization,
        currentRuleSet: _ruleSet('current', '原始支付方式'),
        candidateRuleSet: _ruleSet('candidate', '原始支付方式'),
        currentSemantics: const PaymentMethodSemantics(),
        candidateSemantics: const _MappingSemantics({
          '原始支付方式': '归一化支付方式',
        }),
        ocrText: '账单',
      );

      expect(report.a.result.paymentMethod, '原始支付方式');
      expect(report.b.result.paymentMethod, '原始支付方式');
      expect(report.c.result.paymentMethod, '归一化支付方式');
      expect(report.d.result.paymentMethod, '归一化支付方式');
      expect(report.detectedEffect, BillingRuleUpgradeEffect.normalization);
      expect(report.hasRuleBehaviorChange, isFalse);
      expect(report.hasNormalizationBehaviorChange, isTrue);
      expect(report.hasInteractionAnomaly, isFalse);
    });

    test('reports behavior equivalence despite rule package metadata changes',
        () async {
      final report = await const BillingRuleQuadrantEvaluator().evaluate(
        changeKind: BillingRuleChangeKind.ruleAndNormalization,
        currentRuleSet: _ruleSet('current', '相同支付方式'),
        candidateRuleSet: _ruleSet('repacked', '相同支付方式'),
        currentSemantics: const PaymentMethodSemantics(),
        candidateSemantics: const _MappingSemantics({}),
        ocrText: '账单',
      );

      expect(report.isBehaviorEquivalent, isTrue);
      expect(
        report.detectedEffect,
        BillingRuleUpgradeEffect.behaviorEquivalent,
      );
      expect(report.hasInteractionAnomaly, isFalse);
    });

    test('detects a combined rule and normalization change', () async {
      final report = await const BillingRuleQuadrantEvaluator().evaluate(
        changeKind: BillingRuleChangeKind.ruleAndNormalization,
        currentRuleSet: _ruleSet('current', '旧值'),
        candidateRuleSet: _ruleSet('candidate', '候选值'),
        currentSemantics: const PaymentMethodSemantics(),
        candidateSemantics: const _MappingSemantics({'旧值': '归一化旧值'}),
        ocrText: '账单',
      );

      expect(report.a.result.paymentMethod, '旧值');
      expect(report.b.result.paymentMethod, '候选值');
      expect(report.c.result.paymentMethod, '归一化旧值');
      expect(report.d.result.paymentMethod, '候选值');
      expect(
        report.detectedEffect,
        BillingRuleUpgradeEffect.ruleAndNormalization,
      );
      expect(report.hasInteractionAnomaly, isFalse);
    });

    test('detects an interaction that only appears in quadrant D', () async {
      final report = await const BillingRuleQuadrantEvaluator().evaluate(
        changeKind: BillingRuleChangeKind.ruleAndNormalization,
        currentRuleSet: _ruleSet('current', '旧值'),
        candidateRuleSet: _ruleSet('candidate', '候选值'),
        currentSemantics: const PaymentMethodSemantics(),
        candidateSemantics: const _MappingSemantics({
          '旧值': '正常归一化值',
          '候选值': '组合异常值',
        }),
        ocrText: '账单',
      );

      expect(report.a.result.paymentMethod, '旧值');
      expect(report.b.result.paymentMethod, '候选值');
      expect(report.c.result.paymentMethod, '正常归一化值');
      expect(report.d.result.paymentMethod, '组合异常值');
      expect(report.outcomes.keys, BillingRuleQuadrant.values);
      expect(report.changeKind.wireName, 'rule_and_normalization');
      expect(report.hasInteractionAnomaly, isTrue);
      expect(report.detectedEffect, BillingRuleUpgradeEffect.interaction);
    });
  });
}

class _MappingSemantics extends PaymentMethodSemantics {
  final Map<String, String> replacements;

  const _MappingSemantics(this.replacements);

  @override
  PaymentMethodNormalizationResult canonicalize(String? input) {
    final replacement = replacements[input];
    if (replacement != null) {
      return PaymentMethodNormalizationResult.normalized(replacement);
    }
    return super.canonicalize(input);
  }
}

BillingRuleSet _ruleSet(String version, String paymentMethod) => BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: version,
      normalizationVersion: 1,
      paymentChannels: const [],
      templates: [
        BillingRuleTemplate(
          id: version,
          match: const BillingRuleTemplateMatch(keywordsAll: ['账单']),
          extractors: [
            BillingFieldExtractorRule(
              field: 'paymentMethod',
              type: BillingRuleExtractorTypes.constant,
              value: paymentMethod,
            ),
          ],
        ),
      ],
    );
