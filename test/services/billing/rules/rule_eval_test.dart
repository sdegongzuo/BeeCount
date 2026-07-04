import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/rule_eval.dart';

void main() {
  group('rule_eval CLI core', () {
    test('renders a passing report for the golden WeChat sample', () async {
      final report = await evaluateBillingRules(
        sampleDirectory: Directory('tool/rule_eval/samples'),
        expectedDirectory: Directory('tool/rule_eval/expected'),
        ruleFile: File('assets/rules/billing_rules.toml'),
      );

      expect(report.totalSamples, 1);
      expect(report.passedSamples, 1);
      expect(report.templateHitRate, 1);
      expect(report.fieldAccuracy, 1);
      expect(report.falsePositiveCount, 0);

      final markdown = renderRuleEvalMarkdown(report);
      expect(markdown, contains('Template hit rate: 1/1'));
      expect(markdown, contains('Field accuracy: 6/6'));
      expect(markdown, contains('wechat_payment_detail_001'));
      expect(markdown, contains('PASS'));
    });

    test('renders field diffs for failing expectations', () async {
      final report = await evaluateBillingRules(
        sampleDirectory: Directory('tool/rule_eval/samples'),
        expectedDirectory: Directory('tool/rule_eval/expected'),
        ruleFile: File('assets/rules/billing_rules.toml'),
        expectedOverrides: const {
          'wechat_payment_detail_001': {
            'amount': -99.99,
            'paymentChannel': '支付宝',
          },
        },
      );

      expect(report.passedSamples, 0);
      expect(report.samples.single.fieldDiffs, hasLength(2));

      final markdown = renderRuleEvalMarkdown(report);
      expect(markdown, contains('FAIL'));
      expect(markdown, contains('sample=wechat_payment_detail_001'));
      expect(markdown, contains('field=amount expected=-99.99 actual=-19.5'));
      expect(
          markdown, contains('field=paymentChannel expected=支付宝 actual=微信支付'));
    });
  });
}
