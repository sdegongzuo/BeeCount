import 'dart:convert';
import 'dart:io';

import 'package:beecount/ai/tasks/bill_extraction_task.dart';
import 'package:beecount/services/billing/rules/ai_rule_review_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_rule_review_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('builds an auditable payload from rule, AI and user results', () {
    final service = AiRuleReviewService(reviewDirectory: tempDir);
    final trace = _trace(ruleResult: _ruleResult(amount: -19.5));

    final payload = service.buildPayloadFromUserCorrection(
      sampleId: 'wechat_payment_detail_001',
      sourcePackage: 'com.tencent.mm',
      sourcePaymentChannel: '微信支付',
      ocrText: '当前状态\n支付成功\n支付时间 2026年5月31日 14:27:40',
      trace: trace,
      ruleResult: _ruleResult(amount: -19.5),
      aiResult: const BillInfo(
        amount: -19.5,
        paymentChannel: '微信支付',
        merchantFullName: 'AI商户',
        confidence: 0.7,
      ),
      userFinalResult: const BillInfo(
        amount: -19.5,
        paymentChannel: '微信支付',
        merchantFullName: '用户确认商户',
        confidence: 1,
      ),
    );

    expect(payload.sampleId, 'wechat_payment_detail_001');
    expect(payload.ruleTrace.toJson()['trace_id'], 'trace-001');
    expect(payload.ruleResult.toJson()['matched_template_id'],
        'wechat_payment_detail_v1');
    expect(payload.aiResult['merchant_full_name'], 'AI商户');
    expect(payload.userFinalResult['merchant_full_name'], '用户确认商户');
  });

  test('saves AI suggestions only as review artifacts', () async {
    final service = AiRuleReviewService(
      reviewDirectory: tempDir,
      clock: () => DateTime.utc(2026, 7, 4, 12, 30),
    );
    final payload = service.buildPayloadFromUserCorrection(
      sampleId: 'wechat_payment_detail_001',
      sourcePackage: 'com.tencent.mm',
      sourcePaymentChannel: '微信支付',
      ocrText: '商户全称 上海寻梦信息技术有限公司',
      trace: _trace(ruleResult: _ruleResult(merchantFullName: null)),
      ruleResult: _ruleResult(merchantFullName: null),
      aiResult: const BillInfo(merchantFullName: '上海寻梦信息技术有限公司'),
      userFinalResult: const BillInfo(merchantFullName: '上海寻梦信息技术有限公司'),
    );
    final suggestion = service.createSuggestion(
      payload,
      diagnostics: const ['规则未提取 merchantFullName'],
      risks: const ['样本数量不足，不能直接推广为规则'],
    );

    final file = await service.saveSuggestion(suggestion);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    expect(file.path, contains('ai_suggestions'));
    expect(file.path, endsWith('.review.json'));
    expect(json['requires_human_review'], isTrue);
    expect(json['manual_toml_conversion_required'], isTrue);
    expect(json['auto_activation_allowed'], isFalse);
    expect(json['sample_id'], 'wechat_payment_detail_001');
    expect(json['field_strategies'], isNotEmpty);
    expect(
      File('${tempDir.path}/billing_rules.active.toml').existsSync(),
      isFalse,
    );
  });
}

BillingRuleTrace _trace({required BillingRuleResult ruleResult}) {
  return BillingRuleTrace(
    traceId: 'trace-001',
    rulesVersion: '2026.07.01.1',
    sourcePackage: 'com.tencent.mm',
    sourcePaymentChannel: '微信支付',
    ocrText: '支付详情',
    matchedRuleIds: const ['wechat_payment_detail_v1'],
    result: ruleResult,
  );
}

BillingRuleResult _ruleResult({
  double? amount,
  String? merchantFullName = '上海寻梦信息技术有限公司',
}) {
  return BillingRuleResult(
    amount: amount,
    merchantFullName: merchantFullName,
    paymentChannel: '微信支付',
    matchedTemplateId: 'wechat_payment_detail_v1',
    confidence: 0.86,
  );
}
