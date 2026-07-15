import 'dart:convert';

import '../../data/repositories/billing_job_repository.dart';
import 'ocr_service.dart';
import 'rules/personal_rule_lifecycle_service.dart';

typedef ConfirmedBillCreator = Future<int> Function(OcrResult result);
typedef PersonalRuleCorrectionApplier = Future<PersonalRuleLifecycleResult>
    Function(PersonalRuleCorrection correction);
typedef ConfirmableCategoriesLoader = Future<List<ConfirmableCategory>>
    Function();
typedef CategoryRuleRememberer = Future<void> Function({
  required String matchText,
  required int categoryId,
  required bool global,
});
typedef NotePreferenceRememberer = Future<void> Function({
  required String matchText,
  required String supplementalNote,
});

class ConfirmableCategory {
  final int id;
  final String name;
  const ConfirmableCategory(this.id, this.name);
}

class PendingBillDraft {
  final int jobId;
  final String imagePath;
  final OcrResult candidate;
  final List<ConfirmableCategory> categories;

  const PendingBillDraft({
    required this.jobId,
    required this.imagePath,
    required this.candidate,
    this.categories = const [],
  });
}

class PendingBillConfirmationResult {
  final int transactionId;
  final List<PersonalRuleLifecycleResult> ruleResults;

  const PendingBillConfirmationResult({
    required this.transactionId,
    required this.ruleResults,
  });
}

/// 待确认账单的公开功能边界：读取 OCR 候选、创建当前交易并按用户选择学习规则。
class PendingBillConfirmationService {
  final BillingJobRepository repo;
  final ConfirmedBillCreator createTransaction;
  final PersonalRuleCorrectionApplier applyCorrection;
  final ConfirmableCategoriesLoader? loadCategories;
  final CategoryRuleRememberer? rememberCategory;
  final NotePreferenceRememberer? rememberNotePreference;

  const PendingBillConfirmationService({
    required this.repo,
    required this.createTransaction,
    required this.applyCorrection,
    this.loadCategories,
    this.rememberCategory,
    this.rememberNotePreference,
  });

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
      imagePath: job.imagePath,
      candidate: OcrResult.fromJson(json),
      categories: await loadCategories?.call() ?? const [],
    );
  }

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
      throw StateError('billing_job_not_awaiting_confirmation');
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
    final transactionId = await createTransaction(confirmed);
    await repo.updateFinalResultJson(job.id, jsonEncode(confirmedJson));
    await repo.updateTransactionId(job.id, transactionId);
    await repo.updateStage(job.id, BillingJobStage.completed);
    await repo.markSucceeded(job.id);

    final legacyRememberAll = rememberForSimilarBills ?? false;
    final rememberExtraction =
        rememberExtractionCorrections || legacyRememberAll;
    final rememberCategory = rememberCategoryRule || legacyRememberAll;
    final rememberNote = rememberNotePreference || legacyRememberAll;
    final results = <PersonalRuleLifecycleResult>[];
    if (rememberExtraction) {
      final source = _source(job.sourceInfoJson);
      final changedFields = <MapEntry<String, Object>>[];
      if (original.amount != amount) {
        changedFields.add(MapEntry('amount', amount));
      }
      if (original.time != time) {
        changedFields.add(MapEntry('time', time));
      }
      for (final field in changedFields) {
        results.add(await applyCorrection(PersonalRuleCorrection(
          field: field.key,
          confirmedValue: field.value,
          normalizedOcr: rawText,
          sourcePackage: source.$1,
          sourceAppName: source.$2,
        )));
      }
    }
    if (rememberCategory || rememberNote) {
      final matchText = _ruleMatchText(original);
      if (supplement.isNotEmpty &&
          matchText != null &&
          rememberNote &&
          this.rememberNotePreference != null) {
        await this.rememberNotePreference!(
          matchText: matchText,
          supplementalNote: supplement,
        );
      }
      if (categoryId != null &&
          matchText != null &&
          rememberCategory &&
          this.rememberCategory != null) {
        await this.rememberCategory!(
          matchText: matchText,
          categoryId: categoryId,
          global: categoryRuleGlobal,
        );
      }
    }
    return PendingBillConfirmationResult(
      transactionId: transactionId,
      ruleResults: results,
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

String? _ruleMatchText(OcrResult result) {
  for (final candidate in <String?>[
    result.merchantFullName,
    result.counterparty,
    _merchantFromStructuredSummary(result.note),
  ]) {
    final normalized = candidate?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

String? _merchantFromStructuredSummary(String? summary) {
  if (summary == null || summary.trim().isEmpty) return null;
  return RegExp(r'(?:^|\n)\s*商户\s*[：:]\s*([^\n]+)')
      .firstMatch(summary)
      ?.group(1)
      ?.trim();
}
