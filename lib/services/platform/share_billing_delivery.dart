import 'dart:async';

const shareBillingRetryAtMillisKey = '_shareBillingRetryAtMillis';

class ShareBillingLeaseLost implements Exception {
  final String requestId;
  final Object? cause;

  const ShareBillingLeaseLost(this.requestId, [this.cause]);

  @override
  String toString() =>
      'ShareBillingLeaseLost($requestId${cause == null ? '' : ': $cause'})';
}

String? shareBillingRequestIdFrom(Object? arguments) {
  if (arguments is! Map) return null;
  final value = arguments['requestId']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String? shareBillingOwnerTokenFrom(Object? arguments) {
  if (arguments is! Map) return null;
  final value = arguments['deliveryOwnerToken']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

class ShareBillingDeliveryLeaseOwner {
  final String requestId;
  final String ownerToken;
  final Future<bool> Function(String requestId, String ownerToken) renew;
  final Duration interval;

  Timer? _timer;
  bool _stopped = false;
  ShareBillingLeaseLost? _loss;
  final Completer<void> _lost = Completer<void>();

  ShareBillingDeliveryLeaseOwner({
    required this.requestId,
    required this.ownerToken,
    required this.renew,
    required this.interval,
  });

  Future<void> start() async {
    await _renewOrLose();
    if (_stopped) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_renewWhileActive()));
  }

  Future<void> _renewWhileActive() async {
    if (_stopped) return;
    try {
      await _renewOrLose();
    } catch (_) {
      // _renewOrLose records the loss; guard() terminates the owner workflow.
    }
  }

  Future<void> _renewOrLose() async {
    try {
      final retained = await renew(requestId, ownerToken);
      if (!retained) throw StateError('native owner token rejected');
    } catch (error) {
      _markLost(error);
      throw _loss!;
    }
  }

  void _markLost(Object cause) {
    _loss ??= ShareBillingLeaseLost(requestId, cause);
    _timer?.cancel();
    _timer = null;
    if (!_lost.isCompleted) _lost.complete();
  }

  void ensureOwned() {
    final loss = _loss;
    if (loss != null) throw loss;
  }

  Future<T> guard<T>(Future<T> operation) => Future.any<T>([
        operation,
        _lost.future.then<T>((_) => throw _loss!),
      ]);

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}

class ShareBillingPendingPayloadDrainer {
  final Future<Map<String, dynamic>?> Function() loadNext;
  final Future<void> Function(Map<String, dynamic> payload) process;
  final int Function() nowMillis;
  final Future<void> Function(Duration duration) wait;

  const ShareBillingPendingPayloadDrainer({
    required this.loadNext,
    required this.process,
    this.nowMillis = _systemNowMillis,
    this.wait = Future<void>.delayed,
  });

  Future<void> drain() async {
    final seen = <String>{};
    while (true) {
      final payload = await loadNext();
      if (payload == null || payload.isEmpty) return;
      final retryAt = (payload[shareBillingRetryAtMillisKey] as num?)?.toInt();
      if (retryAt != null) {
        final delayMillis = retryAt - nowMillis();
        if (delayMillis > 0) {
          await wait(Duration(milliseconds: delayMillis));
        }
        continue;
      }
      final identity = shareBillingRequestIdFrom(payload) ??
          payload['cacheImagePath']?.toString() ??
          payload['path']?.toString() ??
          payload.toString();
      if (!seen.add(identity)) return;
      await process(payload);
    }
  }
}

int _systemNowMillis() => DateTime.now().millisecondsSinceEpoch;
