import 'dart:convert';

import '../../data/repositories/billing_job_repository.dart';
import '../system/logger_service.dart';
import 'classification_match_evidence.dart';
import 'ocr_service.dart';
import 'rules/personal_rule_lifecycle_service.dart';

/// 在账单任务创建时固化的账本中创建已确认交易。
typedef ConfirmedBillCreator = Future<int> Function(
  OcrResult result, {
  required int ledgerId,
});

/// 将一项用户确认的提取修正应用到个人规则。
typedef PersonalRuleCorrectionApplier = Future<PersonalRuleLifecycleResult>
    Function(PersonalRuleCorrection correction);

/// 加载确认页可选择的分类。
typedef ConfirmableCategoriesLoader = Future<List<ConfirmableCategory>>
    Function();

/// 在任务固化的账本或全局作用域中记住分类规则。
typedef CategoryRuleRememberer = Future<void> Function({
  required String matchText,
  required int categoryId,
  required bool global,
  required int ledgerId,
});

/// 独立于 OCR 规则记住用户补充信息。
typedef NotePreferenceRememberer = Future<void> Function({
  required String matchText,
  required String supplementalNote,
});

/// 接收仅供诊断的可选学习原始错误。
typedef PendingBillLearningLogger = void Function(
  String component,
  String message,
  Object error,
  StackTrace stackTrace,
);

class ConfirmableCategory {
  final int id;
  final String name;
  const ConfirmableCategory(this.id, this.name);
}

class PendingBillDraft {
  final int jobId;

  /// 账单任务首次接收图片时固化的账本。
  ///
  /// null 表示无法安全确认的历史任务。
  final int? ledgerId;
  final String imagePath;
  final OcrResult candidate;
  final List<ConfirmableCategory> categories;

  const PendingBillDraft({
    required this.jobId,
    required this.ledgerId,
    required this.imagePath,
    required this.candidate,
    this.categories = const [],
  });
}

class PendingBillConfirmationResult {
  final int transactionId;
  final List<PersonalRuleLifecycleResult> ruleResults;
  final List<PendingBillLearningError> learningErrors;

  const PendingBillConfirmationResult({
    required this.transactionId,
    required this.ruleResults,
    this.learningErrors = const [],
  });

  PendingBillLearningStatus get learningStatus => learningErrors.isEmpty
      ? PendingBillLearningStatus.completed
      : PendingBillLearningStatus.partiallyFailed;
}

enum PendingBillLearningKind {
  extractionCorrection,
  categoryRule,
  notePreference,
}

/// 稳定且可安全展示的可选学习失败原因。
enum PendingBillLearningReason {
  sourceInfoInvalid,
  extractionCorrectionFailed,
  categoryRuleFailed,
  notePreferenceFailed,
}

enum PendingBillLearningStatus {
  completed,
  partiallyFailed,
}

class PendingBillLearningError {
  final PendingBillLearningKind kind;
  final String target;

  /// 稳定且可安全展示的原因；特意不包含原始异常。
  final PendingBillLearningReason reason;

  const PendingBillLearningError({
    required this.kind,
    required this.target,
    required this.reason,
  });
}

/// 确认请求在建账前被拒绝时使用的稳定错误码。
enum PendingBillConfirmationErrorCode {
  billingJobNotAwaitingConfirmation,
  billingJobResultMissing,
  billingJobLedgerMissing,
  rememberedCategoryRequired,
}

/// [PendingBillConfirmationService.confirm] 的类型化拒绝。
final class PendingBillConfirmationException implements Exception {
  const PendingBillConfirmationException(this.code);

  /// 请求在交易创建前被拒绝的稳定原因。
  final PendingBillConfirmationErrorCode code;
}

