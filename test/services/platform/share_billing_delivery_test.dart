import 'dart:async';

import 'package:beecount/services/platform/share_billing_delivery.dart';
import 'package:beecount/services/platform/share_billing_request_coordinator.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delivery lease exceeds Billing Job deadline plus heartbeat margin', () {
    expect(
      shareBillingDeliveryLease,
      greaterThan(
        billingJobProcessingDeadline +
            shareBillingHeartbeatInterval +
            shareBillingLeaseSafetyMargin,
      ),
    );
  });
  test('drainer processes every distinct pending payload in order', () async {
    final pending = <Map<String, Object?>>[
      {'requestId': 'expired-1', 'cacheImagePath': '/one.png'},
      {'requestId': 'expired-2', 'cacheImagePath': '/two.png'},
    ];
    final processed = <String>[];
    final drainer = ShareBillingPendingPayloadDrainer(
      loadNext: () async => pending.isEmpty ? null : pending.removeAt(0),
      process: (payload) async =>
          processed.add(payload['requestId']! as String),
    );

    await drainer.drain();

    expect(processed, ['expired-1', 'expired-2']);
  });

  test('drainer stops if native returns the same leased payload again',
      () async {
    const payload = <String, Object?>{
      'requestId': 'same-1',
      'cacheImagePath': '/same.png',
    };
    var reads = 0;
    var processed = 0;
    final drainer = ShareBillingPendingPayloadDrainer(
      loadNext: () async {
        reads++;
        return payload;
      },
      process: (_) async => processed++,
    );

    await drainer.drain();

    expect(processed, 1);
    expect(reads, 2);
  });

  test(
      'drainer waits for the nearest active lease then retries without restart',
      () async {
    var now = 1000;
    var reads = 0;
    final waits = <Duration>[];
    final processed = <String>[];
    final drainer = ShareBillingPendingPayloadDrainer(
      nowMillis: () => now,
      wait: (duration) async {
        waits.add(duration);
        now += duration.inMilliseconds;
      },
      loadNext: () async {
        reads++;
        if (reads == 1) return {shareBillingRetryAtMillisKey: 1075};
        if (reads == 2) {
          return {
            'requestId': 'expired-after-wait',
            'deliveryOwnerToken': 'owner-after-wait',
            'cacheImagePath': '/after-wait.png',
          };
        }
        return null;
      },
      process: (payload) async {
        processed.add(payload['requestId']! as String);
      },
    );

    await drainer.drain();

    expect(waits, [const Duration(milliseconds: 75)]);
    expect(processed, ['expired-after-wait']);
  });

  test('headless initialization failure retains request correlation', () async {
    final invocations = <({String method, Map<String, Object?> arguments})>[];
    final coordinator = ShareBillingRequestCoordinator(
      initialize: () async => throw StateError('init failed'),
      processImage: (_, {sourceInfo}) async =>
          fail('processing must not start'),
      findJob: (_) async => null,
      loadTransaction: (_) async => null,
      invokeMethod: (method, arguments) async {
        invocations.add((method: method, arguments: arguments));
      },
      renewDeliveryLease: (_, __) async => true,
      deliveryLeaseHeartbeatInterval: const Duration(milliseconds: 5),
    );

    await coordinator.process(const {
      'requestId': 'headless-init-7',
      'deliveryOwnerToken': 'headless-owner-7',
      'cacheImagePath': '/headless.png',
    });

    expect(invocations.last.method, 'failShareBilling');
    expect(invocations.last.arguments['requestId'], 'headless-init-7');
    expect(invocations.last.arguments['reason'], contains('init failed'));
  });

  test('headless owner renews lease throughout long initialization', () async {
    final initialized = Completer<void>();
    final renewals = <String>[];
    final awaitingJob = BillingJob(
      id: 92,
      kind: 'image_share',
      imagePath: '/headless-slow.png',
      status: BillingJobStatus.awaitingConfirmation,
      stage: BillingJobStage.ruleDone,
      attemptCount: 1,
      attachmentDone: false,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    final coordinator = ShareBillingRequestCoordinator(
      initialize: () => initialized.future,
      processImage: (_, {sourceInfo}) async => null,
      findJob: (_) async => awaitingJob,
      loadTransaction: (_) async => null,
      invokeMethod: (_, __) async {},
      renewDeliveryLease: (requestId, ownerToken) async {
        renewals.add('$requestId:$ownerToken');
        return true;
      },
      deliveryLeaseHeartbeatInterval: const Duration(milliseconds: 5),
    );

    final result = coordinator.process(const {
      'requestId': 'headless-slow-9',
      'deliveryOwnerToken': 'headless-owner-9',
      'cacheImagePath': '/headless-slow.png',
    });
    await Future<void>.delayed(const Duration(milliseconds: 25));
    initialized.complete();
    await result;

    expect(renewals.length, greaterThanOrEqualTo(2));
    expect(renewals, everyElement('headless-slow-9:headless-owner-9'));
  });

  test('lease renewal rejection fences and terminates guarded work', () async {
    var renewals = 0;
    final owner = ShareBillingDeliveryLeaseOwner(
      requestId: 'fenced-1',
      ownerToken: 'owner-a',
      renew: (_, __) async => ++renewals < 2,
      interval: const Duration(milliseconds: 5),
    );
    await owner.start();

    await expectLater(
      owner.guard(Completer<void>().future),
      throwsA(isA<ShareBillingLeaseLost>()),
    );
    owner.stop();
    expect(renewals, greaterThanOrEqualTo(2));
  });

  test(
      'a continued processing Future receives a guard that fences side effects',
      () async {
    var renewals = 0;
    var businessSideEffects = 0;
    final processingFinished = Completer<void>();
    final coordinator = ShareBillingRequestCoordinator(
      processImage: (_, {sourceInfo}) async => null,
      processImageWithOwnership: (_, {sourceInfo, ensureDeliveryOwned}) async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        try {
          ensureDeliveryOwned!();
          businessSideEffects++;
        } finally {
          processingFinished.complete();
        }
        return null;
      },
      findJob: (_) async => null,
      loadTransaction: (_) async => null,
      invokeMethod: (_, __) async {},
      renewDeliveryLease: (_, __) async => ++renewals < 2,
      deliveryLeaseHeartbeatInterval: const Duration(milliseconds: 5),
    );

    await coordinator.process(const {
      'requestId': 'future-continues-1',
      'deliveryOwnerToken': 'old-owner',
      'cacheImagePath': '/future-continues.png',
    });
    await processingFinished.future;

    expect(renewals, greaterThanOrEqualTo(2));
    expect(businessSideEffects, 0);
  });
}
