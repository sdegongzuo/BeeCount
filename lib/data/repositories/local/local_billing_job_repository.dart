import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../billing_job_repository.dart';

class LocalBillingJobRepository implements BillingJobRepository {
  final BeeDatabase db;

  LocalBillingJobRepository(this.db);

  @override
  Future<BillingJob> createJob({
    required String imagePath,
    int? ledgerId,
    String kind = 'image_share',
  }) async {
    final id = await db.into(db.billingJobs).insert(
          BillingJobsCompanion.insert(
            imagePath: imagePath,
            ledgerId: d.Value(ledgerId),
            kind: d.Value(kind),
          ),
        );
    return (await findById(id))!;
  }

  @override
  Future<BillingJob?> findById(int id) async {
    return await (db.select(db.billingJobs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<BillingJob>> findPendingJobs() async {
    return await (db.select(db.billingJobs)
          ..where((t) =>
              t.status.equals('pending') | t.status.equals('retryable_failed')))
        .get();
  }

  @override
  Future<List<BillingJob>> findAttachmentRecoveryJobs() async {
    final now = DateTime.now();
    return (db.select(db.billingJobs)
          ..where((t) =>
              t.transactionId.isNotNull() &
              t.attachmentDone.equals(false) &
              (t.status.equals(BillingJobStatus.succeeded) |
                  t.stage.equals(BillingJobStage.completed)) &
              (t.leaseUntil.isNull() |
                  t.leaseUntil.isSmallerOrEqualValue(now))))
        .get();
  }

  @override
  Future<List<BillingJob>> findAwaitingConfirmationJobs() async {
    return (db.select(db.billingJobs)
          ..where((t) => t.status.equals(BillingJobStatus.awaitingConfirmation))
          ..orderBy([(t) => d.OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  @override
  Future<bool> updateStage(int id, String stage,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        stage: d.Value(stage),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> updateStatus(
    int id,
    String status, {
    String? lastError,
    BillingJobLease? lease,
    bool releaseLease = false,
  }) async {
    final job = await findById(id);
    if (job == null) return false;
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        status: d.Value(status),
        lastError: d.Value(lastError),
        attemptCount: d.Value(job.attemptCount + 1),
        leaseUntil: releaseLease ? const d.Value(null) : const d.Value.absent(),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> claimJob(int id, Duration leaseDuration) async {
    return await claimJobLease(id, leaseDuration) != null;
  }

  @override
  Future<BillingJobLease?> claimJobLease(int id, Duration leaseDuration) async {
    final now = DateTime.now();
    // Drift's default SQLite DateTime representation has second precision.
    // Use the exact persisted precision as the CAS version returned to callers.
    final requestedLease = now.add(leaseDuration);
    final newLease = DateTime.fromMillisecondsSinceEpoch(
      ((requestedLease.millisecondsSinceEpoch + 999) ~/ 1000) * 1000,
    );

    // 原子抢占：单条 UPDATE + WHERE 条件，只有 leaseUntil 为 null 或已过期才能成功
    final updatedCount = await (db.update(db.billingJobs)
          ..where((t) =>
              t.id.equals(id) &
              (t.leaseUntil.isNull() |
                  t.leaseUntil.isSmallerOrEqualValue(now))))
        .write(BillingJobsCompanion(
      leaseUntil: d.Value(newLease),
      updatedAt: d.Value(now),
    ));

    return updatedCount > 0
        ? BillingJobLease(jobId: id, leaseUntil: newLease)
        : null;
  }

  @override
  Future<BillingJobLease?> claimAttachmentRecoveryLease(
    int id,
    Duration leaseDuration,
  ) async {
    final now = DateTime.now();
    final newLease = _persistedLeaseDeadline(now, leaseDuration);
    // 该入口只在应用启动时恢复已完成主链但附件未完成的任务。
    // 仅无 owner 或 lease 已过期时抢占，避免与仍活跃的附件写入并行。
    final updatedCount = await (db.update(db.billingJobs)
          ..where((t) =>
              t.id.equals(id) &
              t.transactionId.isNotNull() &
              t.attachmentDone.equals(false) &
              (t.status.equals(BillingJobStatus.succeeded) |
                  t.stage.equals(BillingJobStage.completed)) &
              (t.leaseUntil.isNull() |
                  t.leaseUntil.isSmallerOrEqualValue(now))))
        .write(BillingJobsCompanion(
      leaseUntil: d.Value(newLease),
      updatedAt: d.Value(now),
    ));
    return updatedCount > 0
        ? BillingJobLease(jobId: id, leaseUntil: newLease)
        : null;
  }

  @override
  Future<bool> isLeaseOwner(BillingJobLease lease) async {
    final job = await findById(lease.jobId);
    final stored = job?.leaseUntil;
    return stored != null &&
        stored.isAtSameMomentAs(lease.leaseUntil) &&
        stored.isAfter(DateTime.now());
  }

  @override
  Future<T> runFencedPublication<T>(
    BillingJobLease lease,
    Future<T> Function() action,
  ) {
    return db.transaction(() async {
      // This must remain the transaction's first statement. Match only the
      // immutable token here: binding a clock value before this UPDATE waits
      // for SQLite's write lock would leave a stale view of lease expiry.
      final tokenMatched = await db.customUpdate(
        '''
UPDATE billing_jobs
SET updated_at = updated_at
WHERE id = ?
  AND lease_until = ?
''',
        variables: [
          d.Variable<int>(lease.jobId),
          d.Variable<DateTime>(lease.leaseUntil),
        ],
        updates: {db.billingJobs},
      );
      if (tokenMatched == 0) throw BillingJobLeaseLost(lease);

      // The first UPDATE has now returned while this transaction owns the
      // write lock. Capture a fresh clock value only here, then fence expiry
      // before allowing the publication action to replace a stable file.
      final stillCurrent = await db.customUpdate(
        '''
UPDATE billing_jobs
SET updated_at = updated_at
WHERE id = ?
  AND lease_until = ?
  AND lease_until > ?
''',
        variables: [
          d.Variable<int>(lease.jobId),
          d.Variable<DateTime>(lease.leaseUntil),
          d.Variable<DateTime>(DateTime.now()),
        ],
        updates: {db.billingJobs},
      );
      if (stillCurrent == 0) throw BillingJobLeaseLost(lease);
      return action();
    });
  }

  @override
  Future<bool> markAttachmentDone(int id, {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        attachmentDone: const d.Value(true),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> markSucceeded(int id, {BillingJobLease? lease}) async {
    final now = DateTime.now();
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        status: const d.Value('succeeded'),
        completedAt: d.Value(now),
        updatedAt: d.Value(now),
      ),
    );
    return updated > 0;
  }

  @override
  Future<BillingJob?> findByImagePath(String imagePath) async {
    return await (db.select(db.billingJobs)
          ..where((t) => t.imagePath.equals(imagePath))
          ..orderBy([(t) => d.OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<bool> updateRawText(int id, String rawText,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        rawText: d.Value(rawText),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> updateSourceInfoJson(int id, String sourceInfoJson,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        sourceInfoJson: d.Value(sourceInfoJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> updateRuleResultJson(int id, String ruleResultJson,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        ruleResultJson: d.Value(ruleResultJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> updateTransactionId(int id, int transactionId,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        transactionId: d.Value(transactionId),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> updateFinalResultJson(int id, String finalResultJson,
      {BillingJobLease? lease}) async {
    final updated = await (db.update(db.billingJobs)
          ..where((t) => _canMutate(t, id, lease)))
        .write(
      BillingJobsCompanion(
        finalResultJson: d.Value(finalResultJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  d.Expression<bool> _canMutate(
    BillingJobs table,
    int id,
    BillingJobLease? lease,
  ) {
    final byId = table.id.equals(id);
    if (lease == null) return byId;
    if (lease.jobId != id) return const d.Constant(false);
    return byId &
        table.leaseUntil.equals(lease.leaseUntil) &
        table.leaseUntil.isBiggerThanValue(DateTime.now());
  }
}

DateTime _persistedLeaseDeadline(DateTime now, Duration leaseDuration) {
  final requestedLease = now.add(leaseDuration);
  return DateTime.fromMillisecondsSinceEpoch(
    ((requestedLease.millisecondsSinceEpoch + 999) ~/ 1000) * 1000,
  );
}
