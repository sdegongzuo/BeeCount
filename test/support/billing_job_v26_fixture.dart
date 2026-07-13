import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/billing_notification_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// 用真实历史 v26 表结构验证 v27 迁移、终态和代表性恢复路径。
Future<void> verifyHistoricalV26BillingJobUpgrade(File databaseFile) async {
  _seedHistoricalV26Database(databaseFile);

  final db = BeeDatabase.forTesting(NativeDatabase(databaseFile));
  try {
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 27);

    final repo = LocalBillingJobRepository(db);
    final migratedDone = (await repo.findById(2601))!;
    final migratedAttachmentPending = (await repo.findById(2602))!;
    final migratedInProgress = (await repo.findById(2603))!;
    final migratedRetryable = (await repo.findById(2604))!;
    expect(migratedDone.stage, BillingJobStage.completed);
    expect(migratedAttachmentPending.stage, BillingJobStage.completed);
    expect(migratedInProgress.stage, BillingJobStage.ocrDone);
    expect(migratedRetryable.stage, BillingJobStage.transactionCreated);

    final calls = <String>[];
    final reports = <String>[];
    final runner = BillingJobRunner(
      repo: repo,
      ocrProcessor: _RecordingProcessor(repo, BillingJobStage.ocrDone, calls),
      ruleProcessor: _RecordingProcessor(repo, BillingJobStage.ruleDone, calls),
      txProcessor: _RecordingProcessor(
        repo,
        BillingJobStage.transactionCreated,
        calls,
      ),
      aiProcessor: _RecordingProcessor(repo, BillingJobStage.aiDone, calls),
      statusReporter: reports.add,
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    await runner.resumeJob(migratedDone, deadline);
    await runner.resumeJob(migratedAttachmentPending, deadline);
    expect(calls, isEmpty, reason: '历史终态恢复不得重放 OCR、规则、交易或 AI');

    final restoredDone = (await repo.findById(2601))!;
    final restoredAttachmentPending = (await repo.findById(2602))!;
    expect(restoredDone.status, BillingJobStatus.succeeded);
    expect(restoredAttachmentPending.status, BillingJobStatus.succeeded);
    expect(restoredDone.attachmentDone, isTrue);
    expect(restoredAttachmentPending.attachmentDone, isFalse);

    final mapper = BillingNotificationMapper();
    final doneNotification = mapper.map(restoredDone);
    expect(doneNotification.title, '记账完成');
    expect(doneNotification.body, '账单已成功记录');
    final pendingNotification = mapper.map(restoredAttachmentPending);
    expect(pendingNotification.title, '记账已创建');
    expect(pendingNotification.body, '附件稍后保存');

    // 首次恢复会留下未到期租约：立即再次恢复必须被 claimJob 拦截。
    reports.clear();
    await runner.resumeJob((await repo.findById(2601))!, deadline);
    await runner.resumeJob((await repo.findById(2602))!, deadline);
    expect(reports, isEmpty, reason: '有效租约期内不得重复恢复');
    expect(calls, isEmpty);

    // 显式把租约改为历史时间，模拟真实的租约过期。再次恢复必须上报状态，
    // 证明 runner 确实通过生产 claimJob 并进入 completed 分支，且不重放。
    await db.customStatement(
      'UPDATE billing_jobs SET lease_until = 0 WHERE id IN (2601, 2602)',
    );
    reports.clear();
    await runner.resumeJob((await repo.findById(2601))!, deadline);
    await runner.resumeJob((await repo.findById(2602))!, deadline);
    expect(
      reports.where((value) => value == '正在恢复未完成的账单识别'),
      hasLength(2),
    );
    expect(calls, isEmpty);

    calls.clear();
    await runner.resumeJob(migratedInProgress, deadline);
    expect(calls, const [
      '2603:rule_done',
      '2603:transaction_created',
      '2603:ai_done',
    ]);
    final restoredInProgress = (await repo.findById(2603))!;
    expect(restoredInProgress.stage, BillingJobStage.completed);
    expect(restoredInProgress.status, BillingJobStatus.succeeded);
    expect(restoredInProgress.transactionId, 11603);

    calls.clear();
    await runner.resumeJob(migratedRetryable, deadline);
    expect(calls, const ['2604:ai_done']);
    final restoredRetryable = (await repo.findById(2604))!;
    expect(restoredRetryable.stage, BillingJobStage.completed);
    expect(restoredRetryable.status, BillingJobStatus.succeeded);
  } finally {
    await db.close();
  }
}

/// 使用 `b70b1b3^`（schema v26）生成代码对应的原始表结构创建夹具。
///
/// 不使用当前 [BeeDatabase] 建表、也不把 v27 数据库伪装成 v26，确保随后打开
/// 文件时确实走 Drift 的 26 -> 27 `onUpgrade`。
void _seedHistoricalV26Database(File file) {
  final oldDb = sqlite.sqlite3.open(file.path);
  try {
    oldDb.execute(_billingJobsV26Sql);
    oldDb.execute('PRAGMA user_version = 26');
    final insert = oldDb.prepare('''
      INSERT INTO billing_jobs (
        id, status, stage, transaction_id, image_path, raw_text,
        rule_result_json, attachment_done, last_error
      ) VALUES (?, ?, ?, ?, ?, 'historical OCR', '{"amount":26}', ?, ?)
    ''');
    try {
      insert.execute([
        2601,
        BillingJobStatus.pending,
        BillingJobStage.aiDone,
        2601,
        '/instrumentation/attachment-done.png',
        1,
        null,
      ]);
      insert.execute([
        2602,
        BillingJobStatus.pending,
        BillingJobStage.aiDone,
        2602,
        '/instrumentation/attachment-pending.png',
        0,
        null,
      ]);
      insert.execute([
        2603,
        BillingJobStatus.pending,
        BillingJobStage.ocrDone,
        null,
        '/instrumentation/in-progress.png',
        1,
        null,
      ]);
      insert.execute([
        2604,
        BillingJobStatus.retryableFailed,
        BillingJobStage.transactionCreated,
        2604,
        '/instrumentation/retryable.png',
        1,
        'ai_timeout',
      ]);
    } finally {
      insert.close();
    }
  } finally {
    oldDb.close();
  }
}

const _billingJobsV26Sql = '''
CREATE TABLE billing_jobs (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL DEFAULT 'image_share',
  status TEXT NOT NULL DEFAULT 'pending',
  stage TEXT NOT NULL DEFAULT 'received',
  transaction_id INTEGER,
  image_path TEXT NOT NULL,
  raw_text TEXT,
  ocr_engine TEXT,
  source_info_json TEXT,
  rule_result_json TEXT,
  final_result_json TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  lease_until INTEGER,
  attachment_done INTEGER NOT NULL DEFAULT 0
    CHECK (attachment_done IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
  updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
  completed_at INTEGER
)
''';

class _RecordingProcessor implements StageProcessor {
  _RecordingProcessor(this.repo, this.stageName, this.calls);

  final BillingJobRepository repo;

  @override
  final String stageName;

  final List<String> calls;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    calls.add('${job.id}:$stageName');
    if (stageName == BillingJobStage.transactionCreated) {
      final transactionId = 9000 + job.id;
      await repo.updateTransactionId(job.id, transactionId);
      ctx.completeTransactionId(transactionId);
    }
    return const StageResult.success();
  }
}
