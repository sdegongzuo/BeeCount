import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';

enum ShareBillingProcessingOutcome {
  completed,
  awaitingConfirmation,
  inProgress,
  failed,
}

typedef ShareBillingMethodInvoker = Future<void> Function(
  String method,
  Map<String, Object?> arguments,
);

class ShareBillingProcessingOutcomeReporter {
  const ShareBillingProcessingOutcomeReporter(this._invokeMethod);

  final ShareBillingMethodInvoker _invokeMethod;

  Future<ShareBillingProcessingOutcome> report({
    required int? transactionId,
    required BillingJob? job,
    required String imagePath,
  }) async {
    final outcome = resolveShareBillingProcessingOutcome(
      transactionId: transactionId,
      job: job,
    );
    switch (outcome) {
      case ShareBillingProcessingOutcome.completed:
        break;
      case ShareBillingProcessingOutcome.awaitingConfirmation:
        await _invokeMethod('shareBillingNeedsConfirmation', {
          'jobId': job!.id,
          'imagePath': imagePath,
        });
        break;
      case ShareBillingProcessingOutcome.inProgress:
        // Non-terminal: keep the native pending payload intact. Its delivery
        // lease will expire and recovery will observe/resume the same job.
        await _invokeMethod('updateShareBillingStatus', {
          'statusText': '账单仍在处理中，将自动恢复',
        });
        break;
      case ShareBillingProcessingOutcome.failed:
        await _invokeMethod('failShareBilling', {
          'reason': 'transaction_not_created',
        });
        break;
    }
    return outcome;
  }
}

ShareBillingProcessingOutcome resolveShareBillingProcessingOutcome({
  required int? transactionId,
  required BillingJob? job,
}) {
  if (transactionId != null) return ShareBillingProcessingOutcome.completed;
  if (job?.status == BillingJobStatus.awaitingConfirmation) {
    return ShareBillingProcessingOutcome.awaitingConfirmation;
  }
  if (job?.status == BillingJobStatus.pending ||
      job?.status == BillingJobStatus.retryableFailed) {
    return ShareBillingProcessingOutcome.inProgress;
  }
  return ShareBillingProcessingOutcome.failed;
}
