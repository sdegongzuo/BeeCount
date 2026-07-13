import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/services/platform/share_billing_request_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  test('main-engine processing renews its delivery lease while work is running',
      () async {
    final processing = Completer<int?>();
    final renewals = <String>[];
    final awaitingJob = BillingJob(
      id: 91,
      kind: 'image_share',
      imagePath: '/isolated/slow.png',
      status: BillingJobStatus.awaitingConfirmation,
      stage: BillingJobStage.ruleDone,
      attemptCount: 1,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    final coordinator = ShareBillingRequestCoordinator(
      processImage: (_, {sourceInfo}) => processing.future,
      findJob: (_) async => awaitingJob,
      loadTransaction: (_) async => null,
      invokeMethod: (_, __) async {},
      renewDeliveryLease: (requestId) async => renewals.add(requestId),
      deliveryLeaseHeartbeatInterval: const Duration(milliseconds: 5),
    );

    final result = coordinator.process(const {
      'requestId': 'long-main-1',
      'cacheImagePath': '/isolated/slow.png',
    });
    await Future<void>.delayed(const Duration(milliseconds: 25));
    processing.complete(null);
    await result;

    expect(renewals.length, greaterThanOrEqualTo(2));
    expect(renewals, everyElement('long-main-1'));
  });

  test('malformed MethodChannel payload reports a terminal failure', () async {
    final calls = <({String method, Map<String, Object?> arguments})>[];
    final coordinator = ShareBillingRequestCoordinator(
      processImage: (_, {sourceInfo}) async => null,
      findJob: (_) async => null,
      loadTransaction: (_) async => null,
      invokeMethod: (method, arguments) async {
        calls.add((method: method, arguments: arguments));
      },
    );

    await coordinator.process(const {'requestId': 'bad-1'});

    expect(calls.single.method, 'failShareBilling');
    expect(calls.single.arguments['requestId'], 'bad-1');
    expect(calls.single.arguments['reason'], contains('missing'));
  });

  test('awaiting result is a terminal event correlated to its request',
      () async {
    final calls = <({String method, Map<String, Object?> arguments})>[];
    final job = BillingJob(
      id: 42,
      kind: 'image_share',
      imagePath: '/isolated/pending.png',
      status: BillingJobStatus.awaitingConfirmation,
      stage: BillingJobStage.ruleDone,
      attemptCount: 1,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    final coordinator = ShareBillingRequestCoordinator(
      processImage: (_, {sourceInfo}) async => null,
      findJob: (_) async => job,
      loadTransaction: (_) async => null,
      invokeMethod: (method, arguments) async {
        calls.add((method: method, arguments: arguments));
      },
    );

    await coordinator.process(const {
      'requestId': 'pending-42',
      'cacheImagePath': '/isolated/pending.png',
    });

    final terminal = calls.singleWhere(
      (call) => call.method == 'shareBillingNeedsConfirmation',
    );
    expect(terminal.arguments, {
      'requestId': 'pending-42',
      'jobId': 42,
      'imagePath': '/isolated/pending.png',
    });
    expect(
        calls.map((call) => call.method), isNot(contains('failShareBilling')));
  });
}
