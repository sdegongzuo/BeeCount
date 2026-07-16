import 'dart:async';

import 'package:beecount/services/billing/pending_billing_navigation_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('关键待确认优先，待分类不会同时打开或重复导航', () async {
    final opened = <String>[];
    final criticalClosed = Completer<void>();
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async => 11,
      findOldestClassification: (_) async => 22,
      openCritical: (id) async {
        opened.add('critical:$id');
        await criticalClosed.future;
      },
      openClassification: (id) async => opened.add('classification:$id'),
    );

    coordinator.notifyClassificationCreated(22);
    coordinator.notifyClassificationCreated(22);
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['critical:11']);

    coordinator.notifyCritical(11);
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['critical:11']);
    criticalClosed.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['critical:11', 'classification:22']);
  });

  test('三个不同待分类通知按到达顺序打开，重复 ID 只打开一次', () async {
    final opened = <int>[];
    final firstClosed = Completer<void>();
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async => null,
      findOldestClassification: (_) async => null,
      openCritical: (_) async {},
      openClassification: (id) async {
        opened.add(id);
        if (id == 1) await firstClosed.future;
      },
    );

    coordinator.notifyClassificationCreated(1);
    await Future<void>.delayed(Duration.zero);
    coordinator.notifyClassificationCreated(2);
    coordinator.notifyClassificationCreated(2);
    coordinator.notifyClassificationCreated(3);
    expect(opened, [1]);

    firstClosed.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(opened, [1, 2, 3]);
  });

  test('当前页面关闭后，队列中的关键待确认先于待分类打开', () async {
    final opened = <String>[];
    final firstClosed = Completer<void>();
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async => null,
      findOldestClassification: (_) async => null,
      openCritical: (id) async => opened.add('critical:$id'),
      openClassification: (id) async {
        opened.add('classification:$id');
        if (id == 1) await firstClosed.future;
      },
    );

    coordinator.notifyClassificationCreated(1);
    await Future<void>.delayed(Duration.zero);
    coordinator.notifyClassificationCreated(2);
    coordinator.notifyCritical(9);
    firstClosed.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(opened, ['classification:1', 'critical:9', 'classification:2']);
  });

  test('前台 finder 失败只上报一次且不会微任务自旋', () async {
    var attempts = 0;
    final errors = <Object>[];
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async {
        attempts++;
        throw StateError('database unavailable');
      },
      findOldestClassification: (_) async => null,
      openCritical: (_) async {},
      openClassification: (_) async {},
      onError: (error, _) => errors.add(error),
    );

    coordinator.discoverOnForeground();
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(attempts, 1);
    expect(errors, hasLength(1));
  });

  test('页面打开期间的恢复事件不会在用户返回后立即重开未处理记录', () async {
    final opened = <int>[];
    final firstClosed = Completer<void>();
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async => null,
      findOldestClassification: (excludedIds) async =>
          excludedIds.contains(5) ? null : 5,
      openCritical: (_) async {},
      openClassification: (id) async {
        opened.add(id);
        if (opened.length == 1) await firstClosed.future;
      },
    );

    coordinator.discoverOnForeground();
    await Future<void>.delayed(Duration.zero);
    expect(opened, [5]);
    coordinator.discoverOnForeground();
    firstClosed.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(opened, [5]);

    coordinator.discoverOnForeground();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(opened, [5, 5]);
  });

  testWidgets('生产生命周期在启动或恢复时发现当前账本最早遗留账单', (tester) async {
    final opened = <int>[];
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (_) async => null,
      findOldestClassification: (_) async => 7,
      openCritical: (_) async {},
      openClassification: (id) async => opened.add(id),
    );

    final observer = PendingBillingForegroundObserver(coordinator)..start();
    addTearDown(observer.dispose);
    await tester.pump();
    await tester.pump();
    expect(opened, [7]);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(opened, [7, 7]);
  });
}
