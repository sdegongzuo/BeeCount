import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/cloud_mode_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/smart_billing_providers.dart';
import '../billing/billing_job_service.dart';
import '../billing/rules/billing_rule_update_configuration.dart';
import '../billing/rules/billing_rule_update_runtime.dart';
import '../system/logger_service.dart';
import 'share_billing_request_coordinator.dart';
import 'share_billing_delivery.dart';
import 'share_billing_c2_container.dart';
import 'share_billing_c2_fixture.dart';

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
    try {
      final runtimeId =
          arguments is Map ? arguments['c2FixtureId']?.toString() : null;
      final fixture = ShareBillingC2Fixture.fromRuntime(runtimeId);
      final coordinator = ShareBillingRequestCoordinator(
        initialize: () => _ensureInitialized(fixture),
        processImage: (path, {sourceInfo}) =>
            _billingJobService!.processImage(path, sourceInfo: sourceInfo),
        processImageWithOwnership: (path, {sourceInfo, ensureDeliveryOwned}) =>
            _billingJobService!.processImage(
          path,
          sourceInfo: sourceInfo,
          ensureDeliveryOwned: ensureDeliveryOwned,
        ),
        findJob: (path) => _container!
            .read(billingJobRepositoryProvider)
            .findByImagePath(path),
        loadTransaction: (transactionId) async {
          final transaction = await _container!
              .read(repositoryProvider)
              .getTransactionById(transactionId);
          return transaction == null
              ? null
              : ShareBillingTransactionSummary(
                  amount: transaction.amount,
                  note: transaction.note,
                  needsClassification: transaction.needsClassification,
                );
        },
        invokeMethod: (method, values) =>
            _channel.invokeMethod<void>(method, values),
        renewDeliveryLease: (requestId, ownerToken) async =>
            await _channel.invokeMethod<bool>(
              'renewShareBillingDeliveryLease',
              {
                'requestId': requestId,
                'deliveryOwnerToken': ownerToken,
              },
            ) ==
            true,
      );
      await coordinator.process(arguments);
    } catch (e, stackTrace) {
      logger.error('ShareBillingBackground', '后台图片记账失败', e, stackTrace);
      await _channel.invokeMethod<void>('failShareBilling', {
        'reason': e.toString(),
        if (shareBillingRequestIdFrom(arguments) case final requestId?)
          'requestId': requestId,
        if (shareBillingOwnerTokenFrom(arguments) case final ownerToken?)
          'deliveryOwnerToken': ownerToken,
      });
    }
  }

  Future<void> _ensureInitialized(ShareBillingC2Fixture? fixture) async {
    if (_container != null && _billingJobService != null) return;

    final c2Runtime =
        fixture == null ? null : await ShareBillingC2Container.create(fixture);
    final container = c2Runtime?.container ?? ProviderContainer();
    if (fixture == null) {
      await _initializeAppMode(container);
      await initializeProductionBillingRuleUpdateService(
        configuration: await BillingRuleUpdateConfiguration.loadProduction(),
        database: container.read(databaseProvider),
      );
      await _initializeSmartBilling(container);
    }

    final repo = container.read(billingJobRepositoryProvider);
    final service = BillingJobService.create(
      repo: repo,
      container: container,
      statusReporter: _updateStatus,
      captureRegressionSamples: fixture == null,
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
}
