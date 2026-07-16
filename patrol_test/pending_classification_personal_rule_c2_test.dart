import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/billing/pending_transaction_classification_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/pending_billing_navigation_host.dart';
import 'package:beecount/services/platform/image_share_handler_service.dart';
import 'package:beecount/services/platform/share_billing_c2_container.dart';
import 'package:beecount/services/platform/share_billing_c2_fixture.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const _tracer = MethodChannel('com.tntlikely.beecount/share_c2_tracer');
const _merchant = '极光测试实验室';
const expectedStructuredNote = '商户：极光测试实验室';

void main() {
  patrolTest(
    'ACTION_SEND 待分类经生产页面记住账本规则，下一张相似账单立即命中',
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

      await $.pumpWidget(UncontrolledProviderScope(
        container: runtime.container,
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
            child: Scaffold(body: Text('C2 fixture 主页')),
          ),
        ),
      ));
      await $.tester.pump();

      await _send('classification-first', _firstBillText);
      final firstJob = await _waitForCaseJob(
        $,
        runtime,
        caseId: 'classification-first',
      );
      expect(firstJob.status, BillingJobStatus.succeeded);
      expect(firstJob.transactionId, isNotNull);
      final repository = runtime.container.read(repositoryProvider);
      final firstBefore =
          await repository.getTransactionById(firstJob.transactionId!);
      expect(firstBefore, isNotNull);
      expect(firstBefore!.needsClassification, isTrue);
      final fallback =
          await repository.getCategoryById(firstBefore.categoryId!);
      expect(fallback?.name, '其他');
      expect(firstBefore.amount, closeTo(18.50, 0.001));
      expect(firstBefore.happenedAt, DateTime(2026, 7, 17, 12, 34, 56));
      expect(firstBefore.merchantFullName, _merchant);
      expect(firstBefore.note, expectedStructuredNote);
      _expectLoyalStructuredNote(firstBefore.note);

      await _waitForWidget(
          $, find.byType(PendingTransactionClassificationPage));
      expect(find.text('商户：$_merchant'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
      await $.tester.ensureVisible(find.text('餐饮'));
      await $.tap(find.text('餐饮'));
      await $.tester.ensureVisible(find.text('记住到当前账本'));
      await $.tap(find.text('记住到当前账本'));
      await $.tester
          .ensureVisible(find.byKey(const Key('confirmClassification')));
      await $.tap(find.byKey(const Key('confirmClassification')));
      await _waitForWidgetGone(
        $,
        find.byType(PendingTransactionClassificationPage),
      );

      final firstAfter =
          await repository.getTransactionById(firstJob.transactionId!);
      expect(firstAfter, isNotNull);
      expect(firstAfter!.needsClassification, isFalse);
      expect(firstAfter.note, expectedStructuredNote);
      _expectLoyalStructuredNote(firstAfter.note);
      final selectedCategory =
          await repository.getCategoryById(firstAfter.categoryId!);
      expect(selectedCategory?.name, '餐饮');
      expect(selectedCategory?.syncId?.trim(), isNotEmpty);
      final rememberedRows = await runtime.database.customSelect(
        'SELECT match_text, category_sync_id, ledger_id '
        'FROM personal_category_rules WHERE match_text = ?',
        variables: [Variable<String>(_merchant)],
      ).get();
      expect(rememberedRows, hasLength(1));
      expect(rememberedRows.single.read<String>('category_sync_id'),
          selectedCategory!.syncId);
      expect(rememberedRows.single.read<int>('ledger_id'), firstAfter.ledgerId);

      await _send('classification-second', _secondBillText);
      final secondJob = await _waitForCaseJob(
        $,
        runtime,
        caseId: 'classification-second',
      );
      expect(secondJob.status, BillingJobStatus.succeeded);
      expect(secondJob.transactionId, isNotNull);
      final second =
          await repository.getTransactionById(secondJob.transactionId!);
      expect(second, isNotNull);
      expect(second!.needsClassification, isFalse);
      expect(second.note, expectedStructuredNote);
      _expectLoyalStructuredNote(second.note);
      expect(second.categoryId, selectedCategory.id);
      expect(second.amount, closeTo(29.90, 0.001));
      final secondOcr = OcrResult.fromJson(
        jsonDecode(secondJob.finalResultJson!) as Map<String, dynamic>,
      );
      expect(secondOcr.merchantFullName, _merchant);
      expect(secondOcr.suggestedCategoryId, isNull,
          reason: '第二张不能靠页面规则或测试注入分类，只能命中刚记住的个人规则');
      await $.tester.pump(const Duration(seconds: 2));
      expect(find.byType(PendingTransactionClassificationPage), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

void _expectLoyalStructuredNote(String? note) {
  expect(note, isNotNull);
  expect(note, isNot(contains('补充信息：')),
      reason: '没有用户补充时，结构化摘要不得混入自由文本');
  expect(note, isNot(contains('待分类')),
      reason: '分类状态必须保存在结构化字段，不得注入备注');
}

Future<void> _send(String caseId, String text) async {
  final result = await _tracer.invokeMapMethod<String, dynamic>(
    'sendActionSend',
    {
      'fixtureId': ShareBillingC2Fixture.compileTimeFixtureId,
      'caseId': caseId,
      'pngBytes': await _billPng(text),
    },
  );
  expect(result?['fixtureId'], ShareBillingC2Fixture.compileTimeFixtureId);
  expect(result?['caseId'], caseId);
}

Future<BillingJob> _waitForCaseJob(
  PatrolIntegrationTester $,
  ShareBillingC2Container runtime, {
  required String caseId,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final located = await _tracer.invokeMapMethod<String, dynamic>(
      'locateActionSend',
      {
        'fixtureId': ShareBillingC2Fixture.compileTimeFixtureId,
        'caseId': caseId,
      },
    );
    final path = located?['cacheImagePath']?.toString();
    if (path != null && path.isNotEmpty) {
      final job = await runtime.container
          .read(billingJobRepositoryProvider)
          .findByImagePath(path);
      if (job != null &&
          (job.status == BillingJobStatus.succeeded ||
              job.status == BillingJobStatus.awaitingConfirmation ||
              job.status == BillingJobStatus.failed ||
              job.status == BillingJobStatus.retryableFailed)) {
        return job;
      }
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
  throw TimeoutException('C2 case $caseId did not reach a terminal job');
}

Future<void> _waitForWidget(
  PatrolIntegrationTester $,
  Finder finder,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await $.tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException('Expected production widget did not open: $finder');
}

Future<void> _waitForWidgetGone(
  PatrolIntegrationTester $,
  Finder finder,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await $.tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TimeoutException('Production widget did not close: $finder');
}

Future<Uint8List> _billPng(String text) async {
  const size = ui.Size(1080, 1500);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(color: Colors.black, fontSize: 48, height: 1.55),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 960);
  painter.paint(canvas, const Offset(60, 50));
  final image = await recorder.endRecording().toImage(1080, 1500);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

const _firstBillText = '''
微信支付
支付详情
当前状态
支付成功
-18.50
支付时间
2026年07月17日 12:34:56
商户全称
极光测试实验室
支付方式
零钱
交易单号
4200002666202607171234567890
''';

const _secondBillText = '''
微信支付
支付详情
当前状态
支付成功
-29.90
支付时间
2026年07月17日 13:45:06
商户全称
极光测试实验室
支付方式
零钱
交易单号
4200002666202607179876543210
''';
