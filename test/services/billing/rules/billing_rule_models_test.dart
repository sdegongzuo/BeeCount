import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiEnhanceStatus', () {
    test('parses stable wire values', () {
      expect(parseAiEnhanceStatus('pending'), AiEnhanceStatus.pending);
      expect(parseAiEnhanceStatus('completed'), AiEnhanceStatus.completed);
      expect(parseAiEnhanceStatus('failed'), AiEnhanceStatus.failed);
      expect(parseAiEnhanceStatus('timeout'), AiEnhanceStatus.timeout);
      expect(parseAiEnhanceStatus('skipped'), AiEnhanceStatus.skipped);
    });

    test('falls back when the wire value is unknown', () {
      expect(parseAiEnhanceStatus(null), AiEnhanceStatus.skipped);
      expect(parseAiEnhanceStatus(''), AiEnhanceStatus.skipped);
      expect(parseAiEnhanceStatus('queued'), AiEnhanceStatus.skipped);
      expect(
        parseAiEnhanceStatus('queued', fallback: AiEnhanceStatus.pending),
        AiEnhanceStatus.pending,
      );
    });
  });

  group('BillingRuleFieldResult', () {
    test('serializes field value, confidence and evidence', () {
      final result = BillingRuleFieldResult(
        field: 'amount',
        value: -5.07,
        confidence: 0.96,
        extractorType: 'regex',
        evidence: const [
          BillingRuleFieldEvidence(
            type: 'line',
            text: '-5.07',
            lineIndex: 2,
            start: 0,
            end: 5,
            ruleId: 'wechat_payment_detail_v1',
          ),
        ],
      );

      expect(result.toJson(), {
        'field': 'amount',
        'value': -5.07,
        'confidence': 0.96,
        'extractor_type': 'regex',
        'source': null,
        'evidence': [
          {
            'type': 'line',
            'text': '-5.07',
            'line_index': 2,
            'start': 0,
            'end': 5,
            'rule_id': 'wechat_payment_detail_v1',
          },
        ],
      });
    });
  });

  group('BillingRuleTrace', () {
    test('serializes rule version, preprocess metadata, evidence and result',
        () {
      final preprocess = OcrPreprocessResult(
        method: 'maskStatusBar',
        originalWidth: 1080,
        originalHeight: 2400,
        outputWidth: 1080,
        outputHeight: 2400,
        cropRect: const BillingImageRegion(
          left: 0,
          top: 0,
          width: 1080,
          height: 92,
        ),
        metadata: const {'status_bar_source': 'safe_ratio'},
      );
      final fieldEvidence = const BillingRuleFieldEvidence(
        type: 'labelNextLine',
        text: '2026年06月30日 12:51:18',
        lineIndex: 8,
        ruleId: 'wechat_payment_detail_v1',
      );
      final result = BillingRuleResult(
        amount: -5.07,
        time: DateTime(2026, 6, 30, 12, 51, 18),
        paymentChannel: '微信支付',
        merchantFullName: '东莞市小吉姆餐饮管理有限公司',
        confidence: 0.93,
        matchedTemplateId: 'wechat_payment_detail_v1',
        fields: {
          'time': BillingRuleFieldResult(
            field: 'time',
            value: DateTime(2026, 6, 30, 12, 51, 18),
            confidence: 0.91,
            extractorType: 'labelNextLine',
            evidence: [fieldEvidence],
          ),
        },
        aiEnhanceStatus: AiEnhanceStatus.pending,
      );
      final trace = BillingRuleTrace(
        traceId: 'trace-1',
        rulesVersion: '2026.07.01.1',
        sourcePackage: 'com.tencent.mm',
        sourcePaymentChannel: '微信支付',
        ocrText: '支付时间\n2026年06月30日 12:51:18',
        preprocessResult: preprocess,
        matchedRuleIds: const ['wechat_payment_detail_v1'],
        fieldEvidence: {
          'time': [fieldEvidence],
        },
        result: result,
        durationMs: 86,
      );

      final json = trace.toJson();

      expect(json['rules_version'], '2026.07.01.1');
      expect(json['preprocess'], preprocess.toJson());
      expect(json['field_evidence'], {
        'time': [fieldEvidence.toJson()],
      });
      expect(json['result'], result.toJson());
      expect(json['duration_ms'], 86);
      expect(trace.toDebugJson()['matched_rule_ids'], [
        'wechat_payment_detail_v1',
      ]);
    });
  });
}
