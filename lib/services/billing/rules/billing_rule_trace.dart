import 'billing_rule_models.dart';

class BillingRuleTrace {
  final String traceId;
  final String rulesVersion;
  final String? sourcePackage;
  final String? sourceAppName;
  final String? sourcePaymentChannel;
  final String ocrText;
  final OcrPreprocessResult? preprocessResult;
  final List<String> matchedRuleIds;
  final Map<String, List<BillingRuleFieldEvidence>> fieldEvidence;
  final BillingRuleResult? result;
  final int? durationMs;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> debugMessages;

  const BillingRuleTrace({
    required this.traceId,
    required this.rulesVersion,
    required this.ocrText,
    this.sourcePackage,
    this.sourceAppName,
    this.sourcePaymentChannel,
    this.preprocessResult,
    this.matchedRuleIds = const [],
    this.fieldEvidence = const {},
    this.result,
    this.durationMs,
    this.startedAt,
    this.completedAt,
    this.debugMessages = const [],
  });

  Map<String, dynamic> toJson() => {
        'trace_id': traceId,
        'rules_version': rulesVersion,
        'source_package': sourcePackage,
        'source_app_name': sourceAppName,
        'source_payment_channel': sourcePaymentChannel,
        'ocr_text': ocrText,
        'preprocess': preprocessResult?.toJson(),
        'matched_rule_ids': matchedRuleIds,
        'field_evidence': fieldEvidence.map(
          (field, evidence) => MapEntry(
            field,
            evidence.map((item) => item.toJson()).toList(),
          ),
        ),
        'result': result?.toJson(),
        'duration_ms': durationMs,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'debug_messages': debugMessages,
      };

  Map<String, dynamic> toDebugJson() => toJson();
}
