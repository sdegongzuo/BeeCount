import 'dart:convert';

import '../../data/repositories/billing_job_repository.dart';
import 'ocr_service.dart';
import 'rules/personal_rule_lifecycle_service.dart';

typedef ConfirmedBillCreator = Future<int> Function(OcrResult result);
typedef PersonalRuleCorrectionApplier = Future<PersonalRuleLifecycleResult>
    Function(PersonalRuleCorrection correction);

class PendingBillDraft {
  final int jobId;
  final String imagePath;
  final OcrResult candidate;

  const PendingBillDraft({
    required this.jobId,
    required this.imagePath,
    required this.candidate,
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

  const PendingBillConfirmationService({
    required this.repo,
    required this.createTransaction,
    required this.applyCorrection,
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
    );
  }

  Future<PendingBillConfirmationResult> confirm({
    required int jobId,
    required double amount,
    required DateTime time,
    required String supplementalNote,
    required bool rememberForSimilarBills,
  }) async {
    final job = await repo.findById(jobId);
    if (job == null || job.status != BillingJobStatus.awaitingConfirmation) {
      throw StateError('billing_job_not_awaiting_confirmation');
    }
    final stored = jsonDecode(job.finalResultJson!) as Map<String, dynamic>;
    final original = OcrResult.fromJson(stored);
    final rawText = stored['rawText'] as String? ?? job.rawText ?? '';
    final supplement = supplementalNote.trim();
    final transactionNote = supplement.isEmpty
        ? original.note
        : [original.note, supplement]
            .where((part) => part != null && part.trim().isNotEmpty)
            .join('\n');
    final confirmedJson = <String, dynamic>{
      ...stored,
      'amount': amount,
      'time': time.toIso8601String(),
      'supplemental_note': supplement.isEmpty ? null : supplement,
    };
    final transactionJson = <String, dynamic>{
      ...confirmedJson,
      'note': transactionNote,
    };
    final confirmed = OcrResult.fromJson(transactionJson);
    final transactionId = await createTransaction(confirmed);
    await repo.updateFinalResultJson(job.id, jsonEncode(confirmedJson));
    await repo.updateTransactionId(job.id, transactionId);
    await repo.updateStage(job.id, BillingJobStage.completed);
    await repo.markSucceeded(job.id);

    final results = <PersonalRuleLifecycleResult>[];
    if (rememberForSimilarBills) {
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
