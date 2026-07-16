import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/stages/attachment_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalBillingJobRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
  });

  tearDown(() => db.close());

  test('retryable image resumes the same Billing Job instead of creating one',
      () async {
    final existing = await repo.createJob(imagePath: '/same/retry.png');
    await repo.updateStatus(existing.id, BillingJobStatus.retryableFailed);
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 701),
      processingDeadline: const Duration(milliseconds: 300),
      terminalPollInterval: const Duration(milliseconds: 5),
    );

    final transactionId = await service.processImage('/same/retry.png');

    expect(transactionId, 701);
    expect(await _jobCount(db), 1);
    expect(
        (await repo.findById(existing.id))!.status, BillingJobStatus.succeeded);
  });

  test('actively leased existing job is observed to its real terminal result',
      () async {
    final existing = await repo.createJob(imagePath: '/same/active.png');
    expect(
        await repo.claimJob(existing.id, const Duration(seconds: 1)), isTrue);
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 999),
      processingDeadline: const Duration(milliseconds: 300),
      terminalPollInterval: const Duration(milliseconds: 5),
    );
    unawaited(Future<void>.delayed(const Duration(milliseconds: 30), () async {
      await repo.updateTransactionId(existing.id, 702);
      await repo.updateStage(existing.id, BillingJobStage.completed);
      await repo.markSucceeded(existing.id);
    }));

    final transactionId = await service.processImage('/same/active.png');

    expect(transactionId, 702);
    expect(await _jobCount(db), 1);
    expect(
        (await repo.findById(existing.id))!.status, BillingJobStatus.succeeded);
  });

  test('active job is observed until the explicit deadline without replacement',
      () async {
    final existing = await repo.createJob(imagePath: '/same/deadline.png');
    expect(
        await repo.claimJob(existing.id, const Duration(seconds: 1)), isTrue);
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 998),
      processingDeadline: const Duration(milliseconds: 30),
      terminalPollInterval: const Duration(milliseconds: 5),
    );
    final stopwatch = Stopwatch()..start();

    final transactionId = await service.processImage('/same/deadline.png');

    expect(transactionId, isNull);
    expect(stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 20)));
    expect(await _jobCount(db), 1);
    expect(
        (await repo.findById(existing.id))!.status, BillingJobStatus.pending);
  });

  test('terminal jobs are reused and never replaced', () async {
    final awaiting = await repo.createJob(imagePath: '/same/awaiting.png');
    await repo.updateStatus(
      awaiting.id,
      BillingJobStatus.awaitingConfirmation,
    );
    final succeeded = await repo.createJob(imagePath: '/same/succeeded.png');
    await repo.updateTransactionId(succeeded.id, 703);
    await repo.markSucceeded(succeeded.id);
    final failed = await repo.createJob(imagePath: '/same/failed.png');
    await repo.updateStatus(failed.id, BillingJobStatus.failed);
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 997),
    );

    expect(await service.processImage(awaiting.imagePath), isNull);
    expect(await service.processImage(succeeded.imagePath), 703);
    expect(await service.processImage(failed.imagePath), isNull);
    expect(await _jobCount(db), 3);
  });

  test('lost delivery ownership cannot create a new Billing Job', () async {
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 996),
    );

    await expectLater(
      service.processImage(
        '/same/lost-before-create.png',
        ensureDeliveryOwned: () => throw StateError('delivery lease lost'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await _jobCount(db), 0);
  });

  test('new job captures the current ledger exactly once at image receipt',
      () async {
    var currentLedgerId = 7;
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(repo, transactionId: 705),
      currentLedgerId: () => currentLedgerId,
    );

    await service.processImage('/same/captured-ledger.png');
    currentLedgerId = 9;

    final job = await repo.findByImagePath('/same/captured-ledger.png');
    expect(job!.ledgerId, 7);
  });

  test('startup resumes an existing attachment artifact and marks it done',
      () async {
    final job = await repo.createJob(imagePath: '/same/restart.png');
    await repo.updateTransactionId(job.id, 704);
    await repo.updateStage(job.id, BillingJobStage.completed);
    await repo.markSucceeded(job.id);
    expect(await repo.claimJob(job.id, const Duration(seconds: -1)), isTrue);
    final attachmentService = _ExistingAttachmentService();
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(
        repo,
        transactionId: 704,
        attachmentProcessor: AttachmentStageProcessor(
          attachmentService: attachmentService,
          repo: repo,
        ),
      ),
      processingDeadline: const Duration(milliseconds: 300),
    );

    await service.resumePendingJobs();
    await _waitUntil(() async => (await repo.findById(job.id))!.attachmentDone);

    expect(attachmentService.saveCount, 1);
    expect(attachmentService.reusedExistingArtifact, isTrue);
    expect(await _jobCount(db), 1);
  });

  test('startup indexes attachment files once for multiple recovery jobs',
      () async {
    for (var i = 0; i < 2; i++) {
      final job = await repo.createJob(imagePath: '/same/restart-$i.png');
      await repo.updateTransactionId(job.id, 800 + i);
      await repo.updateStage(job.id, BillingJobStage.completed);
      await repo.markSucceeded(job.id);
    }
    final attachmentService = _ExistingAttachmentService();
    final service = BillingJobService.forTesting(
      repo: repo,
      runner: _runner(
        repo,
        transactionId: 800,
        attachmentProcessor: AttachmentStageProcessor(
          attachmentService: attachmentService,
          repo: repo,
        ),
      ),
      processingDeadline: const Duration(milliseconds: 300),
    );

    await service.resumePendingJobs();
    await _waitUntil(() async => attachmentService.saveCount == 2);

    expect(attachmentService.recoveryIndexCount, 1);
  });
}

