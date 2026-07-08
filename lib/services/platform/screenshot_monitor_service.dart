import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/database_providers.dart';
import '../billing/billing_job_service.dart';
import 'screenshot_source_info.dart';

/// Google Play 版本(CI 注入)。Photo & Video Permissions 政策禁止记账类 app
/// 长期持有 READ_MEDIA_IMAGES,所以 Google Play 版本砍掉截屏自动记账功能。
const _isGooglePlayBuild =
    bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);

/// 截图监听服务（Android专用）
/// 监听系统截图事件，通过 BillingJobService 进行 OCR 识别和记账
class ScreenshotMonitorService {
  static const _channel = MethodChannel('com.tntlikely.beecount/screenshot');
  static const _enabledKey = 'screenshot_monitor_enabled';

  final ProviderContainer _container;
  late final BillingJobService _billingJobService;

  bool _isEnabled = false;
  bool _isMonitoring = false;

  // 单例模式
  static ScreenshotMonitorService? _instance;

  factory ScreenshotMonitorService(ProviderContainer container) {
    _instance ??= ScreenshotMonitorService._internal(container);
    return _instance!;
  }

  ScreenshotMonitorService._internal(this._container) {
    final repo = _container.read(billingJobRepositoryProvider);
    _billingJobService = BillingJobService.create(
      repo: repo,
      container: _container,
    );
    _setupMethodCallHandler();
  }

  /// 设置方法调用处理器
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshotDetected') {
        final payload = _parseScreenshotPayload(call.arguments);
        final path = payload.path;
        if (path == null || path.isEmpty) return;
        await _handleScreenshot(path, sourceInfo: payload.sourceInfo);
      }
    });
  }

  /// 检查是否已启用
  Future<bool> isEnabled() async {
    if (_isGooglePlayBuild) return false;
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    return _isEnabled;
  }

  /// 是否已授予使用情况访问权限
  Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// 打开使用情况访问权限设置页
  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  /// 启用截图监听
  Future<void> enable() async {
    if (_isGooglePlayBuild) {
      throw UnsupportedError(
          'Screenshot monitoring is not available in Google Play builds');
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android 平台');
    }

    await _channel.invokeMethod('startScreenshotObserver');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    _isEnabled = true;
    _isMonitoring = true;
  }

  /// 禁用截图监听
  Future<void> disable() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopScreenshotObserver');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    _isEnabled = false;
    _isMonitoring = false;
  }

  /// 处理截图
  Future<void> _handleScreenshot(
    String path, {
    ScreenshotSourceInfo? sourceInfo,
  }) async {
    if (!_isEnabled || !_isMonitoring) return;

    await _billingJobService.processImage(path, sourceInfo: sourceInfo);
  }

  _ScreenshotPayload _parseScreenshotPayload(Object? arguments) {
    if (arguments is String) {
      return _ScreenshotPayload(path: arguments);
    }

    if (arguments is Map) {
      final map = Map<String, dynamic>.from(arguments);
      return _ScreenshotPayload(
        path: map['path']?.toString(),
        sourceInfo: ScreenshotSourceInfo.fromMap(map),
      );
    }

    return const _ScreenshotPayload();
  }

  /// 释放资源
  void dispose() {
    _billingJobService.dispose();
  }
}

class _ScreenshotPayload {
  final String? path;
  final ScreenshotSourceInfo? sourceInfo;

  const _ScreenshotPayload({
    this.path,
    this.sourceInfo,
  });
}
