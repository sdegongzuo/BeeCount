import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/billing/pending_bill_confirmation_page.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/pending_bill_confirmation_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('预填候选并明确区分证据、补充信息和记住范围', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalBillingJobRepository(db);
    final job = await repo.createJob(imagePath: '/tmp/shared.png', ledgerId: 7);
    await repo.updateFinalResultJson(
        job.id,
        jsonEncode(OcrResult(
          rawText: '付款金额\n18.00',
          allNumbers: const ['18.00'],
          amount: 18,
          merchantFullName: '天津海河测试餐厅甲',
        ).toJson()));
    await repo.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    var extractionRemembered = false;
    var noteRemembered = false;
    var createCount = 0;
    ({String matchText, int categoryId, bool global})? rememberedCategory;
    final service = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async {
        createCount++;
        return 9;
      },
      applyCorrection: (_) async {
        extractionRemembered = true;
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
        );
      },
      loadCategories: () async => const [
        ConfirmableCategory(7, '餐饮 / 咖啡'),
        ConfirmableCategory(8, '其他'),
      ],
      rememberCategory: (
          {required matchText,
          required categoryId,
          required global,
          required ledgerId}) async {
        rememberedCategory = (
          matchText: matchText,
          categoryId: categoryId,
          global: global,
        );
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        noteRemembered = true;
        throw StateError('note_preference_failed');
      },
      logLearningFailure: (_, __, ___, ____) {},
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PendingBillConfirmationPage(jobId: job.id, service: service),
    ));
    await tester.pumpAndSettle();

    expect(find.text('确认账单'), findsOneWidget);
    expect(find.text('图片证据字段'), findsOneWidget);
    expect(find.text('账单补充信息（仅本次）'), findsOneWidget);
    expect(find.text('18.00'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('timeField')), '2026-07-12 10:30');
    await tester.tap(find.byKey(const Key('rememberCategoryRule')));
    await tester.tap(find.text('确认并创建账单'));
    await tester.pumpAndSettle();
    expect(find.text('请先选择分类，再开启“记住分类”'), findsOneWidget);
    expect(createCount, 0);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rememberCategoryRule')));
    await tester.tap(find.byKey(const Key('categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮 / 咖啡').last);
    expect(
        find.byKey(const Key('rememberExtractionCorrections')), findsOneWidget);
    expect(find.byKey(const Key('rememberCategoryRule')), findsOneWidget);
    expect(find.byKey(const Key('rememberNotePreference')), findsOneWidget);
    expect(find.byKey(const Key('globalCategoryRule')), findsNothing);

    await tester.enterText(find.byKey(const Key('supplementField')), '和朋友聚餐');
    await tester.tap(find.byKey(const Key('rememberCategoryRule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('globalCategoryRule')), findsOneWidget);
    await tester.tap(find.byKey(const Key('globalCategoryRule')));
    await tester.tap(find.byKey(const Key('rememberNotePreference')));
    await tester.tap(find.text('确认并创建账单'));
    await tester.pumpAndSettle();
    expect(extractionRemembered, isFalse);
    expect(noteRemembered, isTrue);
    expect(createCount, 1);
    expect(
      rememberedCategory,
      (matchText: '天津海河测试餐厅甲', categoryId: 7, global: true),
    );
    expect(find.textContaining('账单已创建，但部分记忆未完成'), findsOneWidget);
    expect(find.textContaining('备注偏好保存失败'), findsOneWidget);
    expect(find.textContaining('note_preference_failed'), findsNothing);
  });
}