/// 待确认账单的公开功能边界：读取 OCR 候选、创建当前交易并按用户选择学习规则。
class PendingBillConfirmationService {
  final BillingJobRepository repo;
  final ConfirmedBillCreator createTransaction;
  final PersonalRuleCorrectionApplier applyCorrection;
  final ConfirmableCategoriesLoader? loadCategories;
  final CategoryRuleRememberer? rememberCategory;
  final NotePreferenceRememberer? rememberNotePreference;
  final PendingBillLearningLogger logLearningFailure;

  const PendingBillConfirmationService({
    required this.repo,
    required this.createTransaction,
    required this.applyCorrection,
    this.loadCategories,
    this.rememberCategory,
    this.rememberNotePreference,
    this.logLearningFailure = _logLearningFailure,
  });

  /// 读取仍待确认的账单草稿；任务不存在或状态不可确认时返回 null。
  Future<PendingBillDraft?> loadDraft(int jobId) async {
    final job = await repo.findById(jobId);
    if (job == null ||
        job.status != BillingJobStatus.awaitingConfirmation ||
        job.finalResultJson == null) {
      return null;
    }
    final json = jsonDecode(job.finalResultJson!) as Map<String, dynamic>;
    return PendingBillDraft(
      jobId: job.id,
      ledgerId: job.ledgerId,
      imagePath: job.imagePath,
      candidate: OcrResult.fromJson(json),
      categories: await loadCategories?.call() ?? const [],
    );
  }

