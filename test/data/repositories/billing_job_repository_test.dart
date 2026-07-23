import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_attachment_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

  test('billing job preserves the ledger captured when the image arrived',
      () async {
    final job = await repo.createJob(
      imagePath: '/tmp/original-ledger.png',
      ledgerId: 42,
    );

    expect(job.ledgerId, 42);
    expect((await repo.findById(job.id))!.ledgerId, 42);
  });

  test('create job with initial stage=received', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');

    expect(job.stage, BillingJobStage.received);
    expect(job.status, BillingJobStatus.pending);
    expect(job.attemptCount, 0);
  });

  test('update stage advances job progress', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);
    final updated = await repo.findById(job.id);
    expect(updated!.stage, BillingJobStage.ocrDone);
  });

  test('completed terminal stage can be persisted and restored', () async {
    final job = await repo.createJob(imagePath: '/tmp/completed.png');

    await repo.updateStage(job.id, BillingJobStage.completed);

    final restored = await repo.findById(job.id);
    expect(restored!.stage, BillingJobStage.completed);
  });

  test('schema 27 migration upgrades legacy ai_done to completed', () async {
    final underlying = sqlite.sqlite3.openInMemory();
    final oldDb = BeeDatabase.forTesting(NativeDatabase.opened(
      underlying,
      closeUnderlyingOnClose: false,
    ));
    final oldRepo = LocalBillingJobRepository(oldDb);
    final job = await oldRepo.createJob(imagePath: '/tmp/legacy.png');
    await oldRepo.updateStage(job.id, BillingJobStage.aiDone);
    await oldDb.customStatement('PRAGMA user_version = 26');
    await oldDb.close();

    final upgradedDb =
        BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    final upgraded =
        await LocalBillingJobRepository(upgradedDb).findById(job.id);

    expect(upgraded!.stage, BillingJobStage.completed);
    await upgradedDb.close();
  });

  test('update status to retryable_failed records last_error', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateStatus(job.id, BillingJobStatus.retryableFailed,
        lastError: 'network timeout');
    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.retryableFailed);
    expect(updated.lastError, 'network timeout');
    expect(updated.attemptCount, 1);
  });

  test('findPendingJobs returns pending and retryable_failed', () async {
    final pending = await repo.createJob(imagePath: '/tmp/pending.png');
    final retryable = await repo.createJob(imagePath: '/tmp/retryable.png');
    await repo.updateStatus(retryable.id, BillingJobStatus.retryableFailed,
        lastError: 'timeout');
    final succeeded = await repo.createJob(imagePath: '/tmp/succeeded.png');
    await repo.markSucceeded(succeeded.id);

    final result = await repo.findPendingJobs();

    expect(result.length, 2);
    expect(result.map((j) => j.id), containsAll([pending.id, retryable.id]));
    expect(result.every((j) => j.id != succeeded.id), isTrue);
  });

  test('findAwaitingConfirmationJobs restores user confirmation work',
      () async {
    final awaiting = await repo.createJob(imagePath: '/tmp/confirm.png');
    await repo.updateStatus(
      awaiting.id,
      BillingJobStatus.awaitingConfirmation,
    );

    final result = await repo.findAwaitingConfirmationJobs();

    expect(result.map((job) => job.id), contains(awaiting.id));
  });

  test('findPendingJobs excludes succeeded and failed', () async {
    final pending = await repo.createJob(imagePath: '/tmp/pending.png');
    final retryable = await repo.createJob(imagePath: '/tmp/retryable.png');
    await repo.updateStatus(retryable.id, BillingJobStatus.retryableFailed,
        lastError: 'timeout');
    final succeeded = await repo.createJob(imagePath: '/tmp/succeeded.png');
    await repo.markSucceeded(succeeded.id);
    final failed = await repo.createJob(imagePath: '/tmp/failed.png');
    await repo.updateStatus(failed.id, BillingJobStatus.failed,
        lastError: 'auth error');

    final result = await repo.findPendingJobs();

    expect(result.length, 2);
    expect(result.map((j) => j.id), containsAll([pending.id, retryable.id]));
    expect(result.any((j) => j.id == succeeded.id), isFalse);
    expect(result.any((j) => j.id == failed.id), isFalse);
  });

  test(
      'findAttachmentRecoveryJobs returns only committed unfinished attachments',
      () async {
    final recoverable =
        await repo.createJob(imagePath: '/tmp/recover-attachment.png');
    await repo.updateTransactionId(recoverable.id, 51);
    await repo.updateStage(recoverable.id, BillingJobStage.completed);
    await repo.markSucceeded(recoverable.id);

    final alreadyDone = await repo.createJob(imagePath: '/tmp/done.png');
    await repo.updateTransactionId(alreadyDone.id, 52);
    await repo.updateStage(alreadyDone.id, BillingJobStage.completed);
    await repo.markSucceeded(alreadyDone.id);
    await repo.markAttachmentDone(alreadyDone.id);

    final noTransaction = await repo.createJob(imagePath: '/tmp/no-tx.png');
    await repo.updateStage(noTransaction.id, BillingJobStage.completed);
    await repo.markSucceeded(noTransaction.id);

    final result = await repo.findAttachmentRecoveryJobs();

    expect(result.map((job) => job.id), [recoverable.id]);
  });

  test('claimJob sets lease_until and returns true', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');

    final claimed = await repo.claimJob(job.id, Duration(seconds: 60));

    expect(claimed, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.leaseUntil, isNotNull);
  });

  test('claimJob returns false if already leased', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');

    final first = await repo.claimJob(job.id, Duration(seconds: 60));
    expect(first, isTrue);

    final second = await repo.claimJob(job.id, Duration(seconds: 60));
    expect(second, isFalse);
  });

  test('claimJob returns true if lease expired', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');

    // Claim with a negative duration so lease_until is in the past (already expired).
    final first = await repo.claimJob(job.id, Duration(seconds: -1));
    expect(first, isTrue);

    final second = await repo.claimJob(job.id, Duration(seconds: 60));
    expect(second, isTrue);
  });

  test('an expired owner cannot mutate after a later owner claims the job',
      () async {
    final job = await repo.createJob(imagePath: '/tmp/stale-owner.png');
    final stale =
        (await repo.claimJobLease(job.id, const Duration(seconds: -1)))!;
    final current =
        (await repo.claimJobLease(job.id, const Duration(seconds: 30)))!;

    expect(
      await repo.updateTransactionId(job.id, 41, lease: stale),
      isFalse,
    );
    expect(
      await repo.updateTransactionId(job.id, 42, lease: current),
      isTrue,
    );
    expect((await repo.findById(job.id))!.transactionId, 42);
  });

  test('attachment recovery cannot replace an active lease owner', () async {
    final job = await repo.createJob(imagePath: '/tmp/active-attachment.png');
    await repo.updateTransactionId(job.id, 53);
    await repo.updateStage(job.id, BillingJobStage.completed);
    await repo.markSucceeded(job.id);
    final active =
        await repo.claimJobLease(job.id, const Duration(seconds: 30));

    final recovery = await repo.claimAttachmentRecoveryLease(
      job.id,
      const Duration(seconds: 30),
    );

    expect(active, isNotNull);
    expect(recovery, isNull);
    expect(await repo.isLeaseOwner(active!), isTrue);
  });

  test('concurrent billing attachment upserts reuse the source record',
      () async {
    final attachments = LocalAttachmentRepository(db);

    final ids = await Future.wait([
      attachments.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: 'tx_61_9_0.avif',
      ),
      attachments.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: 'tx_61_9_0.avif',
      ),
    ]);

    expect(ids.toSet(), hasLength(1));
    expect(await attachments.getAttachmentsByTransaction(61), hasLength(1));
  });

  test('markSucceeded sets completed_at', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.markSucceeded(job.id);

    final updated = await repo.findById(job.id);
    expect(updated!.status, 'succeeded');
    expect(updated.completedAt, isNotNull);
  });

  test('findByImagePath returns job with matching path', () async {
    const path = '/tmp/dedup.png';
    await repo.createJob(imagePath: path);

    final found = await repo.findByImagePath(path);

    expect(found, isNotNull);
    expect(found!.imagePath, path);
  });

  test('findByImagePath returns null for non-existent path', () async {
    final found = await repo.findByImagePath('/tmp/does_not_exist.png');
    expect(found, isNull);
  });

  test('findByImagePath returns same job on repeated calls (dedup)', () async {
    const path = '/tmp/dedup_repeat.png';
    final created = await repo.createJob(imagePath: path);

    final first = await repo.findByImagePath(path);
    final second = await repo.findByImagePath(path);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.id, created.id);
    expect(second!.id, created.id);
  });

  test('rule_done atomically persists the complete execution snapshot',
      () async {
    final job = await repo.createJob(imagePath: '/tmp/snapshot.png');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);

    final committed = await repo.commitRuleResultSnapshot(
      id: job.id,
      ruleResultJson: '{"amount":12}',
      snapshot: const BillingRuleExecutionSnapshot(
        rulePackageVersion: 12,
        rulesVersion: '2026.07.24.1',
        normalizationVersion: 2,
        personalRulesRevision: 37,
      ),
    );

    final saved = await repo.findById(job.id);
    expect(committed, isTrue);
    expect(saved?.stage, BillingJobStage.ruleDone);
    expect(saved?.ruleResultJson, '{"amount":12}');
    expect(saved?.rulePackageVersion, 12);
    expect(saved?.rulesVersion, '2026.07.24.1');
    expect(saved?.normalizationVersion, 2);
    expect(saved?.personalRulesRevision, 37);
    expect(saved?.ruleSnapshotStatus, 'pinned');
  });

  test('snapshot commit rejects a stale stage CAS', () async {
    final job = await repo.createJob(imagePath: '/tmp/stale-snapshot.png');

    final committed = await repo.commitRuleResultSnapshot(
      id: job.id,
      ruleResultJson: '{}',
      snapshot: const BillingRuleExecutionSnapshot(
        rulePackageVersion: 12,
        rulesVersion: 'rules-2',
        normalizationVersion: 2,
        personalRulesRevision: 37,
      ),
    );

    expect(committed, isFalse);
    expect((await repo.findById(job.id))?.ruleResultJson, isNull);
  });

  test('unavailable pinned snapshot explicitly migrates back to ocr_done',
      () async {
    final job = await repo.createJob(imagePath: '/tmp/migrate-snapshot.png');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);
    await repo.commitRuleResultSnapshot(
      id: job.id,
      ruleResultJson: '{"payment_method":"旧值"}',
      snapshot: const BillingRuleExecutionSnapshot(
        rulePackageVersion: 12,
        rulesVersion: 'rules-2',
        normalizationVersion: 2,
        personalRulesRevision: 37,
      ),
    );

    final migrated = await repo.migrateUnavailableRuleSnapshotToOcrDone(job.id);

    final saved = await repo.findById(job.id);
    expect(migrated, isTrue);
    expect(saved?.stage, BillingJobStage.ocrDone);
    expect(saved?.ruleResultJson, isNull);
    expect(saved?.rulesVersion, isNull);
    expect(saved?.normalizationVersion, isNull);
    expect(saved?.personalRulesRevision, isNull);
    expect(saved?.ruleSnapshotStatus, 'snapshot_migrated');
    expect(saved?.lastError, 'snapshot_migrated');
  });
}
