import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';

enum ShareBillingProcessingOutcome {
  completed,
  awaitingConfirmation,
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
  return ShareBillingProcessingOutcome.failed;
}
