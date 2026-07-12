import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/pending_bill_confirmation_service.dart';
import 'package:beecount/services/billing/personal_note_preference_store.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late List<PersonalRuleCorrection> remembered;
  late OcrResult createdBill;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    remembered = [];
  });

  tearDown(() => db.close());

  Future<BillingJob> draftJob() async {
    final job = await repo.createJob(imagePath: '/tmp/shared.png');
    await repo.updateSourceInfoJson(
        job.id,
        jsonEncode({
          'sourcePackage': 'com.tencent.mm',
          'sourceAppName': '微信',
        }));
    await repo.updateFinalResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '付款金额\n18.00\n交易时间\n2026-07-12 10:30',
        allNumbers: const ['18.00'],
        amount: 18,
        note: '结构化摘要',
      ).toJson()),
    );
    await repo.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    return (await repo.findById(job.id))!;
  }

  PendingBillConfirmationService service() => PendingBillConfirmationService(
        repo: repo,
        createTransaction: (result) async {
          createdBill = result;
          return 81;
        },
        applyCorrection: (correction) async {
          remembered.add(correction);
          return const PersonalRuleLifecycleResult(
            status: PersonalRuleLifecycleStatus.enabled,
            revision: 3,
          );
        },
      );

  test('仅本次确认创建交易且不生成个人候选规则', () async {
    final job = await draftJob();

    final result = await service().confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '和朋友聚餐',
      rememberForSimilarBills: false,
    );

    expect(result.transactionId, 81);
    expect(result.ruleResults, isEmpty);
    expect(remembered, isEmpty);
    expect(createdBill.note, '结构化摘要');
    expect(createdBill.details?['supplemental_note'], '和朋友聚餐');
    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(updated.transactionId, 81);
    final finalJson = jsonDecode(updated.finalResultJson!);
    expect(finalJson['note'], '结构化摘要');
    expect(finalJson['supplemental_note'], '和朋友聚餐');
  });

  test('记住时不为未经修改的候选字段生成规则', () async {
    final job = await draftJob();

    await service().confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '',
      rememberForSimilarBills: true,
    );

    expect(remembered.map((item) => item.field), ['time']);
  });

  test('记住时仅把有图片证据的字段修正送入生命周期服务', () async {
    final job = await draftJob();

    final result = await service().confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '图片外补充',
      rememberForSimilarBills: true,
    );

    expect(remembered.map((item) => item.field), ['amount', 'time']);
    expect(remembered.every((item) => !item.normalizedOcr.contains('图片外补充')),
        isTrue);
    expect(result.ruleResults, hasLength(2));
    expect(
        result.ruleResults.every(
            (item) => item.status == PersonalRuleLifecycleStatus.enabled),
        isTrue);
  });

  test('确认分类时可明确记住当前账本或全局规则', () async {
    final job = await draftJob();
    ({String matchText, int categoryId, bool global})? saved;
    final categoryService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (result) async {
        createdBill = result;
        return 82;
      },
      applyCorrection: service().applyCorrection,
      rememberCategory: (
          {required matchText, required categoryId, required global}) async {
        saved = (matchText: matchText, categoryId: categoryId, global: global);
      },
    );

    await categoryService.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '',
      rememberForSimilarBills: true,
      categoryId: 5,
      categoryRuleGlobal: true,
    );

    expect(createdBill.suggestedCategoryId, 5);
    expect(saved, (matchText: '结构化摘要', categoryId: 5, global: true));
  });

  test('对类似账单记住备注会生成待上传修订并在远端设备物化', () async {
    final job = await draftJob();
    final localStore = SqlitePersonalNotePreferenceStore(db);
    final noteService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_) async => 83,
      applyCorrection: service().applyCorrection,
      rememberNotePreference: localStore.remember,
    );

    await noteService.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '和朋友聚餐',
      rememberForSimilarBills: true,
    );

    final outgoing =
        await PersonalRuleSyncRepository(db).pendingUpload();
    final noteRevision = outgoing
        .singleWhere((revision) => revision.kind.name == 'notePreference');
    expect(noteRevision.payload, {'suffix': '和朋友聚餐'});
    expect(noteRevision.toSyncJson().toString().toLowerCase(),
        isNot(contains('ocr')));

    final remoteDb = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(remoteDb.close);
    await PersonalRuleSyncRepository(remoteDb).mergeRemote(
      [noteRevision],
      localDeviceId: 'device-b',
    );
    final materialized =
        await SqlitePersonalNotePreferenceStore(remoteDb).loadActive();
    expect(materialized, hasLength(1));
    expect(materialized.single.conditionKey, '结构化摘要');
    expect(materialized.single.payload, {'suffix': '和朋友聚餐'});
    expect(
        await SqlitePersonalNotePreferenceStore(remoteDb)
            .matchingSuffix('结构化摘要 天津和平测试门店甲'),
        '和朋友聚餐');
  });
}
