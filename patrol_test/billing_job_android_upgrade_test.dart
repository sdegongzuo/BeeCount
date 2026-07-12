import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/billing_notification_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('schema 26 Billing Job upgrades and resumes on Android', ($) async {
    await $.pumpWidget(const SizedBox.shrink());

    final directory = await getTemporaryDirectory();
    final databaseFile = File(p.join(
      directory.path,
      'billing_job_schema_26_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ));

    final seedDb = BeeDatabase.forTesting(NativeDatabase(databaseFile));
    final seedRepo = LocalBillingJobRepository(seedDb);
    final attachmentDone = await seedRepo.createJob(
      imagePath: '/instrumentation/attachment-done.png',
    );
    final attachmentPending = await seedRepo.createJob(
      imagePath: '/instrumentation/attachment-pending.png',
    );
    for (final job in [attachmentDone, attachmentPending]) {
      await seedRepo.updateRawText(job.id, 'historical OCR');
      await seedRepo.updateRuleResultJson(job.id, '{"amount":26}');
      await seedRepo.updateTransactionId(job.id, 2600 + job.id);
      await seedRepo.updateStage(job.id, BillingJobStage.aiDone);
    }
    await seedRepo.markAttachmentDone(attachmentDone.id);
    await seedDb.customStatement('PRAGMA user_version = 26');
    await seedDb.close();

    final db = BeeDatabase.forTesting(NativeDatabase(databaseFile));
    try {
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 27);

      final repo = LocalBillingJobRepository(db);
      final migratedDone = (await repo.findById(attachmentDone.id))!;
      final migratedPending = (await repo.findById(attachmentPending.id))!;
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
      await runner.resumeJob(
        migratedDone,
        DateTime.now().add(const Duration(seconds: 30)),
      );
      await runner.resumeJob(
        migratedPending,
        DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(calls, isEmpty,
          reason: '历史终态恢复不得重放 OCR、规则、交易或 AI');

      final restoredDone = (await repo.findById(attachmentDone.id))!;
      final restoredPending = (await repo.findById(attachmentPending.id))!;
      expect(restoredDone.status, BillingJobStatus.succeeded);
      expect(restoredPending.status, BillingJobStatus.succeeded);
      expect(restoredDone.attachmentDone, isTrue);
      expect(restoredPending.attachmentDone, isFalse);

      final mapper = BillingNotificationMapper();
      expect(mapper.map(restoredDone).title, '记账完成');
      expect(mapper.map(restoredPending).body, '附件稍后保存');
    } finally {
      await db.close();
    }
  });
}

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
