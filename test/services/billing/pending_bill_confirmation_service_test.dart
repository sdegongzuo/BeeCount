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

  Future<BillingJob> draftJob({int? ledgerId = 7}) async {
    final job = await repo.createJob(
      imagePath: '/tmp/shared.png',
      ledgerId: ledgerId,
    );
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
        merchantFullName: '天津海河测试餐厅甲',
      ).toJson()),
    );
    await repo.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    return (await repo.findById(job.id))!;
  }

  PendingBillConfirmationService service() => PendingBillConfirmationService(
        repo: repo,
        createTransaction: (result, {required ledgerId}) async {
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

  test('confirmation creates and learns against the ledger captured by the job',
      () async {
    final job = await draftJob(ledgerId: 7);
    int? transactionLedgerId;
    int? categoryLedgerId;
    final scopedService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (result, {required ledgerId}) async {
        transactionLedgerId = ledgerId;
        return 80;
      },
      applyCorrection: service().applyCorrection,
      rememberCategory: ({
        required matchText,
        required categoryId,
        required global,
        required ledgerId,
      }) async {
        categoryLedgerId = ledgerId;
      },
    );

    await scopedService.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '',
      categoryId: 5,
      rememberCategoryRule: true,
    );

    expect(transactionLedgerId, 7);
    expect(categoryLedgerId, 7);
  });

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
      rememberExtractionCorrections: true,
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
      rememberExtractionCorrections: true,
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
      createTransaction: (result, {required ledgerId}) async {
        createdBill = result;
        return 82;
      },
      applyCorrection: service().applyCorrection,
      rememberCategory: (
          {required matchText,
          required categoryId,
          required global,
          required ledgerId}) async {
        saved = (matchText: matchText, categoryId: categoryId, global: global);
      },
    );

    await categoryService.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '',
      rememberCategoryRule: true,
      categoryId: 5,
      categoryRuleGlobal: true,
    );

    expect(createdBill.suggestedCategoryId, 5);
    expect(saved, (matchText: '天津海河测试餐厅甲', categoryId: 5, global: true));
  });

  test('对类似账单记住备注会生成待上传修订并在远端设备物化', () async {
    final job = await draftJob();
    final localStore = SqlitePersonalNotePreferenceStore(db);
    final noteService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 83,
      applyCorrection: service().applyCorrection,
      rememberNotePreference: localStore.remember,
    );

    await noteService.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      supplementalNote: '和朋友聚餐',
      rememberNotePreference: true,
    );

    final outgoing = await PersonalRuleSyncRepository(db).pendingUpload();
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
    expect(materialized.single.conditionKey, '天津海河测试餐厅甲');
    expect(materialized.single.payload, {'suffix': '和朋友聚餐'});
    expect(
        await SqlitePersonalNotePreferenceStore(remoteDb)
            .matchingSuffix('天津海河测试餐厅甲 天津和平测试门店甲'),
        '和朋友聚餐');
  });

  test('分类记忆可独立于提取修正和备注偏好开启', () async {
    final job = await draftJob();
    ({String matchText, int categoryId, bool global})? savedCategory;
    var savedNote = false;
    final independentService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 84,
      applyCorrection: (correction) async {
        remembered.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
          revision: 1,
        );
      },
      rememberCategory: (
          {required matchText,
          required categoryId,
          required global,
          required ledgerId}) async {
        savedCategory =
            (matchText: matchText, categoryId: categoryId, global: global);
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        savedNote = true;
      },
    );

    await independentService.confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 31),
      supplementalNote: '本次补充',
      categoryId: 5,
      categoryRuleGlobal: false,
      rememberExtractionCorrections: false,
      rememberCategoryRule: true,
      rememberNotePreference: false,
    );

    expect(remembered, isEmpty);
    expect(savedNote, isFalse);
    expect(savedCategory, (matchText: '天津海河测试餐厅甲', categoryId: 5, global: false));
  });

  test('提取修正可单独开启而不记忆分类或备注', () async {
    final job = await draftJob();
    var categorySaved = false;
    var noteSaved = false;
    final independentService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 85,
      applyCorrection: (correction) async {
        remembered.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
          revision: 1,
        );
      },
      rememberCategory: (
          {required matchText,
          required categoryId,
          required global,
          required ledgerId}) async {
        categorySaved = true;
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        noteSaved = true;
      },
    );

    await independentService.confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 31),
      supplementalNote: '只用于当前交易',
      categoryId: 5,
      rememberExtractionCorrections: true,
      rememberCategoryRule: false,
      rememberNotePreference: false,
    );

    expect(remembered.map((item) => item.field), ['amount', 'time']);
    expect(categorySaved, isFalse);
    expect(noteSaved, isFalse);
  });

  test('备注偏好可单独开启而不学习提取修正或分类', () async {
    final job = await draftJob();
    ({String matchText, String supplementalNote})? savedNote;
    final independentService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 86,
      applyCorrection: (correction) async {
        remembered.add(correction);
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
          revision: 1,
        );
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        savedNote = (matchText: matchText, supplementalNote: supplementalNote);
      },
    );

    await independentService.confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 31),
      supplementalNote: '以后都加这句',
      categoryId: 5,
      rememberExtractionCorrections: false,
      rememberCategoryRule: false,
      rememberNotePreference: true,
    );

    expect(remembered, isEmpty);
    expect(savedNote, (matchText: '天津海河测试餐厅甲', supplementalNote: '以后都加这句'));
  });

  test('可选学习失败不影响交易和 job 成功，其他学习仍继续并返回错误', () async {
    final job = await draftJob();
    final correctedFields = <String>[];
    var categorySaved = false;
    var noteSaved = false;
    final resilientService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 87,
      applyCorrection: (correction) async {
        correctedFields.add(correction.field);
        if (correction.field == 'amount') {
          throw StateError('amount_rule_write_failed');
        }
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
          revision: 1,
        );
      },
      rememberCategory: (
          {required matchText,
          required categoryId,
          required global,
          required ledgerId}) async {
        categorySaved = true;
      },
      rememberNotePreference: (
          {required matchText, required supplementalNote}) async {
        noteSaved = true;
      },
    );

    final result = await resilientService.confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 31),
      supplementalNote: '需要记住的补充',
      categoryId: 5,
      rememberExtractionCorrections: true,
      rememberCategoryRule: true,
      rememberNotePreference: true,
    );

    expect(result.transactionId, 87);
    expect(result.learningStatus, PendingBillLearningStatus.partiallyFailed);
    expect(result.learningErrors, hasLength(1));
    expect(result.learningErrors.single.kind,
        PendingBillLearningKind.extractionCorrection);
    expect(result.learningErrors.single.target, 'amount');
    expect(
      result.learningErrors.single.reason,
      PendingBillLearningReason.extractionCorrectionFailed,
    );
    expect(correctedFields, ['amount', 'time']);
    expect(categorySaved, isTrue);
    expect(noteSaved, isTrue);
    expect((await repo.findById(job.id))!.status, BillingJobStatus.succeeded);

    await expectLater(
      resilientService.confirm(
        jobId: job.id,
        amount: 20,
        time: DateTime(2026, 7, 12, 10, 31),
        supplementalNote: '',
      ),
      throwsA(isA<PendingBillConfirmationException>().having(
        (error) => error.code,
        'code',
        PendingBillConfirmationErrorCode.billingJobNotAwaitingConfirmation,
      )),
    );
  });

  test('损坏的来源 JSON 只报告提取学习错误并继续备注和分类学习', () async {
    final job = await draftJob();
    await repo.updateSourceInfoJson(job.id, '{not-json');
    var extractionCalled = false;
    var categorySaved = false;
    var noteSaved = false;
    final resilientService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async => 88,
      applyCorrection: (_) async {
        extractionCalled = true;
        return const PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.enabled,
        );
      },
      rememberCategory: ({
        required matchText,
        required categoryId,
        required global,
        required ledgerId,
      }) async {
        categorySaved = true;
      },
      rememberNotePreference: ({
        required matchText,
        required supplementalNote,
      }) async {
        noteSaved = true;
      },
    );

    final result = await resilientService.confirm(
      jobId: job.id,
      amount: 20,
      time: DateTime(2026, 7, 12, 10, 31),
      supplementalNote: '以后都加这句',
      categoryId: 5,
      rememberExtractionCorrections: true,
      rememberCategoryRule: true,
      rememberNotePreference: true,
    );

    expect(result.transactionId, 88);
    expect(extractionCalled, isFalse);
    expect(categorySaved, isTrue);
    expect(noteSaved, isTrue);
    expect(result.learningErrors, hasLength(1));
    expect(
      result.learningErrors.single.reason,
      PendingBillLearningReason.sourceInfoInvalid,
    );
  });

  test(
      'requesting category memory without a category is typed and creates no bill',
      () async {
    final job = await draftJob();
    var createCount = 0;
    final guardedService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async {
        createCount++;
        return 89;
      },
      applyCorrection: service().applyCorrection,
    );

    await expectLater(
      guardedService.confirm(
        jobId: job.id,
        amount: 18,
        time: DateTime(2026, 7, 12, 10, 30),
        supplementalNote: '',
        rememberCategoryRule: true,
      ),
      throwsA(isA<PendingBillConfirmationException>().having(
        (error) => error.code,
        'code',
        PendingBillConfirmationErrorCode.rememberedCategoryRequired,
      )),
    );
    expect(createCount, 0);
  });

  test(
      'legacy job without a ledger remains visible but cannot guess on confirm',
      () async {
    final job = await draftJob(ledgerId: null);
    var createCount = 0;
    final guardedService = PendingBillConfirmationService(
      repo: repo,
      createTransaction: (_, {required ledgerId}) async {
        createCount++;
        return 90;
      },
      applyCorrection: service().applyCorrection,
    );

    expect((await guardedService.loadDraft(job.id))!.ledgerId, null);
    await expectLater(
      guardedService.confirm(
        jobId: job.id,
        amount: 18,
        time: DateTime(2026, 7, 12, 10, 30),
        supplementalNote: '',
      ),
      throwsA(isA<PendingBillConfirmationException>().having(
        (error) => error.code,
        'code',
        PendingBillConfirmationErrorCode.billingJobLedgerMissing,
      )),
    );
    expect(createCount, 0);
  });
}
