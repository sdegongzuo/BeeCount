import '../ai/bill_extraction_service.dart';
import '../platform/screenshot_source_info.dart';
import 'details_text_helper.dart';
import 'ocr_service.dart';
import 'rules/billing_rule_engine.dart';
import 'rules/billing_rule_models.dart';
import 'rules/billing_rule_trace.dart';

class FastBillingRuleEvaluation {
  final OcrResult result;
  final bool accepted;
  final List<String> rejectReasons;
  final BillingRuleTrace? trace;

  const FastBillingRuleEvaluation({
    required this.result,
    required this.accepted,
    required this.rejectReasons,
    this.trace,
  });
}

class FastBillingRuleService {
  static const defaultMinimumConfidence = 0.75;

  final BillingRuleRepository ruleRepository;
  final BillingRuleEngine ruleEngine;
  final double minimumConfidence;

  const FastBillingRuleService({
    required this.ruleRepository,
    required this.ruleEngine,
    this.minimumConfidence = defaultMinimumConfidence,
  });

  Future<FastBillingRuleEvaluation> evaluate({
    required OcrResult baseResult,
    ScreenshotSourceInfo? sourceInfo,
    OcrPreprocessResult? preprocessResult,
    BillExtractionTraceSink? traceSink,
  }) async {
    BillingRuleTrace? ruleTrace;
    final ruleSet = await ruleRepository.loadActiveRuleSet();
    final sourcePackage = _sourcePackageForRuleMatch(sourceInfo);
    final ruleResult = await ruleEngine.evaluate(
      ruleSet: ruleSet,
      ocrText: baseResult.rawText,
      preprocessResult: preprocessResult,
      sourcePackage: sourcePackage,
      sourcePaymentChannel: sourceInfo?.paymentChannel,
      traceSink: (trace) {
        ruleTrace = trace;
        traceSink?.call(
          BillExtractionTraceEvent(
            stage: 'billing_rule',
            data: trace.toDebugJson(),
          ),
        );
      },
    );

    final mergedResult = _mergeRuleResult(
      baseResult,
      ruleResult,
      sourceInfo: sourceInfo,
      preprocessResult: preprocessResult,
      ruleTrace: ruleTrace,
    );
    final rejectReasons = _rejectReasons(ruleResult, mergedResult);
    final accepted = rejectReasons.isEmpty;

    return FastBillingRuleEvaluation(
      result: mergedResult.copyWithFastBillingRule(
        fastBillingAccepted: accepted,
        fastBillingRejectReasons: rejectReasons,
      ),
      accepted: accepted,
      rejectReasons: rejectReasons,
      trace: ruleTrace,
    );
  }

  OcrResult _mergeRuleResult(
    OcrResult baseResult,
    BillingRuleResult ruleResult, {
    ScreenshotSourceInfo? sourceInfo,
    OcrPreprocessResult? preprocessResult,
    BillingRuleTrace? ruleTrace,
  }) {
    final details = <String, dynamic>{
      ...?baseResult.details,
      ...?ruleResult.details,
      if (ruleResult.matchedTemplateId != null)
        'billing_rule_template_id': ruleResult.matchedTemplateId,
      if (ruleResult.confidence > 0)
        'billing_rule_confidence': ruleResult.confidence,
    };
    final sourcePaymentChannel = sourceInfo?.paymentChannel?.trim();
    final paymentChannel = ruleResult.paymentChannel ??
        (sourcePaymentChannel == null || sourcePaymentChannel.isEmpty
            ? null
            : sourcePaymentChannel) ??
        baseResult.paymentChannel;
    final detailsText =
        details.isEmpty ? baseResult.detailsText : detailsMapToText(details);

    return baseResult.copyWithFastBillingRule(
      amount: ruleResult.amount ?? baseResult.amount,
      note: ruleResult.note ?? baseResult.note,
      time: ruleResult.time ??
          baseResult.time ??
          _timeFromMillis(sourceInfo?.screenshotTimeMillis),
      paymentMethod: ruleResult.paymentMethod ?? baseResult.paymentMethod,
      paymentChannel: paymentChannel,
      counterparty: ruleResult.counterparty ?? baseResult.counterparty,
      merchantFullName:
          ruleResult.merchantFullName ?? baseResult.merchantFullName,
      acquirer: ruleResult.acquirer ?? baseResult.acquirer,
      details: details.isEmpty ? baseResult.details : details,
      detailsText: detailsText,
      preprocessResult: preprocessResult,
      billingRuleResult: ruleResult,
      billingRuleTrace: ruleTrace,
    );
  }

  List<String> _rejectReasons(BillingRuleResult ruleResult, OcrResult result) {
    final reasons = <String>[];
    if (ruleResult.matchedTemplateId == null) {
      reasons.add('no_rule_match');
    }
    if (ruleResult.confidence < minimumConfidence) {
      reasons.add('low_confidence');
    }
    if (result.amount == null || result.amount!.abs() <= 0) {
      reasons.add('missing_amount');
    }
    if (result.paymentChannel == null ||
        result.paymentChannel!.trim().isEmpty) {
      reasons.add('missing_payment_channel');
    }
    if (result.time == null) {
      reasons.add('missing_time');
    }
    return reasons;
  }
}

DateTime? _timeFromMillis(int? millis) {
  if (millis == null || millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

String? _sourcePackageForRuleMatch(ScreenshotSourceInfo? sourceInfo) {
  if (sourceInfo == null) return null;
  if (sourceInfo.hasPaymentChannel || sourceInfo.confidence >= 0.75) {
    return sourceInfo.packageName;
  }
  return null;
}
