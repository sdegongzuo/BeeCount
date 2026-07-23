import '../db.dart';

/// Billing job stage constants matching the stored string values.
abstract final class BillingJobStage {
  static const received = 'received';
  static const ocrDone = 'ocr_done';
  static const ruleDone = 'rule_done';
  static const transactionCreated = 'transaction_created';
  static const completed = 'completed';

  /// Legacy terminal stage retained only for upgrading existing jobs.
  static const aiDone = 'ai_done';
}

/// Billing job status constants matching the stored string values.
abstract final class BillingJobStatus {
  static const pending = 'pending';
  static const succeeded = 'succeeded';
  static const retryableFailed = 'retryable_failed';
  static const awaitingConfirmation = 'awaiting_confirmation';
  static const failed = 'failed';
}

/// An opaque claim version used to fence writes from an expired runner.
///
/// [leaseUntil] is written atomically by [claimJobLease]. A later claimant
/// replaces it, so mutations carrying an older value fail their SQL WHERE CAS.
class BillingJobLease {
  final int jobId;
  final DateTime leaseUntil;

  const BillingJobLease({required this.jobId, required this.leaseUntil});
}

final class BillingJobLeaseLost implements Exception {
  final BillingJobLease lease;

  const BillingJobLeaseLost(this.lease);

  @override
  String toString() => 'BillingJobLeaseLost(jobId=${lease.jobId})';
}

class BillingRuleExecutionSnapshot {
  final int rulePackageVersion;
  final String rulesVersion;
  final int normalizationVersion;
  final int personalRulesRevision;

  const BillingRuleExecutionSnapshot({
    required this.rulePackageVersion,
    required this.rulesVersion,
    required this.normalizationVersion,
    required this.personalRulesRevision,
  });
}

typedef BillingJobPublicationGate = Future<T> Function<T>(
  BillingJobLease lease,
  Future<T> Function() action,
);

abstract class BillingJobRepository {
  /// Persists a job together with the ledger selected when its image arrived.
  ///
  /// [ledgerId] may be null only for legacy/imported jobs. Production callers
  /// must capture and provide it instead of consulting mutable current-ledger
  /// state when the job is resumed or confirmed later.
  Future<BillingJob> createJob({
    required String imagePath,
    int? ledgerId,
    String kind = 'image_share',
  });
  Future<BillingJob?> findById(int id);
  Future<List<BillingJob>> findPendingJobs();
  Future<List<BillingJob>> findAttachmentRecoveryJobs();
  Future<List<BillingJob>> findAwaitingConfirmationJobs();
  Future<bool> updateStage(int id, String stage, {BillingJobLease? lease});
  Future<bool> updateStatus(
    int id,
    String status, {
    String? lastError,
    BillingJobLease? lease,
    bool releaseLease = false,
  });
  Future<bool> claimJob(int id, Duration leaseDuration);
  Future<BillingJobLease?> claimJobLease(int id, Duration leaseDuration);
  Future<BillingJobLease?> claimAttachmentRecoveryLease(
    int id,
    Duration leaseDuration,
  );
  Future<bool> isLeaseOwner(BillingJobLease lease);
  Future<T> runFencedPublication<T>(
    BillingJobLease lease,
    Future<T> Function() action,
  );
  Future<bool> markSucceeded(int id, {BillingJobLease? lease});
  Future<bool> markAttachmentDone(int id, {BillingJobLease? lease});
  Future<BillingJob?> findByImagePath(String imagePath);

  /// Finds the latest image-share job that created [transactionId].
  ///
  /// Returns null for manually created transactions, so ordinary edits never
  /// enter the personal-rule learning flow without OCR evidence.
  Future<BillingJob?> findByTransactionId(int transactionId);
  Future<bool> updateRawText(int id, String rawText, {BillingJobLease? lease});
  Future<bool> updateSourceInfoJson(int id, String sourceInfoJson,
      {BillingJobLease? lease});
  Future<bool> updateRuleResultJson(int id, String ruleResultJson,
      {BillingJobLease? lease});
  Future<bool> commitRuleResultSnapshot({
    required int id,
    required String ruleResultJson,
    required BillingRuleExecutionSnapshot snapshot,
    BillingJobLease? lease,
  }) =>
      throw UnsupportedError('atomic rule snapshot commit is unavailable');
  Future<bool> migrateUnavailableRuleSnapshotToOcrDone(
    int id, {
    BillingJobLease? lease,
  }) =>
      throw UnsupportedError('rule snapshot migration is unavailable');
  Future<bool> updateTransactionId(int id, int transactionId,
      {BillingJobLease? lease});
  Future<bool> updateFinalResultJson(int id, String finalResultJson,
      {BillingJobLease? lease});
}
