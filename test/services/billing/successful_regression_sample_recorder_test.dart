import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/successful_regression_sample_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('成功 Billing Job 保存可重放的普通个人规则回归样本', () async {
    RegressionSampleDraft? captured;
    final recorder = SuccessfulRegressionSampleRecorder(
      loadExpectedFields: (_) async => {
        'amount': 12.0,
        'note': '最终账单',
        'details_text': '订单号: A1',
      },
      saveSample: (draft) async {
        captured = draft;
        return const SaveRegressionSampleResult(
          inserted: true,
          sampleId: 'sample',
          exactFingerprint: 'exact',
          structureFingerprint: 'structure',
        );
      },
    );
    final result = {
      'amount': 12.0,
      'note': '蜂店',
      'rawText': '支付成功 金额 12.00',
      'billing_rule_result': {
        'templateId': 'wechat-payment',
        'evidence': ['金额', '12.00'],
      },
      'allNumbers': ['12.00'],
    };

    await recorder.capture(_job(
      status: BillingJobStatus.succeeded,
      rawText: '  支付成功\r\n\r\n金额   12.00  ',
      ruleResultJson: jsonEncode(result),
      sourceInfoJson: jsonEncode({
        'sourceAppPackage': 'com.tencent.mm',
        'sourcePaymentChannel': '微信支付',
      }),
    ));

    expect(captured?.normalizedOcr, '支付成功\n金额 12.00');
    expect(captured?.expectedFields, containsPair('amount', 12.0));
    expect(captured?.expectedFields, containsPair('note', '最终账单'));
    expect(captured?.expectedFields, isNot(contains('rawText')));
    expect(captured?.sensitiveEvidence['billing_rule_result'], isA<Map>());
    expect(captured?.sensitiveEvidence['allNumbers'], ['12.00']);
    expect(captured?.structureDescriptor, contains('wechat-payment'));
    expect(captured?.protection, RegressionSampleProtection.none);
  });

  test('失败或不完整的 Billing Job 不形成成功回归样本', () async {
    var calls = 0;
    final recorder = SuccessfulRegressionSampleRecorder(
      loadExpectedFields: (_) async => const {},
      saveSample: (draft) async {
        calls++;
        throw StateError('不应调用');
      },
    );

    await recorder.capture(_job(status: BillingJobStatus.failed));
    await recorder.capture(_job(status: BillingJobStatus.succeeded));

    expect(calls, 0);
  });
}

BillingJob _job({
  required String status,
  String? rawText,
  String? ruleResultJson,
  String? sourceInfoJson,
}) =>
    BillingJob(
      id: 1,
      kind: 'image_share',
      status: status,
      stage: BillingJobStage.aiDone,
      transactionId: status == BillingJobStatus.succeeded ? 7 : null,
      imagePath: '/private/share.png',
      rawText: rawText,
      ruleResultJson: ruleResultJson,
      sourceInfoJson: sourceInfoJson,
      attemptCount: 0,
      attachmentDone: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
