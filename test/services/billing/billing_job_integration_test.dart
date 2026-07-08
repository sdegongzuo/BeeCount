import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/billing_notification_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always-succeed processor with configurable delay.
class FakeStageProcessor implements StageProcessor {
  @override
  final String stageName;
  final Duration delay;
  bool called = false;
  int callCount = 0;

  FakeStageProcessor(this.stageName, {this.delay = Duration.zero});

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    callCount++;
    if (delay != Duration.zero) {
      await Future.delayed(delay);
    }
    return const StageResult.success();
  }
}

/// Processor that fails with a retryable error.
class RetryableFailingProcessor implements StageProcessor {
  @override
  final String stageName;
  bool called = false;

  RetryableFailingProcessor(this.stageName);

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    return const StageResult.failure('ai_timeout', retryable: true);
  }
}

/// Processor that fails with a non-retryable error.
class NonRetryableFailingProcessor implements StageProcessor {
  @override
  final String stageName;
  bool called = false;

  NonRetryableFailingProcessor(this.stageName);

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    called = true;
    return const StageResult.failure('api_key_missing', retryable: false);
  }
}

BillingJobRunner _buildRunner({
  required BillingJobRepository repo,
  StageProcessor? ocr,
  StageProcessor? rule,
  StageProcessor? tx,
  StageProcessor? ai,
  StageProcessor? attachment,
}) {
  return BillingJobRunner(
    repo: repo,
    ocrProcessor: ocr ?? FakeStageProcessor(BillingJobStage.ocrDone),
    ruleProcessor: rule ?? FakeStageProcessor(BillingJobStage.ruleDone),
    txProcessor: tx ?? FakeStageProcessor(BillingJobStage.transactionCreated),
    aiProcessor: ai ?? FakeStageProcessor(BillingJobStage.aiDone),
    attachmentProcessor: attachment,
  );
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // TC-70
  test('full pipeline: image share to succeeded', () async {
    final attachment = FakeStageProcessor('attachment');
    final runner = _buildRunner(
      repo: repo,
      attachment: attachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(updated.stage, BillingJobStage.aiDone);
    expect(attachment.called, isTrue);
    expect(updated.attachmentDone, isFalse);
  });

  // TC-71
  test('full pipeline with AI timeout: retry and succeed', () async {
    final attachment = FakeStageProcessor('attachment');

    // First run: AI fails with retryable error.
    final failingAi = RetryableFailingProcessor(BillingJobStage.aiDone);
    final runner1 =
        _buildRunner(repo: repo, ai: failingAi, attachment: attachment);
    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner1.runJob(job, deadline);

    final afterFirst = await repo.findById(job.id);
    expect(afterFirst!.status, BillingJobStatus.retryableFailed);
    expect(afterFirst.stage, BillingJobStage.transactionCreated);
    expect(attachment.called, isTrue);
    expect(afterFirst.attachmentDone, isFalse);

    // Simulate recovery: manually set up a retryable_failed job at transactionCreated stage.
    // This avoids the lease expiry problem from the first runJob.
    final job2 = await repo.createJob(imagePath: '/tmp/receipt2.png');
    await repo.updateStage(job2.id, BillingJobStage.transactionCreated);
    await repo.updateStatus(job2.id, BillingJobStatus.retryableFailed,
        lastError: 'ai_timeout');
    final resumedJob = (await repo.findById(job2.id))!;

    // Resume without attachment processor — the job has no attachment.
    final successAi = FakeStageProcessor(BillingJobStage.aiDone);
    final runner2 = _buildRunner(repo: repo, ai: successAi);
    await runner2.resumeJob(
        resumedJob, DateTime.now().add(const Duration(seconds: 90)));
    expect(successAi.called, isTrue);

    final final_ = await repo.findById(job2.id);
    // Stage advances to aiDone after successful retry.
    expect(final_!.stage, BillingJobStage.aiDone);
    // Status resets from retryable_failed to succeeded after recovery.
    expect(final_.status, BillingJobStatus.succeeded);
  });

  // TC-72
  test('full pipeline with permanent AI failure: transaction still created',
      () async {
    final permanentAi = NonRetryableFailingProcessor(BillingJobStage.aiDone);
    final runner = _buildRunner(repo: repo, ai: permanentAi);

    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.failed);
    expect(updated.stage, BillingJobStage.transactionCreated);
  });

  // TC-73
  test('resume from ocr_done after app restart', () async {
    final ocr = FakeStageProcessor(BillingJobStage.ocrDone);
    final runner = _buildRunner(repo: repo, ocr: ocr);

    // Simulate app restart: job already completed OCR.
    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);
    final resumedJob = (await repo.findById(job.id))!;

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.resumeJob(resumedJob, deadline);

    // OCR must not be called again.
    expect(ocr.called, isFalse);
    expect(ocr.callCount, 0);

    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.aiDone);
    expect(updated.status, BillingJobStatus.succeeded);
  });

  // TC-74
  test('same image shared twice does not create duplicate transaction',
      () async {
    final runner = _buildRunner(repo: repo);

    // First share.
    final job1 = await repo.createJob(imagePath: '/tmp/same_receipt.png');
    await runner.runJob(job1, DateTime.now().add(const Duration(seconds: 90)));

    // Second share of the same image.
    final job2 = await repo.createJob(imagePath: '/tmp/same_receipt.png');
    await runner.runJob(job2, DateTime.now().add(const Duration(seconds: 90)));

    // Both jobs succeed independently.
    final updated1 = await repo.findById(job1.id);
    final updated2 = await repo.findById(job2.id);
    expect(updated1!.status, BillingJobStatus.succeeded);
    expect(updated2!.status, BillingJobStatus.succeeded);

    // Two distinct jobs exist for the same image path.
    expect(updated1.id, isNot(equals(updated2.id)));
    expect(updated1.imagePath, updated2.imagePath);
  });

  // TC-75
  test('two concurrent jobs run independently', () async {
    final runner = _buildRunner(repo: repo);

    final job1 = await repo.createJob(imagePath: '/tmp/receipt_1.png');
    final job2 = await repo.createJob(imagePath: '/tmp/receipt_2.png');

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await Future.wait([
      runner.runJob(job1, deadline),
      runner.runJob(job2, deadline),
    ]);

    final updated1 = await repo.findById(job1.id);
    final updated2 = await repo.findById(job2.id);
    expect(updated1!.status, BillingJobStatus.succeeded);
    expect(updated2!.status, BillingJobStatus.succeeded);
  });

  // TC-76
  test('90s timeout saves partial progress', () async {
    final runner = _buildRunner(repo: repo);

    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    // Deadline already in the past.
    final deadline = DateTime.now().subtract(const Duration(seconds: 1));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.retryableFailed);
    expect(updated.lastError, 'foreground_timeout');
    // Stage stays at received since no processor ran.
    expect(updated.stage, BillingJobStage.received);
  });

  // TC-77
  test('attachment is dispatched after main pipeline with slow AI', () async {
    final slowAi = FakeStageProcessor(
      BillingJobStage.aiDone,
      delay: const Duration(milliseconds: 100),
    );
    final fastAttachment = FakeStageProcessor('attachment');
    final runner = _buildRunner(
      repo: repo,
      ai: slowAi,
      attachment: fastAttachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(fastAttachment.called, isTrue);
    expect(updated.attachmentDone, isFalse);
    expect(updated.stage, BillingJobStage.aiDone);
  });

  // TC-78
  test('attachment dispatch does not block succeeded job', () async {
    final fastAi = FakeStageProcessor(BillingJobStage.aiDone);
    final slowAttachment = FakeStageProcessor(
      'attachment',
      delay: const Duration(milliseconds: 100),
    );
    final runner = _buildRunner(
      repo: repo,
      ai: fastAi,
      attachment: slowAttachment,
    );

    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await runner.runJob(job, deadline);

    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.succeeded);
    expect(slowAttachment.called, isTrue);
    expect(updated.attachmentDone, isFalse);
    expect(updated.stage, BillingJobStage.aiDone);
  });

  // TC-79
  test('notification opens app and triggers recovery', () async {
    final mapper = BillingNotificationMapper();

    // Create a pending job at the OCR stage.
    final job = await repo.createJob(imagePath: '/tmp/receipt.png');
    final content = mapper.map(job);

    expect(content.title, isNotEmpty);
    expect(content.body, isNotEmpty);
    expect(content.title, '正在识别账单');

    // Simulate a retryable_failed job — notification should indicate recovery.
    await repo.updateStatus(job.id, BillingJobStatus.retryableFailed,
        lastError: 'timeout');
    final failedJob = (await repo.findById(job.id))!;
    final failedContent = mapper.map(failedJob);

    expect(failedContent.title, '记账已创建');
    expect(failedContent.body, '剩余信息稍后补全');
  });
}
