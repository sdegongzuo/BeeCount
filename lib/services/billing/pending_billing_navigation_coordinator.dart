import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

/// 查询当前最早一条待处理记录的数据库 ID。
typedef PendingBillingFinder = Future<int?> Function();

/// 打开指定待处理页面，并在页面关闭后完成。
typedef PendingBillingOpener = Future<void> Function(int id);

/// 接收发现或导航失败；错误只上报，不触发自动重试。
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

  final LinkedHashSet<int> _criticalIds = LinkedHashSet<int>();
  final LinkedHashSet<int> _classificationIds = LinkedHashSet<int>();
  bool _discoverRequested = false;
  bool _running = false;
  int? _activeCriticalId;
  int? _activeClassificationId;

  /// 通知协调器有新的关键待确认 Billing Job。
  void notifyCritical(int jobId) {
    if (_activeCriticalId != jobId) _criticalIds.add(jobId);
    _schedule();
  }

  /// 通知协调器主 Flutter engine 刚创建了待分类交易。
  void notifyClassificationCreated(int transactionId) {
    if (_activeClassificationId != transactionId) {
      _classificationIds.add(transactionId);
    }
    _schedule();
  }

  /// 应用启动或回到前台时发现当前账本的遗留记录。
  void discoverOnForeground() {
    // 页面已打开时的 resumed 往往只是系统生命周期抖动；若记住这次发现，用户
    // 主动返回未处理页面后会立刻再次打开同一条记录。下一次真正回到前台再查。
    if (_running) return;
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
      final discoverClassification = _discoverRequested;
      final discoverCritical =
          _discoverRequested || _classificationIds.isNotEmpty;
      _discoverRequested = false;

      if (discoverCritical) {
        try {
          final id = await findOldestCritical();
          if (id != null && id != _activeCriticalId) _criticalIds.add(id);
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        }
      }
      if (discoverClassification) {
        try {
          final id = await findOldestClassification();
          if (id != null && id != _activeClassificationId) {
            _classificationIds.add(id);
          }
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        }
      }

      while (_criticalIds.isNotEmpty || _classificationIds.isNotEmpty) {
        if (_criticalIds.isNotEmpty) {
          final id = _criticalIds.first;
          _criticalIds.remove(id);
          _activeCriticalId = id;
          try {
            await openCritical(id);
          } catch (error, stackTrace) {
            onError?.call(error, stackTrace);
          } finally {
            _activeCriticalId = null;
          }
          continue;
        }

        final id = _classificationIds.first;
        _classificationIds.remove(id);
        _activeClassificationId = id;
        try {
          await openClassification(id);
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        } finally {
          _activeClassificationId = null;
        }
      }
    } finally {
      _activeCriticalId = null;
      _activeClassificationId = null;
      _running = false;
      if (_criticalIds.isNotEmpty ||
          _classificationIds.isNotEmpty ||
          _discoverRequested) {
        _schedule();
      }
    }
  }
}

/// 把应用启动和恢复前台事件转成待处理账单发现请求。
class PendingBillingForegroundObserver with WidgetsBindingObserver {
  /// 创建把生命周期事件转交给 [coordinator] 的观察器。
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
