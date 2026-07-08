import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../billing_job_repository.dart';

class LocalBillingJobRepository implements BillingJobRepository {
  final BeeDatabase db;

  LocalBillingJobRepository(this.db);

  @override
  Future<BillingJob> createJob(
      {required String imagePath, String kind = 'image_share'}) async {
    final id = await db.into(db.billingJobs).insert(
          BillingJobsCompanion.insert(
            imagePath: imagePath,
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
  Future<void> updateStage(int id, String stage) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        stage: d.Value(stage),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateStatus(int id, String status, {String? lastError}) async {
    final job = await findById(id);
    if (job == null) return;
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        status: d.Value(status),
        lastError: d.Value(lastError),
        attemptCount: d.Value(job.attemptCount + 1),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<bool> claimJob(int id, Duration leaseDuration) async {
    final now = DateTime.now();
    final newLease = now.add(leaseDuration);

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

    return updatedCount > 0;
  }

  @override
  Future<void> markAttachmentDone(int id) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        attachmentDone: const d.Value(true),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markSucceeded(int id) async {
    final now = DateTime.now();
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        status: const d.Value('succeeded'),
        completedAt: d.Value(now),
        updatedAt: d.Value(now),
      ),
    );
  }

  @override
  Future<BillingJob?> findByImagePath(String imagePath) async {
    return await (db.select(db.billingJobs)
          ..where((t) => t.imagePath.equals(imagePath)))
        .getSingleOrNull();
  }

  @override
  Future<void> updateRawText(int id, String rawText) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        rawText: d.Value(rawText),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateSourceInfoJson(int id, String sourceInfoJson) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        sourceInfoJson: d.Value(sourceInfoJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateRuleResultJson(int id, String ruleResultJson) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        ruleResultJson: d.Value(ruleResultJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateTransactionId(int id, int transactionId) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        transactionId: d.Value(transactionId),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateFinalResultJson(int id, String finalResultJson) async {
    await (db.update(db.billingJobs)..where((t) => t.id.equals(id))).write(
      BillingJobsCompanion(
        finalResultJson: d.Value(finalResultJson),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }
}
