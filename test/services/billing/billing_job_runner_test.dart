import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStageProcessor implements StageProcessor {
  @override
  final String stageName;
  bool called = false;

  FakeStageProcessor(this.stageName);

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    return const StageResult.success();
  }
}

class FailingStageProcessor implements StageProcessor {
  @override
  final String stageName;
  bool called = false;

  FailingStageProcessor(this.stageName);

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    return const StageResult.failure('stage_failed', retryable: true);
  }
}

class NonRetryableFailingStageProcessor implements StageProcessor {
  @override
  final String stageName;
  final String errorMessage;
  bool called = false;

  NonRetryableFailingStageProcessor(this.stageName,
      {this.errorMessage = 'non_retryable_error'});

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    return StageResult.failure(errorMessage, retryable: false);
  }
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late FakeStageProcessor ocr;
  late FakeStageProcessor rule;
  late FakeStageProcessor tx;
  late FakeStageProcessor ai;
  late BillingJobRunner runner;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    ocr = FakeStageProcessor(BillingJobStage.ocrDone);
    rule = FakeStageProcessor(BillingJobStage.ruleDone);
    tx = FakeStageProcessor(BillingJobStage.transactionCreated);
    ai = FakeStageProcessor(BillingJobStage.aiDone);
    runner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('runJob completes all stages in order', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    expect(job.stage, BillingJobStage.received);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.completed);
    expect(ocr.called, isTrue);
    expect(rule.called, isTrue);
    expect(tx.called, isTrue);
    expect(ai.called, isTrue);
  });

  test('runJob reports progress status from the beginning', () async {
    final statuses = <String>[];
    final reportingRunner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
      statusReporter: statuses.add,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await reportingRunner.runJob(job, deadline);

    expect(
      statuses,
      containsAllInOrder([
        '已接收图片，准备识别账单',
        '正在识别账单文字',
        '正在提取账单字段',
        '正在创建账单',
        '正在完善账单信息',
        '账单识别完成，正在收尾',
      ]),
    );
  });

  test('runJob dispatches attachment before OCR finishes', () async {
    DateTime? attachmentCalledAt;
    DateTime? ocrFinishedAt;
    final slowOcr = _SlowStageProcessor(
      BillingJobStage.ocrDone,
      delay: const Duration(milliseconds: 50),
      onFinished: () => ocrFinishedAt = DateTime.now(),
    );
    final runnerWithAttachment = BillingJobRunner(
      repo: repo,
      ocrProcessor: slowOcr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
      attachmentProcessor: _TimedStageProcessor(
        onCalled: () => attachmentCalledAt = DateTime.now(),
      ),
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    expect(job.attachmentDone, isFalse);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runnerWithAttachment.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(attachmentCalledAt, isNotNull);
    expect(ocrFinishedAt, isNotNull);
    expect(attachmentCalledAt!.isBefore(ocrFinishedAt!), isTrue);
    expect(updated!.attachmentDone, isFalse);
    expect(updated.stage, BillingJobStage.completed);
  });

  test('runJob marks succeeded when ai_done without waiting for attachment',
      () async {
    final attachment = FakeStageProcessor('attachment');
    final runnerWithAttachment = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
      attachmentProcessor: attachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runnerWithAttachment.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(updated.attachmentDone, isFalse);
  });

  test('runJob stops at deadline and marks retryable_failed', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    expect(job.stage, BillingJobStage.received);

    final deadline = DateTime.now().subtract(const Duration(seconds: 1));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.retryableFailed);
    expect(updated.lastError, 'foreground_timeout');
    expect(updated.stage, BillingJobStage.received);
  });

  test('resumeJob continues from saved stage', () async {
    // Create a job and manually set stage to ocr_done (simulate OCR already completed)
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);
    final resumedJob = (await repo.findById(job.id))!;

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.resumeJob(resumedJob, deadline);

    // OCR should NOT have been called since we resumed from ocr_done
    expect(ocr.called, isFalse);
    expect(rule.called, isTrue);
    expect(tx.called, isTrue);
    expect(ai.called, isTrue);

    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.completed);
  });

  test('resumeJob skips already-completed stages', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateStage(job.id, BillingJobStage.transactionCreated);
    final resumedJob = (await repo.findById(job.id))!;

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.resumeJob(resumedJob, deadline);

    expect(ocr.called, isFalse);
    expect(rule.called, isFalse);
    expect(tx.called, isFalse);
    expect(ai.called, isTrue);

    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.completed);
  });

  test('resumeJob upgrades legacy ai_done without replaying processors',
      () async {
    final job = await repo.createJob(imagePath: '/tmp/legacy-ai-done.png');
    await repo.updateStage(job.id, BillingJobStage.aiDone);
    final legacyJob = (await repo.findById(job.id))!;

    await runner.resumeJob(
      legacyJob,
      DateTime.now().add(const Duration(seconds: 90)),
    );

    expect(ocr.called, isFalse);
    expect(rule.called, isFalse);
    expect(tx.called, isFalse);
    expect(ai.called, isFalse);
    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.completed);
    expect(updated.status, BillingJobStatus.succeeded);
  });

  test('resumeJob re-runs failed stage', () async {
    // Create a job, then simulate AI stage failure:
    // stage stays at transactionCreated because AI didn't succeed.
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateStage(job.id, BillingJobStage.transactionCreated);
    await repo.updateStatus(job.id, BillingJobStatus.retryableFailed,
        lastError: 'ai_timeout');
    final resumedJob = (await repo.findById(job.id))!;

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.resumeJob(resumedJob, deadline);

    // OCR, rule, and tx should NOT have been called
    expect(ocr.called, isFalse);
    expect(rule.called, isFalse);
    expect(tx.called, isFalse);
    // AI should have been called — re-runs the failed stage
    expect(ai.called, isTrue);

    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.completed);
  });

  test('runJob respects lease_until concurrency control', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    expect(job.stage, BillingJobStage.received);

    // Another runner claims the job with a 90-second lease.
    final claimed = await repo.claimJob(job.id, const Duration(seconds: 90));
    expect(claimed, isTrue);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    // Job should be skipped — stage must stay at received.
    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.received);
    expect(ocr.called, isFalse);
    expect(rule.called, isFalse);
    expect(tx.called, isFalse);
    expect(ai.called, isFalse);
  });

  test('runJob classifies retryable AI errors', () async {
    final retryableAi = FailingStageProcessor(BillingJobStage.aiDone);
    final retryableRunner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: retryableAi,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await retryableRunner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.retryableFailed);
    expect(updated.lastError, 'stage_failed');
  });

  test('runJob classifies non-retryable AI errors', () async {
    final nonRetryableAi = NonRetryableFailingStageProcessor(
      BillingJobStage.aiDone,
      errorMessage: 'api_key_missing',
    );
    final nonRetryableRunner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: nonRetryableAi,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await nonRetryableRunner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.failed);
    expect(updated.lastError, 'api_key_missing');
  });

  test('runJob increments attempt_count on failure', () async {
    final failingOcr = FailingStageProcessor(BillingJobStage.ocrDone);
    final failingRunner = BillingJobRunner(
      repo: repo,
      ocrProcessor: failingOcr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    expect(job.attemptCount, 0);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await failingRunner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.attemptCount, 1);
    expect(failingOcr.called, isTrue);
    expect(rule.called, isFalse);
  });

  test('runJob does not write AI errors to transaction detailsText', () async {
    // AI processor fails with a non-retryable error.
    final failingAi = NonRetryableFailingStageProcessor(
      BillingJobStage.aiDone,
      errorMessage: 'ai_api_error',
    );
    final failingRunner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: failingAi,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await failingRunner.runJob(job, deadline);

    // Error info must be written to the job table.
    final updated = await repo.findById(job.id);
    expect(updated!.lastError, 'ai_api_error');
    expect(updated.status, BillingJobStatus.failed);

    // Stage must stay at transactionCreated — AI failure must not advance the stage.
    expect(updated.stage, BillingJobStage.transactionCreated);

    // Upstream processors ran successfully; only AI failed.
    expect(ocr.called, isTrue);
    expect(rule.called, isTrue);
    expect(tx.called, isTrue);
    expect(failingAi.called, isTrue);
  });

  test('runJob succeeds even if attachment finishes before AI', () async {
    final slowAi = _SlowStageProcessor(
      BillingJobStage.aiDone,
      delay: const Duration(milliseconds: 50),
    );
    final fastAttachment = FakeStageProcessor('attachment');

    final runnerWithTiming = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: slowAi,
      attachmentProcessor: fastAttachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runnerWithTiming.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(fastAttachment.called, isTrue);
    expect(updated.stage, BillingJobStage.completed);
  });

  test(
      'runJob launches attachment after transaction creation but before AI done',
      () async {
    DateTime? attachmentCalledAt;
    DateTime? aiFinishedAt;

    final slowAi = _SlowStageProcessor(
      BillingJobStage.aiDone,
      delay: const Duration(milliseconds: 50),
      onFinished: () => aiFinishedAt = DateTime.now(),
    );
    final timedAttachment = _TimedStageProcessor(
      onCalled: () => attachmentCalledAt = DateTime.now(),
    );

    final runnerWithTiming = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: slowAi,
      attachmentProcessor: timedAttachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runnerWithTiming.runJob(job, deadline);

    expect(attachmentCalledAt, isNotNull);
    expect(aiFinishedAt, isNotNull);
    expect(attachmentCalledAt!.isBefore(aiFinishedAt!), isTrue);
  });

  test('runJob attachment failure does not block main pipeline', () async {
    final failingAttachment = FailingStageProcessor('attachment');
    final runnerWithFailingAttachment = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocr,
      ruleProcessor: rule,
      txProcessor: tx,
      aiProcessor: ai,
      attachmentProcessor: failingAttachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runnerWithFailingAttachment.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    // Main pipeline completed.
    expect(updated!.stage, BillingJobStage.completed);
    // Attachment failed — not marked done.
    expect(updated.attachmentDone, isFalse);
    // Attachment failure must not block the critical transaction job.
    expect(updated.status, BillingJobStatus.succeeded);
  });
}

class _SlowStageProcessor implements StageProcessor {
  @override
  final String stageName;
  final Duration delay;
  final void Function()? onFinished;

  _SlowStageProcessor(this.stageName, {required this.delay, this.onFinished});

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    await Future.delayed(delay);
    onFinished?.call();
    return const StageResult.success();
  }
}

class _TimedStageProcessor implements StageProcessor {
  @override
  String get stageName => 'attachment';
  final void Function() onCalled;

  _TimedStageProcessor({required this.onCalled});

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    onCalled();
    return const StageResult.success();
  }
}