  /// 创建确认后的交易，并分别执行用户明确选择的提取、分类和备注学习。
  ///
  /// 交易始终写入任务固化的账本；缺少账本身份等前置条件时抛出
  /// [PendingBillConfirmationException]，可选学习失败则通过结果返回。
  Future<PendingBillConfirmationResult> confirm({
    required int jobId,
    required double amount,
    required DateTime time,
    required String supplementalNote,
    @Deprecated('Use the three independent remember options instead.')
    bool? rememberForSimilarBills,
    bool rememberExtractionCorrections = false,
    bool rememberCategoryRule = false,
    bool rememberNotePreference = false,
    int? categoryId,
    bool categoryRuleGlobal = false,
  }) async {
    final job = await repo.findById(jobId);
    if (job == null || job.status != BillingJobStatus.awaitingConfirmation) {
      throw const PendingBillConfirmationException(
        PendingBillConfirmationErrorCode.billingJobNotAwaitingConfirmation,
      );
    }
    if (job.finalResultJson == null) {
      throw const PendingBillConfirmationException(
        PendingBillConfirmationErrorCode.billingJobResultMissing,
      );
    }
    final ledgerId = job.ledgerId;
    if (ledgerId == null) {
      throw const PendingBillConfirmationException(
        PendingBillConfirmationErrorCode.billingJobLedgerMissing,
      );
    }
    final legacyRememberAll = rememberForSimilarBills ?? false;
    final rememberExtraction =
        rememberExtractionCorrections || legacyRememberAll;
    final rememberCategory = rememberCategoryRule || legacyRememberAll;
    final rememberNote = rememberNotePreference || legacyRememberAll;
    if (rememberCategory && categoryId == null) {
      throw const PendingBillConfirmationException(
        PendingBillConfirmationErrorCode.rememberedCategoryRequired,
      );
    }
    final stored = jsonDecode(job.finalResultJson!) as Map<String, dynamic>;
    final original = OcrResult.fromJson(stored);
    final rawText = stored['rawText'] as String? ?? job.rawText ?? '';
    final supplement = supplementalNote.trim();
    final originalDetails = original.details ?? const <String, dynamic>{};
    final confirmedJson = <String, dynamic>{
      ...stored,
      'amount': amount,
      'time': time.toIso8601String(),
      if (categoryId != null) 'suggestedCategoryId': categoryId,
      'supplemental_note': supplement.isEmpty ? null : supplement,
      'details': {
        ...originalDetails,
        if (supplement.isNotEmpty) 'supplemental_note': supplement,
      },
    };
    final transactionJson = <String, dynamic>{
      ...confirmedJson,
      'note': original.note,
    };
    final confirmed = OcrResult.fromJson(transactionJson);
    final transactionId = await createTransaction(
      confirmed,
      ledgerId: ledgerId,
    );
    await repo.updateFinalResultJson(job.id, jsonEncode(confirmedJson));
    await repo.updateTransactionId(job.id, transactionId);
    await repo.updateStage(job.id, BillingJobStage.completed);
    await repo.markSucceeded(job.id);

    final results = <PersonalRuleLifecycleResult>[];
    final learningErrors = <PendingBillLearningError>[];
    if (rememberExtraction) {
      (String?, String?)? source;
      try {
        source = _source(job.sourceInfoJson);
      } catch (error, stackTrace) {
        logLearningFailure(
          'PendingBillConfirmation',
          '解析可选来源证据失败',
          error,
          stackTrace,
        );
        learningErrors.add(const PendingBillLearningError(
          kind: PendingBillLearningKind.extractionCorrection,
          target: 'source_info',
          reason: PendingBillLearningReason.sourceInfoInvalid,
        ));
      }
      final changedFields = <MapEntry<String, Object>>[];
      if (original.amount != amount) {
        changedFields.add(MapEntry('amount', amount));
      }
      if (original.time != time) {
        changedFields.add(MapEntry('time', time));
      }
      final parsedSource = source;
      for (final field in parsedSource == null
          ? const <MapEntry<String, Object>>[]
          : changedFields) {
        try {
          results.add(await applyCorrection(PersonalRuleCorrection(
            field: field.key,
            confirmedValue: field.value,
            normalizedOcr: rawText,
            sourcePackage: parsedSource!.$1,
            sourceAppName: parsedSource.$2,
          )));
        } catch (error, stackTrace) {
          logLearningFailure(
            'PendingBillConfirmation',
            '保存提取修正失败',
            error,
            stackTrace,
          );
          learningErrors.add(PendingBillLearningError(
            kind: PendingBillLearningKind.extractionCorrection,
            target: field.key,
            reason: PendingBillLearningReason.extractionCorrectionFailed,
          ));
        }
      }
    }
    if (rememberCategory || rememberNote) {
      final matchText = classificationMatchText(
        merchantFullName: original.merchantFullName,
        counterparty: original.counterparty,
        structuredSummary: original.note,
      );
      if (supplement.isNotEmpty &&
          matchText != null &&
          rememberNote &&
          this.rememberNotePreference != null) {
        try {
          await this.rememberNotePreference!(
            matchText: matchText,
            supplementalNote: supplement,
          );
        } catch (error, stackTrace) {
          logLearningFailure(
            'PendingBillConfirmation',
            '保存备注偏好失败',
            error,
            stackTrace,
          );
          learningErrors.add(PendingBillLearningError(
            kind: PendingBillLearningKind.notePreference,
            target: matchText,
            reason: PendingBillLearningReason.notePreferenceFailed,
          ));
        }
      }
      if (categoryId != null &&
          matchText != null &&
          rememberCategory &&
          this.rememberCategory != null) {
        try {
          await this.rememberCategory!(
            matchText: matchText,
            categoryId: categoryId,
            global: categoryRuleGlobal,
            ledgerId: ledgerId,
          );
        } catch (error, stackTrace) {
          logLearningFailure(
            'PendingBillConfirmation',
            '保存分类规则失败',
            error,
            stackTrace,
          );
          learningErrors.add(PendingBillLearningError(
            kind: PendingBillLearningKind.categoryRule,
            target: matchText,
            reason: PendingBillLearningReason.categoryRuleFailed,
          ));
        }
      }
    }
    return PendingBillConfirmationResult(
      transactionId: transactionId,
      ruleResults: results,
      learningErrors: List.unmodifiable(learningErrors),
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
  // 日志只用于诊断，绝不能把可选学习失败升级为确认失败；这也适用于
  // 后台或测试 isolate 尚未初始化 Flutter bindings 的场景。
  try {
    logger.error(component, message, error, stackTrace);
  } catch (_) {}
}
