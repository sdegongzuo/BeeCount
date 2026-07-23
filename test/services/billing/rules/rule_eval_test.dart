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

      expect(report.totalSamples, greaterThanOrEqualTo(3));
      expect(report.passedSamples, report.totalSamples);
      expect(report.templateHitRate, 1);
      expect(report.fieldAccuracy, 1);
      expect(report.falsePositiveCount, 0);
      final paymentSample = report.samples.firstWhere(
        (sample) => sample.paymentMethodReport != null,
      );
      final paymentReport =
          paymentSample.toJson()['paymentMethod'] as Map<String, dynamic>;
      expect(
          paymentReport.keys,
          containsAll([
            'raw',
            'normalized',
            'expected',
            'evidence',
          ]));
      expect(paymentReport['raw'], isNot(contains(RegExp(r'\d{7,}'))));
      expect(
        (paymentReport['evidence'] as List).join(),
        isNot(contains(RegExp(r'\d{7,}'))),
      );

      final markdown = renderRuleEvalMarkdown(report);
      expect(markdown, contains('Template hit rate:'));
      expect(markdown, contains('Field accuracy:'));
      expect(markdown, contains('wechat_payment_detail_001'));
      expect(markdown, contains('alipay_etc_single'));
      expect(markdown, contains('alipay_mimo_token_single'));
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

      expect(report.passedSamples, report.totalSamples - 1);
      final wechat = report.samples.singleWhere(
        (sample) => sample.id == 'wechat_payment_detail_001',
      );
      expect(wechat.fieldDiffs, hasLength(2));

      final markdown = renderRuleEvalMarkdown(report);
      expect(markdown, contains('FAIL'));
      expect(markdown, contains('sample=wechat_payment_detail_001'));
      expect(markdown, contains('field=amount expected=-99.99 actual=-19.5'));
      expect(
          markdown, contains('field=paymentChannel expected=支付宝 actual=微信支付'));
    });
  });
}
