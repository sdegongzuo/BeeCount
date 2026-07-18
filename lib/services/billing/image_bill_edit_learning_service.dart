import 'dart:convert';

import '../../data/repositories/billing_job_repository.dart';
import '../system/logger_service.dart';
import 'classification_match_evidence.dart';
import 'ocr_service.dart';
import 'pending_bill_confirmation_service.dart';
import 'rules/personal_rule_lifecycle_service.dart';

/// OCR evidence retained for a transaction created from a shared image.
class ImageBillEditLearningContext {
  const ImageBillEditLearningContext({
    required this.transactionId,
    required this.ledgerId,
    required this.original,
    required this.rawText,
    required this.sourceInfoJson,
  });

  final int transactionId;
  final int ledgerId;
  final OcrResult original;
  final String rawText;
  final String? sourceInfoJson;

  /// Returns only an appended user note. Rewriting any byte of the original
  /// structured summary is not safe evidence for a reusable note preference.
  String? supplementalNoteFrom(String? editedNote) {
    final edited = editedNote?.trim() ?? '';
    if (edited.isEmpty) return null;
    final structured = original.note?.trim() ?? '';
    if (structured.isEmpty) return edited;
    if (edited == structured || !edited.startsWith(structured)) return null;
    final suffix = edited.substring(structured.length).trim();
    return suffix.isEmpty ? null : suffix;
  }
}

class ImageBillEditLearningResult {
  const ImageBillEditLearningResult({
    this.ruleResults = const [],
    this.learningErrors = const [],
  });

  final List<PersonalRuleLifecycleResult> ruleResults;
  final List<PendingBillLearningError> learningErrors;
}

/// Learns explicit edits only when the transaction can be traced to OCR
/// evidence from a shared image.
class ImageBillEditLearningService {
  const ImageBillEditLearningService({
    required this.jobs,
    required this.applyCorrection,
    this.rememberCategory,
    this.rememberNotePreference,
    this.logLearningFailure = _logLearningFailure,
  });

  final BillingJobRepository jobs;
  final PersonalRuleCorrectionApplier applyCorrection;
  final CategoryRuleRememberer? rememberCategory;
  final NotePreferenceRememberer? rememberNotePreference;
  final PendingBillLearningLogger logLearningFailure;

  Future<ImageBillEditLearningContext?> loadContext(
    int transactionId, {
    int? fallbackLedgerId,
  }) async {
    final job = await jobs.findByTransactionId(transactionId);
    if (job == null) return null;
    final ledgerId = job.ledgerId ?? fallbackLedgerId;
    if (ledgerId == null) return null;
    // 待确认任务会把用户确认后的候选写入 finalResultJson；
    // 可直接创建交易的任务不经过该分支，交易实际使用的是
    // ruleResultJson。两者都是交易可追溯的 OCR 结果，最终确认值优先。
    // 历史 AI 阶段曾用 Map.toString() 写入非 JSON 的最终结果；
    // 解析失败时必须继续尝试规则结果，可选学习不得阻断交易编辑。
    final candidates = <String?>[job.finalResultJson, job.ruleResultJson];
    for (final storedJson in candidates) {
      if (storedJson == null || storedJson.isEmpty) continue;
      try {
        final stored = jsonDecode(storedJson) as Map<String, dynamic>;
        final original = OcrResult.fromJson(stored);
        return ImageBillEditLearningContext(
          transactionId: transactionId,
          ledgerId: ledgerId,
          original: original,
          rawText: stored['rawText'] as String? ?? job.rawText ?? '',
          sourceInfoJson: job.sourceInfoJson,
        );
      } catch (error, stackTrace) {
        logLearningFailure(
          'ImageBillEditLearning',
          '解析可选 OCR 学习上下文失败',
          error,
          stackTrace,
        );
      }
    }
    return null;
  }

