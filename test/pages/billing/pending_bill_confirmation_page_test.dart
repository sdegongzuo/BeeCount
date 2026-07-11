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
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalBillingJobRepository(db);
    final job = await repo.createJob(imagePath: '/tmp/shared.png');
    await repo.updateFinalResultJson(
        job.id,
        jsonEncode(OcrResult(
          rawText: '付款金额\n18.00',
          allNumbers: const ['18.00'],
          amount: 18,
        ).toJson()));
    await repo.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    var remembered = false;
    final service = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_) async => 9,
      applyCorrection: (_) async {
        remembered = true;
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
        );
      },
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
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('仅本次'), findsOneWidget);
    expect(find.text('对类似账单记住'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('timeField')), '2026-07-12 10:30');
    await tester.tap(find.text('对类似账单记住'));
    await tester.tap(find.text('确认并创建账单'));
    await tester.pumpAndSettle();
    expect(remembered, isTrue);
    expect(find.textContaining('个人规则已启用'), findsOneWidget);
  });
}
