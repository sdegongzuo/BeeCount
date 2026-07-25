import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/billing/image_bill_edit_learning_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('截图交易在普通编辑页修改金额后保存会询问是否更新规则', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    final categoryId =
        await repository.createCategory(name: '餐饮', kind: 'expense');
    final happenedAt = DateTime(2026, 7, 18, 10, 30);
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 18,
      discountAmount: 1,
      categoryId: categoryId,
      happenedAt: happenedAt,
      merchantFullName: '天津海河测试餐厅甲',
    );
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/shared.png',
      ledgerId: ledgerId,
    );
    // 可直接创建交易的生产任务保留 ruleResultJson，不会写
    // 只供待确认分支使用的 finalResultJson。
    await jobs.updateRuleResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n18.00',
        allNumbers: const ['18.00'],
        amount: 18,
        time: happenedAt,
        merchantFullName: '天津海河测试餐厅甲',
      ).toJson()),
    );
    await jobs.updateSourceInfoJson(
      job.id,
      jsonEncode({
        'sourceAppPackage': 'com.tencent.mm',
        'sourceAppName': '微信',
      }),
    );
    await jobs.updateTransactionId(job.id, transactionId);
    expect((await jobs.findById(job.id))!.finalResultJson, isNull);
    final corrections = <PersonalRuleCorrection>[];
    final learningService = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (correction) async {
        corrections.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.regressionRejected,
        );
      },
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
      imageBillEditLearningServiceProvider
          .overrideWith((_) async => learningService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TransactionEditorPage(
          initialKind: 'expense',
          quickAdd: true,
          initialCategoryId: categoryId,
          initialAmount: 18,
          initialDate: happenedAt,
          initialMerchantFullName: '天津海河测试餐厅甲',
          initialDiscountAmount: 1,
          editingTransactionId: transactionId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, '2'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, '0'));
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('是否更新个人规则？'), findsOneWidget);
    expect(find.text('仅本次'), findsOneWidget);
    expect(find.text('对类似账单记住'), findsOneWidget);
    expect((await repository.getTransactionById(transactionId))!.amount, 18);

    await tester.tap(find.text('对类似账单记住'));
    await tester.pumpAndSettle();

    expect((await repository.getTransactionById(transactionId))!.amount, 20);
    expect(
      (await repository.getTransactionById(transactionId))!.discountAmount,
      1,
    );
    expect(find.text('账单修改已保存；个人规则未通过回归门禁'), findsOneWidget);
    expect(corrections.single.field, 'amount');
    expect(corrections.single.confirmedValue, 20);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('截图交易在普通编辑页修改支付方式后保存会询问是否更新规则', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    final categoryId =
        await repository.createCategory(name: '餐饮', kind: 'expense');
    final happenedAt = DateTime(2026, 7, 18, 10, 30);
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 18,
      categoryId: categoryId,
      happenedAt: happenedAt,
      merchantFullName: '天津海河测试餐厅甲',
      paymentMethod: '微信支付',
    );
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/shared.png',
      ledgerId: ledgerId,
    );
    await jobs.updateRuleResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n18.00',
        allNumbers: const ['18.00'],
        amount: 18,
        time: happenedAt,
        merchantFullName: '天津海河测试餐厅甲',
      ).toJson()),
    );
    await jobs.updateSourceInfoJson(
      job.id,
      jsonEncode({
        'sourceAppPackage': 'com.tencent.mm',
        'sourceAppName': '微信',
      }),
    );
    await jobs.updateTransactionId(job.id, transactionId);
    expect((await jobs.findById(job.id))!.finalResultJson, isNull);
    final corrections = <PersonalRuleCorrection>[];
    final learningService = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (correction) async {
        corrections.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.regressionRejected,
        );
      },
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
      imageBillEditLearningServiceProvider
          .overrideWith((_) async => learningService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TransactionEditorPage(
          initialKind: 'expense',
          quickAdd: true,
          initialCategoryId: categoryId,
          initialAmount: 18,
          initialDate: happenedAt,
          initialMerchantFullName: '天津海河测试餐厅甲',
          initialPaymentMethod: '微信支付',
          editingTransactionId: transactionId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 找到支付方式输入框并修改
    final paymentMethodField = find.widgetWithText(TextField, '微信支付');
    expect(paymentMethodField, findsOneWidget);
    await tester.tap(paymentMethodField);
    await tester.pump();
    await tester.enterText(paymentMethodField, '支付宝');
    await tester.pump();

    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('是否更新个人规则？'), findsOneWidget);
    expect(find.text('仅本次'), findsOneWidget);
    expect(find.text('对类似账单记住'), findsOneWidget);
    expect(find.text('支付方式'), findsOneWidget);
    expect((await repository.getTransactionById(transactionId))!.paymentMethod,
        '微信支付');

    await tester.tap(find.text('对类似账单记住'));
    await tester.pumpAndSettle();

    expect((await repository.getTransactionById(transactionId))!.paymentMethod,
        '支付宝');
    expect(corrections, hasLength(1));
    expect(corrections.single.field, 'paymentMethod');
    expect(corrections.single.confirmedValue, '支付宝');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('支付方式归一化后相同不触发规则更新提示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    final categoryId =
        await repository.createCategory(name: '餐饮', kind: 'expense');
    final happenedAt = DateTime(2026, 7, 18, 10, 30);
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 18,
      categoryId: categoryId,
      happenedAt: happenedAt,
      merchantFullName: '天津海河测试餐厅甲',
      paymentMethod: '中国建设银行信用卡[1234]',
    );
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/shared.png',
      ledgerId: ledgerId,
    );
    await jobs.updateRuleResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n18.00',
        allNumbers: const ['18.00'],
        amount: 18,
        time: happenedAt,
        merchantFullName: '天津海河测试餐厅甲',
      ).toJson()),
    );
    await jobs.updateSourceInfoJson(
      job.id,
      jsonEncode({
        'sourceAppPackage': 'com.tencent.mm',
        'sourceAppName': '微信',
      }),
    );
    await jobs.updateTransactionId(job.id, transactionId);
    final learningService = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (correction) async {
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.regressionRejected,
        );
      },
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
      currentLedgerIdProvider.overrideWith((_) => ledgerId),
      imageBillEditLearningServiceProvider
          .overrideWith((_) async => learningService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TransactionEditorPage(
          initialKind: 'expense',
          quickAdd: true,
          initialCategoryId: categoryId,
          initialAmount: 18,
          initialDate: happenedAt,
          initialMerchantFullName: '天津海河测试餐厅甲',
          initialPaymentMethod: '中国建设银行信用卡[1234]',
          editingTransactionId: transactionId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 修改为归一化后相同的值
    final paymentMethodField =
        find.widgetWithText(TextField, '中国建设银行信用卡[1234]');
    expect(paymentMethodField, findsOneWidget);
    await tester.tap(paymentMethodField);
    await tester.pump();
    await tester.enterText(paymentMethodField, '中国建设银行信用卡(1234)');
    await tester.pump();

    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 500));

    // 归一化后相同，不应弹出提示
    expect(find.text('是否更新个人规则？'), findsNothing);
    expect((await repository.getTransactionById(transactionId))!.paymentMethod,
        '中国建设银行信用卡(1234)');
    await tester.pump(const Duration(seconds: 3));
  });
}
