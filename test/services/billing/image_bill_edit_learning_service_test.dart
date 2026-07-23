import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/image_bill_edit_learning_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('仅截图交易可找回 OCR 证据并学习明确修改的字段', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/shared.png',
      ledgerId: 7,
    );
    await jobs.updateFinalResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n18.00',
        allNumbers: const ['18.00'],
        amount: 18,
        time: DateTime(2026, 7, 18, 10, 30),
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
    await jobs.updateTransactionId(job.id, 42);
    final corrections = <PersonalRuleCorrection>[];
    final notePreferences = <({String matchText, String note})>[];
    final service = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (correction) async {
        corrections.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
        );
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        notePreferences.add((matchText: matchText, note: supplementalNote));
      },
    );

    final context = await service.loadContext(42);
    expect(context, isNotNull);
    expect(await service.loadContext(99), isNull);

    final result = await service.remember(
      context: context!,
      amount: 20,
      paymentMethod: '中国银行信用卡(2853)',
      supplementalNote: '和朋友聚餐',
    );

    expect(result.ruleResults, hasLength(2));
    expect(corrections, hasLength(2));
    expect(corrections.map((item) => item.field), ['amount', 'paymentMethod']);
    expect(corrections.map((item) => item.confirmedValue), [
      20,
      '中国银行信用卡(2853)',
    ]);
    for (final correction in corrections) {
      expect(correction.normalizedOcr, '付款金额\n18.00');
      expect(correction.sourcePackage, 'com.tencent.mm');
    }
    expect(
      notePreferences,
      [(matchText: '天津海河测试餐厅甲', note: '和朋友聚餐')],
    );
  });

  test('普通编辑只把忠实追加在结构化摘要后的文本视为补充备注', () {
    final context = ImageBillEditLearningContext(
      transactionId: 42,
      ledgerId: 7,
      original: OcrResult(
        rawText: '付款成功',
        allNumbers: const [],
        note: '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲',
      ),
      rawText: '付款成功',
      sourceInfoJson: null,
    );

    expect(
      context.supplementalNoteFrom('商户：天津海河测试餐厅甲\n商品：海河测试饮品甲\n和朋友聚餐'),
      '和朋友聚餐',
    );
    expect(
      context.supplementalNoteFrom('商户：瑞幸\n商品：海河测试饮品甲\n和朋友聚餐'),
      isNull,
    );
    expect(context.preferenceMatchText, '天津海河测试餐厅甲');

    final evidenceLess = ImageBillEditLearningContext(
      transactionId: 43,
      ledgerId: 7,
      original: OcrResult(
        rawText: '付款金额 18.00',
        allNumbers: const ['18.00'],
        amount: 18,
      ),
      rawText: '付款金额 18.00',
      sourceInfoJson: null,
    );
    expect(evidenceLess.preferenceMatchText, isNull);
  });

  test('自动创建成功的截图交易从规则结果找回 OCR 证据', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/automatic.png',
      ledgerId: 7,
    );
    await jobs.updateRawText(job.id, '付款金额\n29.90');
    await jobs.updateRuleResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n29.90',
        allNumbers: const ['29.90'],
        amount: 29.90,
        time: DateTime(2026, 7, 18, 11, 30),
        merchantFullName: '极光测试实验室',
      ).toJson()),
    );
    await jobs.updateTransactionId(job.id, 43);
    final service = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (_) async => const PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.enabled,
      ),
    );

    final context = await service.loadContext(43);

    expect(context, isNotNull);
    expect(context!.original.amount, 29.90);
    expect(context.original.merchantFullName, '极光测试实验室');
    expect(context.rawText, '付款金额\n29.90');
  });

  test('旧任务的最终结果损坏时回退到规则结果和交易账本', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(imagePath: '/tmp/legacy.png');
    await jobs.updateRawText(job.id, '付款金额\n36.00');
    await jobs.updateRuleResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n36.00',
        allNumbers: const ['36.00'],
        amount: 36,
        merchantFullName: '旧版商户',
      ).toJson()),
    );
    await jobs.updateFinalResultJson(job.id, '{amount: 36.0}');
    await jobs.updateTransactionId(job.id, 44);
    final failures = <Object>[];
    final service = ImageBillEditLearningService(
      jobs: jobs,
      applyCorrection: (_) async => const PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.enabled,
      ),
      logLearningFailure: (_, __, error, ___) => failures.add(error),
    );

    final context = await service.loadContext(44, fallbackLedgerId: 9);

    expect(context, isNotNull);
    expect(context!.ledgerId, 9);
    expect(context.original.amount, 36);
    expect(context.original.merchantFullName, '旧版商户');
    expect(failures, hasLength(1));
  });
}
