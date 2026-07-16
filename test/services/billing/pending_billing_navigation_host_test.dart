import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/smart_billing_providers.dart';
import 'package:beecount/services/billing/pending_billing_navigation_host.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('生产 Host 冷启动按当前账本打开真实待分类页面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final otherLedger = await repository.createLedger(name: '其他账本');
    final currentLedger = await repository.createLedger(name: '当前账本');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.addTransaction(
      ledgerId: otherLedger,
      type: 'expense',
      amount: 8,
      happenedAt: DateTime(2026, 7, 17, 8),
      note: '其他账本待分类',
      needsClassification: true,
    );
    await repository.addTransaction(
      ledgerId: currentLedger,
      type: 'expense',
      amount: 18,
      happenedAt: DateTime(2026, 7, 17, 9),
      note: '当前账本待分类',
      needsClassification: true,
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => currentLedger),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PendingBillingNavigationHost(
          child: Scaffold(body: Text('主页')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('待分类账单'), findsOneWidget);
    expect(find.text('当前账本待分类'), findsOneWidget);
    expect(find.text('其他账本待分类'), findsNothing);
  });

  testWidgets('生产 Host 连续消费分享通知，返回未处理页面后不立即重复发现', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '当前账本');
    await repository.createCategory(name: '其他', kind: 'expense');
    Future<int> addPending(int sequence) => repository.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: sequence.toDouble(),
          happenedAt: DateTime(2026, 7, 17, 10, sequence),
          note: '连续待分类-$sequence',
          needsClassification: true,
        );
    final first = await addPending(1);
    final second = await addPending(2);
    final third = await addPending(3);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
    ]);
    addTearDown(container.dispose);
    final navigationErrors = <Object>[];

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _testApp(
        PendingBillingNavigationHost(
          onNavigationError: (error, _) => navigationErrors.add(error),
          child: const Scaffold(body: Text('主页')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('连续待分类-1'), findsOneWidget);

    container.read(pendingTransactionClassificationIdProvider.notifier).state =
        second;
    container.read(pendingTransactionClassificationIdProvider.notifier).state =
        third;
    await tester.pump();
    Navigator.of(tester.element(find.text('待分类账单'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('连续待分类-2'), findsOneWidget);

    Navigator.of(tester.element(find.text('待分类账单'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('连续待分类-3'), findsOneWidget);

    Navigator.of(tester.element(find.text('待分类账单'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('待分类账单'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('连续待分类-1'), findsOneWidget);
    expect(first, isNot(second));
  });

  testWidgets('后台直接新增第二条后恢复前台，返回第一页会打开第二页且不重开第一页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '当前账本');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime(2026, 7, 17, 13),
      note: '前台已打开的第一条',
      needsClassification: true,
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _testApp(
        const PendingBillingNavigationHost(
          child: Scaffold(body: Text('主页')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('前台已打开的第一条'), findsOneWidget);

    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime(2026, 7, 17, 13, 1),
      note: '后台新增的第二条',
      needsClassification: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    Navigator.of(tester.element(find.text('待分类账单'))).pop();
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && find.text('后台新增的第二条').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('后台新增的第二条'), findsOneWidget);
    expect(find.text('前台已打开的第一条'), findsNothing);
  });

  testWidgets('生产 Host 同时发现两类记录时先打开真实关键待确认页面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '当前账本');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 23,
      happenedAt: DateTime(2026, 7, 17, 12),
      note: '稍后打开的待分类',
      needsClassification: true,
    );
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/missing/critical.png',
      ledgerId: ledgerId,
    );
    await jobs.updateFinalResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额 32.00',
        allNumbers: const ['32.00'],
        amount: 32,
        time: DateTime(2026, 7, 17, 11, 30),
        merchantFullName: '关键待确认商户',
      ).toJson()),
    );
    await jobs.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
    ]);
    addTearDown(container.dispose);
    final criticalNavigationErrors = <Object>[];

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _testApp(
        PendingBillingNavigationHost(
          onNavigationError: (error, _) => criticalNavigationErrors.add(error),
          child: const Scaffold(body: Text('主页')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('确认账单'), findsOneWidget);
    expect(find.text('待分类账单'), findsNothing);
    expect(
      await container
          .read(pendingTransactionClassificationServiceProvider)
          .listPending(ledgerId: ledgerId),
      hasLength(1),
    );
    Navigator.of(tester.element(find.text('确认账单'))).pop();
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && find.text('待分类账单').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(criticalNavigationErrors, isEmpty);
    expect(find.text('待分类账单'), findsOneWidget);
    expect(find.text('稍后打开的待分类'), findsOneWidget);
  });
}

Widget _testApp(Widget home) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