  /// Learns only non-null fields. Callers pass fields the user changed and
  /// explicitly chose to remember; omitted fields remain current-only.
  Future<ImageBillEditLearningResult> remember({
    required ImageBillEditLearningContext context,
    double? amount,
    DateTime? time,
    int? categoryId,
    String? supplementalNote,
    bool categoryGlobal = false,
  }) async {
    final results = <PersonalRuleLifecycleResult>[];
    final errors = <PendingBillLearningError>[];
    if (amount != null || time != null) {
      (String?, String?)? source;
      try {
        source = _source(context.sourceInfoJson);
      } catch (error, stackTrace) {
        logLearningFailure(
          'ImageBillEditLearning',
          '解析可选来源证据失败',
          error,
          stackTrace,
        );
        errors.add(const PendingBillLearningError(
          kind: PendingBillLearningKind.extractionCorrection,
          target: 'source_info',
          reason: PendingBillLearningReason.sourceInfoInvalid,
        ));
      }
      final fields = <MapEntry<String, Object>>[
        if (amount != null) MapEntry('amount', amount),
        if (time != null) MapEntry('time', time),
      ];
      final parsedSource = source;
      if (parsedSource != null) {
        for (final field in fields) {
          try {
            results.add(await applyCorrection(PersonalRuleCorrection(
              field: field.key,
              confirmedValue: field.value,
              normalizedOcr: context.rawText,
              sourcePackage: parsedSource.$1,
              sourceAppName: parsedSource.$2,
            )));
          } catch (error, stackTrace) {
            logLearningFailure(
              'ImageBillEditLearning',
              '保存提取修正失败',
              error,
              stackTrace,
            );
            errors.add(PendingBillLearningError(
              kind: PendingBillLearningKind.extractionCorrection,
              target: field.key,
              reason: PendingBillLearningReason.extractionCorrectionFailed,
            ));
          }
        }
      }
    }
    if (categoryId != null && rememberCategory != null) {
      final matchText = classificationMatchText(
        merchantFullName: context.original.merchantFullName,
        counterparty: context.original.counterparty,
        structuredSummary: context.original.note,
      );
      if (matchText != null) {
        try {
          await rememberCategory!(
            matchText: matchText,
            categoryId: categoryId,
            global: categoryGlobal,
            ledgerId: context.ledgerId,
          );
        } catch (error, stackTrace) {
          logLearningFailure(
            'ImageBillEditLearning',
            '保存分类规则失败',
            error,
            stackTrace,
          );
          errors.add(PendingBillLearningError(
            kind: PendingBillLearningKind.categoryRule,
            target: matchText,
            reason: PendingBillLearningReason.categoryRuleFailed,
          ));
        }
      }
    }
    final note = supplementalNote?.trim() ?? '';
    if (note.isNotEmpty && rememberNotePreference != null) {
      final matchText = classificationMatchText(
        merchantFullName: context.original.merchantFullName,
        counterparty: context.original.counterparty,
        structuredSummary: context.original.note,
      );
      if (matchText != null) {
        try {
          await rememberNotePreference!(
            matchText: matchText,
            supplementalNote: note,
          );
        } catch (error, stackTrace) {
          logLearningFailure(
            'ImageBillEditLearning',
            '保存备注偏好失败',
            error,
            stackTrace,
          );
          errors.add(PendingBillLearningError(
            kind: PendingBillLearningKind.notePreference,
            target: matchText,
            reason: PendingBillLearningReason.notePreferenceFailed,
          ));
        }
      }
    }
    return ImageBillEditLearningResult(
      ruleResults: List.unmodifiable(results),
      learningErrors: List.unmodifiable(errors),
    );
  }
}

(String?, String?) _source(String? sourceInfoJson) {
  if (sourceInfoJson == null || sourceInfoJson.isEmpty) return (null, null);
  final json = jsonDecode(sourceInfoJson) as Map<String, dynamic>;
  return (
    (json['sourceAppPackage'] ?? json['sourcePackage']) as String?,
    json['sourceAppName'] as String?,
  );
}

void _logLearningFailure(
  String component,
  String message,
  Object error,
  StackTrace stackTrace,
) {
  try {
    logger.error(component, message, error, stackTrace);
  } catch (_) {}
}
