import 'dart:convert';
import 'dart:io';

import 'package:beecount/ai/tasks/bill_extraction_task.dart';

import 'billing_rule_models.dart';
import 'billing_rule_trace.dart';

typedef AiRuleReviewClock = DateTime Function();

class AiRuleReviewPayload {
  final String sampleId;
  final String? sourcePackage;
  final String? sourcePaymentChannel;
  final String ocrText;
  final BillingRuleTrace ruleTrace;
  final BillingRuleResult ruleResult;
  final Map<String, dynamic> aiResult;
  final Map<String, dynamic> userFinalResult;
  final DateTime createdAt;

  const AiRuleReviewPayload({
    required this.sampleId,
    required this.ocrText,
    required this.ruleTrace,
    required this.ruleResult,
    required this.aiResult,
    required this.userFinalResult,
    required this.createdAt,
    this.sourcePackage,
    this.sourcePaymentChannel,
  });

  Map<String, dynamic> toJson() => {
        'sample_id': sampleId,
        'source_package': sourcePackage,
        'source_payment_channel': sourcePaymentChannel,
        'ocr_text': ocrText,
        'rule_trace': ruleTrace.toJson(),
        'rule_result': ruleResult.toJson(),
        'ai_result': aiResult,
        'user_final_result': userFinalResult,
        'created_at': createdAt.toIso8601String(),
      };
}

class AiRuleFieldStrategy {
  final String field;
  final Object? currentRuleValue;
  final Object? aiValue;
  final Object? userFinalValue;
  final String recommendation;
  final List<Map<String, dynamic>> evidence;

  const AiRuleFieldStrategy({
    required this.field,
    required this.currentRuleValue,
    required this.aiValue,
    required this.userFinalValue,
    required this.recommendation,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'current_rule_value': _jsonValue(currentRuleValue),
        'ai_value': _jsonValue(aiValue),
        'user_final_value': _jsonValue(userFinalValue),
        'recommendation': recommendation,
        'evidence': evidence,
      };
}

class AiRuleReviewSuggestion {
  final AiRuleReviewPayload payload;
  final List<String> diagnostics;
  final List<AiRuleFieldStrategy> fieldStrategies;
  final List<String> reasons;
  final List<String> risks;
  final bool requiresHumanReview;
  final bool manualTomlConversionRequired;
  final bool autoActivationAllowed;

  const AiRuleReviewSuggestion({
    required this.payload,
    required this.diagnostics,
    required this.fieldStrategies,
    required this.reasons,
    required this.risks,
    this.requiresHumanReview = true,
    this.manualTomlConversionRequired = true,
    this.autoActivationAllowed = false,
  });

  Map<String, dynamic> toJson() => {
        'sample_id': payload.sampleId,
        'diagnostics': diagnostics,
        'field_strategies':
            fieldStrategies.map((strategy) => strategy.toJson()).toList(),
        'reasons': reasons,
        'risks': risks,
        'requires_human_review': requiresHumanReview,
        'manual_toml_conversion_required': manualTomlConversionRequired,
        'auto_activation_allowed': autoActivationAllowed,
        'payload': payload.toJson(),
      };
}

class AiRuleReviewService {
  static const suggestionDirectoryName = 'ai_suggestions';

  final Directory reviewDirectory;
  final AiRuleReviewClock clock;

  const AiRuleReviewService({
    required this.reviewDirectory,
    AiRuleReviewClock? clock,
  }) : clock = clock ?? DateTime.now;

  AiRuleReviewPayload buildPayloadFromUserCorrection({
    required String sampleId,
    required String ocrText,
    required BillingRuleTrace trace,
    required BillingRuleResult ruleResult,
    required BillInfo aiResult,
    required BillInfo userFinalResult,
    String? sourcePackage,
    String? sourcePaymentChannel,
  }) {
    return AiRuleReviewPayload(
      sampleId: sampleId,
      sourcePackage: sourcePackage ?? trace.sourcePackage,
      sourcePaymentChannel: sourcePaymentChannel ?? trace.sourcePaymentChannel,
      ocrText: ocrText,
      ruleTrace: trace,
      ruleResult: ruleResult,
      aiResult: aiResult.toJson(),
      userFinalResult: userFinalResult.toJson(),
      createdAt: clock().toUtc(),
    );
  }

  AiRuleReviewSuggestion createSuggestion(
    AiRuleReviewPayload payload, {
    List<String> diagnostics = const [],
    List<String> reasons = const [],
    List<String> risks = const [],
  }) {
    final strategies = _buildFieldStrategies(payload);
    return AiRuleReviewSuggestion(
      payload: payload,
      diagnostics: diagnostics,
      fieldStrategies: strategies,
      reasons: reasons.isEmpty
          ? const ['AI 建议仅作为规则评估证据，必须人工转换为 TOML 后才能进入规则包。']
          : reasons,
      risks: risks.isEmpty
          ? const ['单一样本不足以证明规则泛化能力，激活前需要 rule_eval 和人工审核。']
          : risks,
    );
  }

  Future<File> saveSuggestion(AiRuleReviewSuggestion suggestion) async {
    final directory = Directory(
      '${reviewDirectory.path}/$suggestionDirectoryName',
    );
    await directory.create(recursive: true);
    final timestamp = clock()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final sampleId = _safeFileName(suggestion.payload.sampleId);
    final file = File('${directory.path}/${sampleId}_$timestamp.review.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(suggestion.toJson())}\n');
    return file;
  }

  List<AiRuleFieldStrategy> _buildFieldStrategies(
    AiRuleReviewPayload payload,
  ) {
    final ruleJson = payload.ruleResult.toJson();
    final fields = <String>{
      ...ruleJson.keys,
      ...payload.aiResult.keys,
      ...payload.userFinalResult.keys,
    }..removeWhere((field) => field == 'fields');

    final strategies = <AiRuleFieldStrategy>[];
    for (final field in fields) {
      final ruleValue = ruleJson[field];
      final aiValue = payload.aiResult[field];
      final userValue = payload.userFinalResult[field];
      if (_sameJsonValue(ruleValue, userValue)) continue;

      final evidence = payload.ruleTrace.fieldEvidence[field]
              ?.map((item) => item.toJson())
              .toList() ??
          const <Map<String, dynamic>>[];
      strategies.add(
        AiRuleFieldStrategy(
          field: field,
          currentRuleValue: ruleValue,
          aiValue: aiValue,
          userFinalValue: userValue,
          recommendation:
              'Review extractor/parser coverage for "$field" and convert any accepted change into TOML manually.',
          evidence: evidence,
        ),
      );
    }

    return strategies;
  }
}

bool _sameJsonValue(Object? left, Object? right) {
  return jsonEncode(_jsonValue(left)) == jsonEncode(_jsonValue(right));
}

String _safeFileName(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safe.isEmpty ? 'sample' : safe;
}

dynamic _jsonValue(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value is Enum) return value.name;
  if (value is List) return value.map(_jsonValue).toList();
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _jsonValue(item)),
    );
  }
  return value;
}
