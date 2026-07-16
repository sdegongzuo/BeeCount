import 'dart:async';

import 'package:beecount/services/billing/pending_billing_navigation_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('关键待确认优先，待分类不会同时打开或重复导航', () async {
    final opened = <String>[];
    final criticalClosed = Completer<void>();
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: () async => 11,
      findOldestClassification: () async => 22,
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

  testWidgets('生产生命周期在启动或恢复时发现当前账本最早遗留账单', (tester) async {
    final opened = <int>[];
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: () async => null,
      findOldestClassification: () async => 7,
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
