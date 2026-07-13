import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/services/platform/share_billing_processing_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('待确认 job 不会被分享后台流程误报为失败', () {
    final job = BillingJob(
      id: 7,
      kind: 'image_share',
      imagePath: '/isolated/share.png',
      status: BillingJobStatus.awaitingConfirmation,
      stage: BillingJobStage.ruleDone,
      attemptCount: 1,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );

    final outcome = resolveShareBillingProcessingOutcome(
      transactionId: null,
      job: job,
    );

    expect(outcome, ShareBillingProcessingOutcome.awaitingConfirmation);
  });

  test('待确认通过明确事件携带 jobId 和 imagePath，且不发送失败', () async {
    final calls = <({String method, Map<String, Object?> arguments})>[];
    final job = BillingJob(
      id: 19,
      kind: 'image_share',
      imagePath: '/isolated/awaiting.png',
      status: BillingJobStatus.awaitingConfirmation,
      stage: BillingJobStage.ruleDone,
      attemptCount: 1,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    final reporter = ShareBillingProcessingOutcomeReporter(
      (method, arguments) async {
        calls.add((method: method, arguments: arguments));
      },
    );

    final outcome = await reporter.report(
      transactionId: null,
      job: job,
      imagePath: job.imagePath,
    );

    expect(outcome, ShareBillingProcessingOutcome.awaitingConfirmation);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareBillingNeedsConfirmation');
    expect(calls.single.arguments, {
      'jobId': 19,
      'imagePath': '/isolated/awaiting.png',
    });
    expect(
        calls.map((call) => call.method), isNot(contains('failShareBilling')));
  });

  test('仍由另一执行者处理的 job 到观察 deadline 后不会被误报失败', () async {
    final calls = <({String method, Map<String, Object?> arguments})>[];
    final job = BillingJob(
      id: 20,
      kind: 'image_share',
      imagePath: '/isolated/active.png',
      status: BillingJobStatus.pending,
      stage: BillingJobStage.ocrDone,
      attemptCount: 0,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    final reporter = ShareBillingProcessingOutcomeReporter(
      (method, arguments) async {
        calls.add((method: method, arguments: arguments));
      },
    );

    final outcome = await reporter.report(
      transactionId: null,
      job: job,
      imagePath: job.imagePath,
    );

    expect(outcome, ShareBillingProcessingOutcome.inProgress);
    expect(calls.single.method, 'updateShareBillingStatus');
    expect(calls.single.arguments['statusText'], contains('自动恢复'));
    expect(
        calls.map((call) => call.method), isNot(contains('failShareBilling')));
  });
}
