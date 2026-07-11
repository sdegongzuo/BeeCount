import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_providers.dart';
import '../billing/billing_job_service.dart';
import '../system/logger_service.dart';
import 'screenshot_source_info.dart';

/// 图片分享处理服务（Android专用）
/// 处理从相册或其他应用分享过来的图片，通过 BillingJobService 进行 OCR 识别和记账
class ImageShareHandlerService {
  static const _channel = MethodChannel('com.tntlikely.beecount/share');

  final ProviderContainer _container;
  late final BillingJobService _billingJobService;

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
      statusReporter: _updateShareBillingStatus,
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
        final payload = _payloadFromArguments(call.arguments);
        logger.info('ImageShare', '收到分享的图片，路径: ${payload.path}');
        await _handleSharedImage(payload);
      }
    });
  }

  /// 处理分享的图片
  Future<void> _handleSharedImage(_SharedImagePayload payload) async {
    logger.info('ImageShare', '开始处理分享的图片: ${payload.path}');

    try {
      if (!Platform.isAndroid) {
        logger.warning('ImageShare', '图片分享仅支持 Android 平台');
        return;
      }

      await _updateShareBillingStatus('正在准备识别账单');
      final processing = _billingJobService.processImage(
        payload.path,
        sourceInfo: payload.sourceInfo,
      );
      final transactionCreated = _notifyWhenTransactionCreated(payload.path);
      final transactionId = await processing;
      await transactionCreated;
      if (transactionId != null) {
        await _completeShareBilling(transactionId);
      } else {
        await _failShareBilling('transaction_not_created');
      }
      logger.info('ImageShare', '图片处理完成');
    } catch (e, stackTrace) {
      logger.error('ImageShare', '处理分享图片失败', e, stackTrace);
      await _failShareBilling(e.toString());
    }
  }

  Future<void> _processPendingSharedImage() async {
    if (!Platform.isAndroid) return;
    try {
      final pending = await _channel.invokeMapMethod<String, dynamic>(
        'getPendingShareBillingPayload',
      );
      if (pending == null || pending.isEmpty) return;
      final payload = _payloadFromArguments(pending);
      logger.info('ImageShare', '发现待处理分享图片: ${payload.path}');
      await _handleSharedImage(payload);
    } catch (e, stackTrace) {
      logger.error('ImageShare', '读取待处理分享图片失败', e, stackTrace);
    }
  }

  /// 恢复未完成的 billing jobs
  Future<void> _resumePendingJobs() async {
    try {
      await _billingJobService.resumePendingJobs();
    } catch (e, stackTrace) {
      logger.error('ImageShare', '恢复待处理任务失败', e, stackTrace);
    }
  }

  Future<void> _completeShareBilling(int transactionId) async {
    if (!Platform.isAndroid) return;
    try {
      final repo = _container.read(repositoryProvider);
      final transaction = await repo.getTransactionById(transactionId);
      await _channel.invokeMethod('completeShareBilling', {
        'amount': transaction?.amount,
        'note': transaction?.note,
      });
    } catch (e) {
      logger.warning('ImageShare', '通知分享前台服务完成失败: $e');
    }
  }

  Future<void> _notifyWhenTransactionCreated(String imagePath) async {
    try {
      for (var i = 0; i < 180; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final job = await _container
            .read(billingJobRepositoryProvider)
            .findByImagePath(imagePath);
        final transactionId = job?.transactionId;
        if (transactionId == null) continue;

        final transaction = await _container
            .read(repositoryProvider)
            .getTransactionById(transactionId);
        await _channel.invokeMethod('shareBillingCreated', {
          'amount': transaction?.amount,
          'note': transaction?.note,
        });
        logger.info(
          'ImageShare',
          '分享图片交易已创建',
          'txId=$transactionId',
        );
        return;
      }
    } catch (e, stackTrace) {
      logger.warning(
        'ImageShare',
        '更新交易已创建通知失败: $e',
        stackTrace,
      );
    }
  }

  Future<void> _updateShareBillingStatus(String statusText) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateShareBillingStatus', {
        'statusText': statusText,
      });
    } catch (e) {
      logger.warning('ImageShare', '更新分享记账通知状态失败: $e');
    }
  }

  Future<void> _failShareBilling(String reason) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('failShareBilling', {'reason': reason});
    } catch (e) {
      logger.warning('ImageShare', '通知分享前台服务失败状态失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _billingJobService.dispose();
  }
}

_SharedImagePayload _payloadFromArguments(Object? arguments) {
  if (arguments is String) {
    return _SharedImagePayload(path: arguments);
  }
  if (arguments is Map) {
    final map = Map<String, dynamic>.from(arguments);
    final path =
        _stringValue(map['cacheImagePath']) ?? _stringValue(map['path']);
    if (path == null || path.isEmpty) {
      throw ArgumentError('Shared image payload missing cacheImagePath/path');
    }
    return _SharedImagePayload(
      path: path,
      sourceInfo: ScreenshotSourceInfo.fromMap(map),
    );
  }
  throw ArgumentError('Unsupported shared image payload: $arguments');
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class _SharedImagePayload {
  final String path;
  final ScreenshotSourceInfo? sourceInfo;

  const _SharedImagePayload({
    required this.path,
    this.sourceInfo,
  });
}
