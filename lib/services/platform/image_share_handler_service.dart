import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_providers.dart';
import '../../providers/smart_billing_providers.dart';
import '../billing/billing_job_service.dart';
import '../system/logger_service.dart';
import 'share_billing_request_coordinator.dart';
import 'share_billing_delivery.dart';

/// 图片分享处理服务（Android专用）
/// 处理从相册或其他应用分享过来的图片，通过 BillingJobService 进行 OCR 识别和记账
class ImageShareHandlerService {
  static const _channel = MethodChannel('com.tntlikely.beecount/share');

  final ProviderContainer _container;
  late final BillingJobService _billingJobService;
  late final ShareBillingRequestCoordinator _coordinator;

  // 单例模式
  static ImageShareHandlerService? _instance;

  factory ImageShareHandlerService(ProviderContainer container) {
    _instance ??= ImageShareHandlerService._internal(container);
    return _instance!;
  }

  ImageShareHandlerService._internal(this._container) {
    final repo = _container.read(billingJobRepositoryProvider);
    _billingJobService = BillingJobService.create(
      repo: repo,
      container: _container,
      statusReporter: (statusText) => _channel.invokeMethod<void>(
        'updateShareBillingStatus',
        {'statusText': statusText},
      ),
    );
    _coordinator = ShareBillingRequestCoordinator(
      processImage: _billingJobService.processImage,
      findJob: _container.read(billingJobRepositoryProvider).findByImagePath,
      loadTransaction: (transactionId) async {
        final transaction = await _container
            .read(repositoryProvider)
            .getTransactionById(transactionId);
        return transaction == null
            ? null
            : ShareBillingTransactionSummary(
                amount: transaction.amount,
                note: transaction.note,
              );
      },
      invokeMethod: (method, arguments) =>
          _channel.invokeMethod<void>(method, arguments),
      renewDeliveryLease: (requestId) => _channel.invokeMethod<void>(
        'renewShareBillingDeliveryLease',
        {'requestId': requestId},
      ),
      onAwaitingConfirmation: (jobId) async {
        _container.read(pendingBillConfirmationJobIdProvider.notifier).state =
            jobId;
      },
    );
    _setupMethodCallHandler();
    _processPendingSharedImage();
    _resumePendingJobs();
  }

  /// 设置方法调用处理器
  void _setupMethodCallHandler() {
    logger.info('ImageShare', '初始化图片分享处理器');
    _channel.setMethodCallHandler((call) async {
      logger.info('ImageShare', '收到方法调用: ${call.method}');
      if (call.method == 'onImageShared') {
        await _coordinator.process(call.arguments);
      }
    });
    _channel.invokeMethod<void>('shareBillingMainReady');
  }

  Future<void> _processPendingSharedImage() async {
    try {
      await ShareBillingPendingPayloadDrainer(
        loadNext: () => _channel.invokeMapMethod<String, dynamic>(
          'getPendingShareBillingPayload',
        ),
        process: _coordinator.process,
      ).drain();
    } catch (e, stackTrace) {
      logger.error('ImageShare', '读取待处理分享图片失败', e, stackTrace);
    }
  }

  /// 恢复未完成的 billing jobs
  Future<void> _resumePendingJobs() async {
    try {
      await _billingJobService.resumePendingJobs();
      final awaiting = await _container
          .read(billingJobRepositoryProvider)
          .findAwaitingConfirmationJobs();
      if (awaiting.isNotEmpty) {
        _container.read(pendingBillConfirmationJobIdProvider.notifier).state =
            awaiting.first.id;
      }
    } catch (e, stackTrace) {
      logger.error('ImageShare', '恢复待处理任务失败', e, stackTrace);
    }
  }

  /// 释放资源
  void dispose() {
    _billingJobService.dispose();
  }
}
