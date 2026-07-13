import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import 'screenshot_source_info.dart';
import 'share_billing_delivery.dart';
import 'share_billing_processing_outcome.dart';

typedef ShareBillingImageProcessor = Future<int?> Function(
  String imagePath, {
  ScreenshotSourceInfo? sourceInfo,
});
typedef ShareBillingJobFinder = Future<BillingJob?> Function(String imagePath);
typedef ShareBillingTransactionLoader = Future<ShareBillingTransactionSummary?>
    Function(int transactionId);
typedef ShareBillingAwaitingHandler = Future<void> Function(int jobId);

class ShareBillingTransactionSummary {
  final double? amount;
  final String? note;

  const ShareBillingTransactionSummary({this.amount, this.note});
}

/// One orchestration path shared by the foreground and headless Flutter engines.
class ShareBillingRequestCoordinator {
  final ShareBillingImageProcessor processImage;
  final ShareBillingJobFinder findJob;
  final ShareBillingTransactionLoader loadTransaction;
  final ShareBillingMethodInvoker invokeMethod;
  final Future<bool> Function(String requestId, String ownerToken)?
      renewDeliveryLease;
  final Future<void> Function()? initialize;
  final Duration deliveryLeaseHeartbeatInterval;
  final ShareBillingAwaitingHandler? onAwaitingConfirmation;
  final Duration pollInterval;
  final int maxPolls;

  const ShareBillingRequestCoordinator({
    required this.processImage,
    required this.findJob,
    required this.loadTransaction,
    required this.invokeMethod,
    this.renewDeliveryLease,
    this.initialize,
    this.deliveryLeaseHeartbeatInterval = const Duration(seconds: 30),
    this.onAwaitingConfirmation,
    this.pollInterval = const Duration(milliseconds: 500),
    this.maxPolls = 180,
  });

  Future<void> process(Object? arguments) async {
    final requestId = _requestIdFrom(arguments);
    final ownerToken = shareBillingOwnerTokenFrom(arguments);
    final owner =
        requestId == null || ownerToken == null || renewDeliveryLease == null
            ? null
            : ShareBillingDeliveryLeaseOwner(
                requestId: requestId,
                ownerToken: ownerToken,
                renew: renewDeliveryLease!,
                interval: deliveryLeaseHeartbeatInterval,
              );
    try {
      await owner?.start();
      Future<void> ownedProcessing() async {
        await initialize?.call();
        final payload = _payloadFromArguments(arguments);
        await _invoke(
            'updateShareBillingStatus', requestId, ownerToken, owner, {
          'statusText': '正在准备识别账单',
        });

        final processing = processImage(
          payload.path,
          sourceInfo: payload.sourceInfo,
        );
        final transactionCreated = _notifyWhenTransactionCreated(
          payload.path,
          requestId,
          ownerToken,
          owner,
        );
        final transactionId = await processing;
        owner?.ensureOwned();
        await transactionCreated;
        owner?.ensureOwned();
        final job = await findJob(payload.path);

        if (transactionId != null) {
          final transaction = await loadTransaction(transactionId);
          await _invoke('completeShareBilling', requestId, ownerToken, owner, {
            'amount': transaction?.amount,
            'note': transaction?.note,
          });
          return;
        }

        final outcome = await ShareBillingProcessingOutcomeReporter(
          (method, values) =>
              _invoke(method, requestId, ownerToken, owner, values),
        ).report(
          transactionId: transactionId,
          job: job,
          imagePath: payload.path,
        );
        if (outcome == ShareBillingProcessingOutcome.awaitingConfirmation) {
          await onAwaitingConfirmation?.call(job!.id);
        }
      }

      if (owner == null) {
        await ownedProcessing();
      } else {
        await owner.guard(ownedProcessing());
      }
    } catch (error) {
      await _invoke('failShareBilling', requestId, ownerToken, null, {
        'reason': error.toString(),
      });
    } finally {
      owner?.stop();
    }
  }

  Future<void> _notifyWhenTransactionCreated(
    String imagePath,
    String? requestId,
    String? ownerToken,
    ShareBillingDeliveryLeaseOwner? owner,
  ) async {
    for (var i = 0; i < maxPolls; i++) {
      final job = await findJob(imagePath);
      if (job?.status == BillingJobStatus.awaitingConfirmation) return;
      final transactionId = job?.transactionId;
      if (transactionId != null) {
        final transaction = await loadTransaction(transactionId);
        await _invoke('shareBillingCreated', requestId, ownerToken, owner, {
          'amount': transaction?.amount,
          'note': transaction?.note,
        });
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _invoke(
    String method,
    String? requestId,
    String? ownerToken,
    ShareBillingDeliveryLeaseOwner? owner,
    Map<String, Object?> arguments,
  ) {
    owner?.ensureOwned();
    return invokeMethod(method, {
      ...arguments,
      if (requestId != null) 'requestId': requestId,
      if (ownerToken != null) 'deliveryOwnerToken': ownerToken,
    });
  }
}

String? _requestIdFrom(Object? arguments) {
  if (arguments is! Map) return null;
  return _stringValue(arguments['requestId']);
}

_SharedImagePayload _payloadFromArguments(Object? arguments) {
  if (arguments is String) return _SharedImagePayload(path: arguments);
  if (arguments is Map) {
    final map = Map<String, dynamic>.from(arguments);
    final path =
        _stringValue(map['cacheImagePath']) ?? _stringValue(map['path']);
    if (path == null || path.isEmpty) {
      throw ArgumentError('shared image payload missing cacheImagePath/path');
    }
    return _SharedImagePayload(
      path: path,
      sourceInfo: ScreenshotSourceInfo.fromMap(map),
    );
  }
  throw ArgumentError('unsupported shared image payload: $arguments');
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class _SharedImagePayload {
  final String path;
  final ScreenshotSourceInfo? sourceInfo;

  const _SharedImagePayload({required this.path, this.sourceInfo});
}
