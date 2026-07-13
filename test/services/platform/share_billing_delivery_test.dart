import 'dart:async';

import 'package:beecount/services/platform/share_billing_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('headless initialization failure retains request correlation', () async {
    final invocations = <({String method, Map<String, Object?> arguments})>[];
    final runner = ShareBillingHeadlessRequestRunner(
      initialize: () async => throw StateError('init failed'),
      process: (_) async => fail('processing must not start'),
      invokeMethod: (method, arguments) async {
        invocations.add((method: method, arguments: arguments));
      },
      heartbeatInterval: const Duration(milliseconds: 5),
    );

    await runner.run(const {
      'requestId': 'headless-init-7',
      'cacheImagePath': '/headless.png',
    });

    expect(invocations.last.method, 'failShareBilling');
    expect(invocations.last.arguments['requestId'], 'headless-init-7');
    expect(invocations.last.arguments['reason'], contains('init failed'));
  });

  test('headless owner renews lease throughout long initialization', () async {
    final initialized = Completer<void>();
    final renewals = <String>[];
    final runner = ShareBillingHeadlessRequestRunner(
      initialize: () => initialized.future,
      process: (_) async {},
      invokeMethod: (method, arguments) async {
        if (method == 'renewShareBillingDeliveryLease') {
          renewals.add(arguments['requestId']! as String);
        }
      },
      heartbeatInterval: const Duration(milliseconds: 5),
    );

    final result = runner.run(const {
      'requestId': 'headless-slow-9',
      'cacheImagePath': '/headless-slow.png',
    });
    await Future<void>.delayed(const Duration(milliseconds: 25));
    initialized.complete();
    await result;

    expect(renewals.length, greaterThanOrEqualTo(2));
    expect(renewals, everyElement('headless-slow-9'));
  });
}
