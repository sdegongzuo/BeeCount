import 'dart:async';

typedef ShareBillingPlatformInvoke = Future<void> Function(
  String method,
  Map<String, Object?> arguments,
);

String? shareBillingRequestIdFrom(Object? arguments) {
  if (arguments is! Map) return null;
  final value = arguments['requestId']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

class ShareBillingDeliveryLeaseOwner {
  final String requestId;
  final Future<void> Function(String requestId) renew;
  final Duration interval;

  Timer? _timer;
  bool _stopped = false;

  ShareBillingDeliveryLeaseOwner({
    required this.requestId,
    required this.renew,
    required this.interval,
  });

  Future<void> start() async {
    await renew(requestId);
    if (_stopped) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_renewWhileActive()));
  }

  Future<void> _renewWhileActive() async {
    if (_stopped) return;
    try {
      await renew(requestId);
    } catch (_) {
      // The next heartbeat retries without turning a Timer callback into an
      // uncorrelated terminal error.
    }
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}

class ShareBillingPendingPayloadDrainer {
  final Future<Map<String, dynamic>?> Function() loadNext;
  final Future<void> Function(Map<String, dynamic> payload) process;

  const ShareBillingPendingPayloadDrainer({
    required this.loadNext,
    required this.process,
  });

  Future<void> drain() async {
    final seen = <String>{};
    while (true) {
      final payload = await loadNext();
      if (payload == null || payload.isEmpty) return;
      final identity = shareBillingRequestIdFrom(payload) ??
          payload['cacheImagePath']?.toString() ??
          payload['path']?.toString() ??
          payload.toString();
      if (!seen.add(identity)) return;
      await process(payload);
    }
  }
}

class ShareBillingHeadlessRequestRunner {
  final Future<void> Function() initialize;
  final Future<void> Function(Object? arguments) process;
  final ShareBillingPlatformInvoke invokeMethod;
  final Duration heartbeatInterval;

  const ShareBillingHeadlessRequestRunner({
    required this.initialize,
    required this.process,
    required this.invokeMethod,
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  Future<void> run(Object? arguments) async {
    final requestId = shareBillingRequestIdFrom(arguments);
    final owner = requestId == null
        ? null
        : ShareBillingDeliveryLeaseOwner(
            requestId: requestId,
            renew: (id) => invokeMethod(
              'renewShareBillingDeliveryLease',
              {'requestId': id},
            ),
            interval: heartbeatInterval,
          );
    try {
      await owner?.start();
      await initialize();
      await process(arguments);
    } catch (error) {
      await invokeMethod('failShareBilling', {
        'reason': error.toString(),
        if (requestId != null) 'requestId': requestId,
      });
    } finally {
      owner?.stop();
    }
  }
}
