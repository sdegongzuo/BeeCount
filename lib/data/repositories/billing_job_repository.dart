import '../db.dart';

/// Billing job stage constants matching the stored string values.
abstract final class BillingJobStage {
  static const received = 'received';
  static const ocrDone = 'ocr_done';
  static const ruleDone = 'rule_done';
  static const transactionCreated = 'transaction_created';
  static const aiDone = 'ai_done';
}

/// Billing job status constants matching the stored string values.
abstract final class BillingJobStatus {
  static const pending = 'pending';
  static const succeeded = 'succeeded';
  static const retryableFailed = 'retryable_failed';
  static const failed = 'failed';
}

abstract class BillingJobRepository {
  Future<BillingJob> createJob(
      {required String imagePath, String kind = 'image_share'});
  Future<BillingJob?> findById(int id);
  Future<List<BillingJob>> findPendingJobs();
  Future<void> updateStage(int id, String stage);
  Future<void> updateStatus(int id, String status, {String? lastError});
  Future<bool> claimJob(int id, Duration leaseDuration);
  Future<void> markSucceeded(int id);
  Future<void> markAttachmentDone(int id);
  Future<BillingJob?> findByImagePath(String imagePath);
  Future<void> updateRawText(int id, String rawText);
  Future<void> updateSourceInfoJson(int id, String sourceInfoJson);
  Future<void> updateRuleResultJson(int id, String ruleResultJson);
  Future<void> updateTransactionId(int id, int transactionId);
  Future<void> updateFinalResultJson(int id, String finalResultJson);
}