Future<int> _jobCount(BeeDatabase db) async => (await db
        .customSelect('SELECT COUNT(*) AS count FROM billing_jobs')
        .getSingle())
    .read<int>('count');

BillingJobRunner _runner(
  BillingJobRepository repo, {
  required int transactionId,
  StageProcessor? attachmentProcessor,
}) =>
    BillingJobRunner(
      repo: repo,
      ocrProcessor: _SuccessStage(BillingJobStage.ocrDone),
      ruleProcessor: _SuccessStage(BillingJobStage.ruleDone),
      txProcessor: _TransactionStage(repo, transactionId),
      aiProcessor: _SuccessStage(BillingJobStage.completed),
      attachmentProcessor: attachmentProcessor,
    );

Future<void> _waitUntil(Future<bool> Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(milliseconds: 300));
  while (!await predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition was not met before timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _ExistingAttachmentService implements AttachmentSaveServiceInterface {
  int saveCount = 0;
  int recoveryIndexCount = 0;
  bool reusedExistingArtifact = false;

  @override
  Future<Set<String>> indexRecoveryFiles() async {
    recoveryIndexCount++;
    return const {};
  }

  @override
  Future<TransactionAttachment> saveAttachment(
    String imagePath,
    Future<int> transactionId, {
    required int billingJobId,
    required BillingJobLease lease,
    required BillingJobPublicationGate runFencedPublication,
    Set<String>? recoveryFileNames,
  }) async {
    final transactionIdValue = await transactionId;
    expect(transactionIdValue, greaterThan(0));
    expect(billingJobId, isNotNull);
    expect(
      await runFencedPublication(lease, () async => 'owned'),
      'owned',
    );
    saveCount++;
    reusedExistingArtifact = true;
    return TransactionAttachment(
      id: saveCount,
      transactionId: transactionIdValue,
      fileName: 'tx_${transactionIdValue}_${billingJobId}_0.jpg',
      originKey: 'billing:$billingJobId:0',
      sortOrder: 0,
      createdAt: DateTime(2026, 7, 15),
    );
  }
}

class _SuccessStage implements StageProcessor {
  _SuccessStage(this.stageName);

  @override
  final String stageName;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async =>
      const StageResult.success();
}

class _TransactionStage implements StageProcessor {
  _TransactionStage(this.repo, this.transactionId);

  final BillingJobRepository repo;
  final int transactionId;

  @override
  String get stageName => BillingJobStage.transactionCreated;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    await repo.updateTransactionId(job.id, transactionId);
    ctx.completeTransactionId(transactionId);
    return const StageResult.success();
  }
}
