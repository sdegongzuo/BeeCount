import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/cloud_mode_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/smart_billing_providers.dart';
import '../../data/repositories/billing_job_repository.dart';
import '../billing/billing_job_service.dart';
import '../system/logger_service.dart';
import 'screenshot_source_info.dart';
import 'share_billing_processing_outcome.dart';

class ShareBillingBackgroundService {
  static const MethodChannel _channel =
      MethodChannel('com.tntlikely.beecount/share_background');

  ProviderContainer? _container;
  BillingJobService? _billingJobService;

  Future<void> start() async {
    WidgetsFlutterBinding.ensureInitialized();

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'processShareBilling':
          await _processShareBilling(call.arguments);
        default:
          throw PlatformException(
            code: 'not_implemented',
            message: 'Unknown share background method: ${call.method}',
          );
      }
    });

    await _channel.invokeMethod<void>('ready');
  }

  Future<void> _processShareBilling(Object? arguments) async {
    final payload = _payloadFromArguments(arguments);
    logger.info('ShareBillingBackground', '开始后台图片记账', payload.path);

    try {
      await _ensureInitialized();
      await _updateStatus('正在准备识别账单');

      final processing = _billingJobService!.processImage(
        payload.path,
        sourceInfo: payload.sourceInfo,
      );
      final transactionCreated = _notifyWhenTransactionCreated(payload.path);
      final transactionId = await processing;
      await transactionCreated;
      final job = await _container!
          .read(billingJobRepositoryProvider)
          .findByImagePath(payload.path);
      if (transactionId != null) {
        final repo = _container!.read(repositoryProvider);
        final transaction = await repo.getTransactionById(transactionId);
        await _channel.invokeMethod<void>('completeShareBilling', {
          'amount': transaction?.amount,
          'note': transaction?.note,
        });
        logger.info(
          'ShareBillingBackground',
          '后台图片记账完成',
          'txId=$transactionId',
        );
        return;
      }

      final outcome = await ShareBillingProcessingOutcomeReporter(
        (method, arguments) => _channel.invokeMethod<void>(method, arguments),
      ).report(
        transactionId: transactionId,
        job: job,
        imagePath: payload.path,
      );
      if (outcome == ShareBillingProcessingOutcome.awaitingConfirmation) {
        logger.info(
          'ShareBillingBackground',
          '后台图片记账等待用户确认',
          'jobId=${job?.id}',
        );
      }
      return;
    } catch (e, stackTrace) {
      logger.error('ShareBillingBackground', '后台图片记账失败', e, stackTrace);
      await _fail(e.toString());
    }
  }

  Future<void> _ensureInitialized() async {
    if (_container != null && _billingJobService != null) return;

    final container = ProviderContainer();
    await _initializeAppMode(container);
    await _initializeSmartBilling(container);

    final repo = container.read(billingJobRepositoryProvider);
    final service = BillingJobService.create(
      repo: repo,
      container: container,
      statusReporter: _updateStatus,
    );

    _container = container;
    _billingJobService = service;
  }

  Future<void> _initializeAppMode(ProviderContainer container) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('app_mode');
      final mode =
          modeStr != null ? AppMode.fromString(modeStr) : AppMode.local;
      await container.read(appModeProvider.notifier).switchMode(mode);
    } catch (e, stackTrace) {
      logger.error('ShareBillingBackground', '后台初始化应用模式失败', e, stackTrace);
    }
  }

  Future<void> _initializeSmartBilling(ProviderContainer container) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final formatStr = prefs.getString('smartBillingAttachmentFormat');
      final format = SmartBillingAttachmentFormat.fromStorageKey(formatStr);
      container.read(smartBillingAttachmentFormatProvider.notifier).state =
          format;

      final quality = prefs.getInt('smartBillingAttachmentQuality');
      if (quality != null) {
        container.read(smartBillingAttachmentQualityProvider.notifier).state =
            quality.clamp(5, 100);
      }

      logger.info('ShareBillingBackground',
          '后台初始化附件格式: format=${format.storageKey}, quality=$quality');
    } catch (e, stackTrace) {
      logger.error('ShareBillingBackground', '后台初始化附件设置失败', e, stackTrace);
    }
  }

  Future<void> _updateStatus(String statusText) async {
    await _channel.invokeMethod<void>('updateShareBillingStatus', {
      'statusText': statusText,
    });
  }

  Future<void> _notifyWhenTransactionCreated(String imagePath) async {
    try {
      for (var i = 0; i < 180; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final job = await _container!
            .read(billingJobRepositoryProvider)
            .findByImagePath(imagePath);
        if (job?.status == BillingJobStatus.awaitingConfirmation) return;
        final transactionId = job?.transactionId;
        if (transactionId == null) continue;

        final transaction = await _container!
            .read(repositoryProvider)
            .getTransactionById(transactionId);
        await _channel.invokeMethod<void>('shareBillingCreated', {
          'amount': transaction?.amount,
          'note': transaction?.note,
        });
        logger.info(
          'ShareBillingBackground',
          '后台图片记账交易已创建',
          'txId=$transactionId',
        );
        return;
      }
    } catch (e, stackTrace) {
      logger.warning(
        'ShareBillingBackground',
        '更新交易已创建通知失败: $e',
        stackTrace,
      );
    }
  }

  Future<void> _fail(String reason) async {
    await _channel.invokeMethod<void>('failShareBilling', {'reason': reason});
  }
}

_SharedImagePayload _payloadFromArguments(Object? arguments) {
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
