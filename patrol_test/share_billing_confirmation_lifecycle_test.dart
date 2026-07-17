import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/services/billing/billing_attachment_publisher.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/pending_bill_confirmation_service.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/personal_note_preference_store.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/platform/image_share_handler_service.dart';
import 'package:beecount/services/platform/share_billing_c2_container.dart';
import 'package:beecount/services/platform/share_billing_c2_fixture.dart';
import 'package:beecount/pages/billing/pending_bill_confirmation_page.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _tracer = MethodChannel('com.tntlikely.beecount/share_c2_tracer');

void main() {
  patrolTest(
    'ACTION_SEND production coordinator closes pending confirmation lifecycle',
    ($) async {
      const fixtureId = ShareBillingC2Fixture.compileTimeFixtureId;
      expect(fixtureId, isNotEmpty,
          reason: 'Patrol 必须传 BEECOUNT_SHARE_C2_FIXTURE_ID');
      final fixture = ShareBillingC2Fixture.fromRuntime(fixtureId)!;
      final runtime = await ShareBillingC2Container.create(fixture);
      final handler = ImageShareHandlerService(
        runtime.container,
        c2Fixture: fixture,
      );
      addTearDown(() async {
        handler.dispose();
        await runtime.dispose();
      });
      await $.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      await _send('reliable-1', _reliableBillText);
      final reliable = await _waitForJob(runtime.database, 1);
      expect(reliable.status, BillingJobStatus.succeeded);
      expect(reliable.transactionId, isNotNull);
      expect(await _transactionCount(runtime.database), 1);
      await _expectReliableTransactionAndAttachment(runtime, reliable);

      await _send('pending-current-only', _unreliableBillText);
      final currentOnlyJob = await _waitForJob(runtime.database, 2);
      expect(currentOnlyJob.status, BillingJobStatus.awaitingConfirmation);
      final service = await _confirmationService(runtime);
      final draft = await service.loadDraft(currentOnlyJob.id);
      expect(draft, isNotNull);
      expect(draft!.candidate.rawText, contains('实付金额'));
      expect(draft.candidate.allNumbers, isNotEmpty);

      final revisionsBefore = await _revisionCount(runtime.database);
      await _confirmThroughPage(
        $,
        service: service,
        jobId: currentOnlyJob.id,
        amount: _confirmedAmount(draft.candidate),
        rememberForSimilarBills: false,
      );
      final currentOnlyDone =
          await runtimeJob(runtime.database, currentOnlyJob.id);
      expect(currentOnlyDone?.status, BillingJobStatus.succeeded);
      expect(find.text('账单已创建'), findsOneWidget);
      expect(await _revisionCount(runtime.database), revisionsBefore);

      await _send('pending-remember', _unreliableBillText);
      final rememberJob = await _waitForJob(runtime.database, 3);
      expect(rememberJob.status, BillingJobStatus.awaitingConfirmation);
      final rememberDraft = (await service.loadDraft(rememberJob.id))!;
      final correctedAmount = _confirmedAmount(rememberDraft.candidate);
      await _confirmThroughPage(
        $,
        service: service,
        jobId: rememberJob.id,
        amount: correctedAmount,
        rememberForSimilarBills: true,
      );
      final rememberDone = await runtimeJob(runtime.database, rememberJob.id);
      expect(rememberDone?.status, BillingJobStatus.succeeded);
      expect(find.textContaining('个人规则已启用'), findsOneWidget);
      expect(
          await _revisionCount(runtime.database), greaterThan(revisionsBefore));

      final transactionCountBeforeFuture =
          await _transactionCount(runtime.database);
      await _send('future-similar', _futureSimilarBillText);
      final future = await _waitForJob(runtime.database, 4);
      expect(future.status, BillingJobStatus.awaitingConfirmation);
      expect(future.transactionId, isNull);
      expect(
        await _transactionCount(runtime.database),
        transactionCountBeforeFuture,
      );
      final futureJson =
          jsonDecode(future.finalResultJson!) as Map<String, dynamic>;
      final futureResult = OcrResult.fromJson(futureJson);
      expect(futureResult.amount, correctedAmount);
      final futureTrace =
          futureJson['billing_rule_trace'] as Map<String, dynamic>?;
      expect(
        futureTrace?['matched_rules'],
        contains(predicate<Map<String, dynamic>>(
          (rule) => rule['origin'] == 'personal',
        )),
      );
      expect(futureResult.fastBillingRejectReasons, contains('missing_time'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _confirmThroughPage(
  PatrolIntegrationTester $, {
  required PendingBillConfirmationService service,
  required int jobId,
  required double amount,
  required bool rememberForSimilarBills,
}) async {
  await $.pumpWidget(MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PendingBillConfirmationPage(jobId: jobId, service: service),
  ));
  await $.pumpAndSettle();
  expect(find.byType(PendingBillConfirmationPage), findsOneWidget);
  expect(find.byType(Image), findsOneWidget);
  expect(find.byKey(const Key('amountField')), findsOneWidget);
  expect(find.byKey(const Key('timeField')), findsOneWidget);

  await $.enterText(
    find.byKey(const Key('amountField')),
    amount.toStringAsFixed(2),
  );
  await $.enterText(
    find.byKey(const Key('timeField')),
    '2026-07-16 12:34',
  );
  if (rememberForSimilarBills) {
    final remember = find.byKey(const Key('rememberExtractionCorrections'));
    await $.tester.ensureVisible(remember);
    await $.tap(remember);
  }
  final confirm = find.text('确认并创建账单');
  await $.tester.ensureVisible(confirm);
  await $.tap(confirm);
  await $.pumpAndSettle();
}

Future<void> _expectReliableTransactionAndAttachment(
  ShareBillingC2Container runtime,
  BillingJob job,
) async {
  final repository = runtime.container.read(repositoryProvider);
  final transaction = await repository.getTransactionById(job.transactionId!);
  expect(transaction, isNotNull);
  expect(transaction!.amount, closeTo(18.5, 0.001));
  expect(transaction.happenedAt, DateTime(2026, 7, 16, 12, 34, 56));

  final List<TransactionAttachment> attachments =
      await repository.getAttachmentsByTransaction(transaction.id);
  expect(attachments, hasLength(1));
  final attachment = attachments.single;
  final documents = await getApplicationDocumentsDirectory();
  final isolatedDirectory = p.join(
    documents.path,
    runtime.fixture.attachmentDirectoryName,
  );
  final file = File(p.join(isolatedDirectory, attachment.fileName));
  expect(p.dirname(file.path), p.normalize(isolatedDirectory));
  expect(await file.exists(), isTrue);
  final decoded = await decodeCompleteBillingJobAttachmentBytes(
    await file.readAsBytes(),
    extension: p.extension(attachment.fileName),
  );
  expect(decoded, isNotNull);
  expect(decoded!.width, greaterThan(0));
  expect(decoded.height, greaterThan(0));
}

Future<PendingBillConfirmationService> _confirmationService(
    ShareBillingC2Container runtime) async {
  final jobs = runtime.container.read(billingJobRepositoryProvider);
  final base = runtime.container.read(repositoryProvider);
  final categoryRules = SqlitePersonalCategoryRuleStore(runtime.database);
  final notePreferences = SqlitePersonalNotePreferenceStore(runtime.database);
  final lifecycle =
      await BillingJobService.createProductionPersonalRuleLifecycle(
    runtime.database,
    regressionSamples: const _EmptyRegressionSamples(),
  );
  return PendingBillConfirmationService(
    repo: jobs,
    createTransaction: (result, {required int ledgerId}) async {
      final id = await BillCreationService(
        base,
        personalCategoryRules: categoryRules,
        personalNotePreferences: notePreferences,
      ).createBillTransaction(
        result: result,
        ledgerId: ledgerId,
        billingTypes: const ['image'],
      );
      if (id == null) throw StateError('confirmed_bill_not_created');
      return id;
    },
    applyCorrection: lifecycle.applyCorrection,
  );
}

Future<void> _send(String caseId, String text) async {
  final bytes = await _billPng(text);
  final result = await _tracer.invokeMapMethod<String, dynamic>(
    'sendActionSend',
    {
      'fixtureId': ShareBillingC2Fixture.compileTimeFixtureId,
      'caseId': caseId,
      'pngBytes': bytes,
    },
  );
  expect(result?['fixtureId'], ShareBillingC2Fixture.compileTimeFixtureId);
  expect(result?['caseId'], caseId);
}

Future<Uint8List> _billPng(String text) async {
  const size = ui.Size(1080, 1200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(color: Colors.black, fontSize: 52, height: 1.7),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 960);
  painter.paint(canvas, const Offset(60, 60));
  final image = await recorder.endRecording().toImage(1080, 1200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<BillingJob> _waitForJob(BeeDatabase db, int expectedCount) async {
  final deadline = DateTime.now().add(const Duration(seconds: 75));
  while (DateTime.now().isBefore(deadline)) {
    final rows = await db
        .customSelect(
          'SELECT id FROM billing_jobs ORDER BY id',
        )
        .get();
    if (rows.length >= expectedCount) {
      final job = await runtimeJob(db, rows[expectedCount - 1].read<int>('id'));
      if (job != null &&
          (job.status == BillingJobStatus.succeeded ||
              job.status == BillingJobStatus.awaitingConfirmation ||
              job.status == BillingJobStatus.failed)) {
        return job;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TimeoutException('Billing job $expectedCount did not become terminal');
}

Future<BillingJob?> runtimeJob(BeeDatabase db, int id) =>
    LocalBillingJobRepository(db).findById(id);

Future<int> _transactionCount(BeeDatabase db) async => (await db
        .customSelect('SELECT COUNT(*) AS count FROM transactions')
        .getSingle())
    .read<int>('count');

Future<int> _revisionCount(BeeDatabase db) async {
  final exists = await db
      .customSelect(
        "SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name='personal_rule_revisions'",
      )
      .getSingle();
  if (exists.read<int>('count') == 0) return 0;
  return (await db
          .customSelect('SELECT COUNT(*) AS count FROM personal_rule_revisions')
          .getSingle())
      .read<int>('count');
}

double _confirmedAmount(OcrResult result) {
  return ShareBillingC2Fixture.selectDistinctExactAmountCandidate(
    rawText: result.rawText,
    currentAmount: result.amount,
    candidates: result.allNumbers,
  );
}

class _EmptyRegressionSamples implements PersonalRuleRegressionSampleSource {
  const _EmptyRegressionSamples();

  @override
  Future<RegressionSampleBatch> readBatch() async =>
      const RegressionSampleBatch(
        samples: [],
        unreadableSampleIds: [],
        keyUnwrapCount: 0,
        timings: RegressionSampleTimings(
          keyUnwrapMs: 0,
          sampleReadMs: 0,
          decryptMs: 0,
          decodeMs: 0,
          totalMs: 0,
        ),
      );
}

const _reliableBillText = '''
账单详情
支付成功
-18.50
支付时间
2026-07-16 12:34:56
付款方式
余额
''';

const _unreliableBillText = '''
账单截图
商品金额
12.00
实付金额
18.50
''';

const _futureSimilarBillText = '''
账单截图
商品金额
12.00
实付金额
29.90
''';
