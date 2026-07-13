import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/billing_notification_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '真实 v26 Billing Job 在 Android 升级到 v27 并幂等恢复',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final databaseFile = File(p.join(
        directory.path,
        'billing_job_v26_upgrade_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      ));

      _seedHistoricalV26Database(databaseFile);

      final db = BeeDatabase.forTesting(NativeDatabase(databaseFile));
      try {
        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        expect(version.read<int>('user_version'), 27);

        final repo = LocalBillingJobRepository(db);
        final migratedDone = (await repo.findById(2601))!;
        final migratedPending = (await repo.findById(2602))!;
        expect(migratedDone.stage, BillingJobStage.completed);
        expect(migratedPending.stage, BillingJobStage.completed);

        final calls = <String>[];
        final runner = BillingJobRunner(
          repo: repo,
          ocrProcessor: _RecordingProcessor(BillingJobStage.ocrDone, calls),
          ruleProcessor: _RecordingProcessor(BillingJobStage.ruleDone, calls),
          txProcessor:
              _RecordingProcessor(BillingJobStage.transactionCreated, calls),
          aiProcessor: _RecordingProcessor(BillingJobStage.aiDone, calls),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        await runner.resumeJob(migratedDone, deadline);
        await runner.resumeJob(migratedPending, deadline);

        expect(calls, isEmpty, reason: '历史终态恢复不得重放 OCR、规则、交易或 AI');

        final restoredDone = (await repo.findById(2601))!;
        final restoredPending = (await repo.findById(2602))!;
        expect(restoredDone.status, BillingJobStatus.succeeded);
        expect(restoredPending.status, BillingJobStatus.succeeded);
        expect(restoredDone.attachmentDone, isTrue);
        expect(restoredPending.attachmentDone, isFalse);

        final mapper = BillingNotificationMapper();
        final doneNotification = mapper.map(restoredDone);
        expect(doneNotification.title, '记账完成');
        expect(doneNotification.body, '账单已成功记录');
        final pendingNotification = mapper.map(restoredPending);
        expect(pendingNotification.title, '记账已创建');
        expect(pendingNotification.body, '附件稍后保存');

        // 再恢复一次，证明已完成任务不会重放任何处理阶段。
        await runner.resumeJob(restoredDone, deadline);
        await runner.resumeJob(restoredPending, deadline);
        expect(calls, isEmpty);
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

/// 使用 `b70b1b3^`（schema v26）生成代码对应的原始表结构创建夹具。
///
/// 这里刻意不使用当前 [BeeDatabase] 建表、也不把 v27 数据库伪装成 v26，确保
/// 随后的打开动作确实走 Drift 的 26 -> 27 `onUpgrade`。
void _seedHistoricalV26Database(File file) {
  final oldDb = sqlite.sqlite3.open(file.path);
  try {
    oldDb.execute(_billingJobsV26Sql);
    oldDb.execute('PRAGMA user_version = 26');
    final insert = oldDb.prepare('''
      INSERT INTO billing_jobs (
        id, status, stage, transaction_id, image_path, raw_text,
        rule_result_json, attachment_done
      ) VALUES (?, 'pending', 'ai_done', ?, ?, 'historical OCR', ?, ?)
    ''');
    try {
      insert.execute([
        2601,
        2601,
        '/instrumentation/attachment-done.png',
        '{"amount":26}',
        1,
      ]);
      insert.execute([
        2602,
        2602,
        '/instrumentation/attachment-pending.png',
        '{"amount":26}',
        0,
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
  _RecordingProcessor(this.stageName, this.calls);

  @override
  final String stageName;
  final List<String> calls;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    calls.add(stageName);
    return const StageResult.success();
  }
}
