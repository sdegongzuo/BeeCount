import 'dart:async';

import 'package:flutter/widgets.dart';

typedef PendingBillingFinder = Future<int?> Function();
typedef PendingBillingOpener = Future<void> Function(int id);
typedef PendingBillingNavigationErrorHandler = void Function(
    Object error, StackTrace stackTrace);

/// 串行协调“待确认账单”和“待分类账单”的生产导航。
///
/// 待确认账单包含建账所需的关键字段，优先级高于已经成功创建的待分类账单。
/// 同一时刻最多打开一个页面；页面打开期间收到的新请求会在页面关闭后继续处理。
class PendingBillingNavigationCoordinator {
  PendingBillingNavigationCoordinator({
    required this.findOldestCritical,
    required this.findOldestClassification,
    required this.openCritical,
    required this.openClassification,
    this.onError,
  });

  final PendingBillingFinder findOldestCritical;
  final PendingBillingFinder findOldestClassification;
  final PendingBillingOpener openCritical;
  final PendingBillingOpener openClassification;
  final PendingBillingNavigationErrorHandler? onError;

  int? _criticalId;
  int? _classificationId;
  bool _discoverRequested = false;
  bool _running = false;
  int? _activeCriticalId;
  int? _activeClassificationId;

  /// 通知协调器有新的关键待确认 Billing Job。
  void notifyCritical(int jobId) {
    if (_activeCriticalId != jobId) _criticalId = jobId;
    _schedule();
  }

  /// 通知协调器主 Flutter engine 刚创建了待分类交易。
  void notifyClassificationCreated(int transactionId) {
    if (_activeClassificationId != transactionId) {
      _classificationId = transactionId;
    }
    _schedule();
  }

  /// 应用启动或回到前台时发现当前账本的遗留记录。
  void discoverOnForeground() {
    _discoverRequested = true;
    _schedule();
  }

  void _schedule() {
    if (_running) return;
    _running = true;
    scheduleMicrotask(_drain);
  }

  Future<void> _drain() async {
    try {
      var mayDiscover = _discoverRequested || _classificationId != null;
      _discoverRequested = false;

      final criticalId =
          _criticalId ?? (mayDiscover ? await findOldestCritical() : null);
      _criticalId = null;
      if (criticalId != null) {
        _activeCriticalId = criticalId;
        await openCritical(criticalId);
        _activeCriticalId = null;
        // 关键页面关闭后继续处理期间收到的显式待分类通知，但不在同一轮
        // 再次发现同一个仍未处理的关键任务。
        mayDiscover = false;
      }

      final classificationId = _classificationId ??
          (mayDiscover ? await findOldestClassification() : null);
      _classificationId = null;
      if (classificationId != null) {
        _activeClassificationId = classificationId;
        await openClassification(classificationId);
        _activeClassificationId = null;
      }
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    } finally {
      _activeCriticalId = null;
      _activeClassificationId = null;
      _running = false;
      if (_criticalId != null ||
          _classificationId != null ||
          _discoverRequested) {
        _schedule();
      }
    }
  }
}

/// 把应用启动和恢复前台事件转成待处理账单发现请求。
class PendingBillingForegroundObserver with WidgetsBindingObserver {
  PendingBillingForegroundObserver(this.coordinator);

  final PendingBillingNavigationCoordinator coordinator;
  bool _started = false;

  /// 注册生命周期监听，并立即执行一次冷启动发现。
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    coordinator.discoverOnForeground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      coordinator.discoverOnForeground();
    }
  }

  /// 取消生命周期监听。
  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
