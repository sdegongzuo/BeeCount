import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../../models/billing_case.dart';
import '../billing_case_repository.dart';

class LocalBillingCaseRepository implements BillingCaseRepository {
  final BeeDatabase db;

  LocalBillingCaseRepository(this.db);

  // --- Billing Case ---

  @override
  Future<BillingCase> getOrCreateCaseByRequestId({
    required String requestId,
    required String sourceImagePath,
    int? ledgerId,
    String? sourceInfoJson,
    Future<void> Function(int caseId)? onCreate,
  }) async {
    return db.transaction(() async {
      // 先查是否已存在同 requestId 的 Case。
      final existing = await (db.select(db.billingCases)
            ..where((t) => t.requestId.equals(requestId)))
          .getSingleOrNull();
      if (existing != null) {
        return existing;
      }
      final id = await db.into(db.billingCases).insert(
            BillingCasesCompanion.insert(
              requestId: requestId,
              sourceImagePath: sourceImagePath,
              ledgerId: d.Value(ledgerId),
              sourceInfoJson: d.Value(sourceInfoJson),
            ),
          );
      if (onCreate != null) {
        await onCreate(id);
      }
      return (await (db.select(db.billingCases)
                ..where((t) => t.id.equals(id)))
              .getSingle());
    });
  }

  @override
  Future<BillingCase?> findCaseById(int id) async {
    return await (db.select(db.billingCases)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<BillingCase?> findCaseByRequestId(String requestId) async {
    return await (db.select(db.billingCases)
          ..where((t) => t.requestId.equals(requestId)))
        .getSingleOrNull();
  }

  @override
  Future<BillingCase?> findCaseByTransactionId(int transactionId) async {
    return await (db.select(db.billingCases)
          ..where((t) => t.transactionId.equals(transactionId)))
        .getSingleOrNull();
  }

  @override
  Future<bool> updateCaseState(
    int id, {
    required String state,
    required int expectedVersion,
    int? transactionId,
    bool? syncAllowed,
  }) async {
    final now = DateTime.now();
    final updated = await (db.update(db.billingCases)
          ..where((t) =>
              t.id.equals(id) & t.version.equals(expectedVersion)))
        .write(BillingCasesCompanion(
      state: d.Value(state),
      transactionId: transactionId != null
          ? d.Value(transactionId)
          : const d.Value.absent(),
      syncAllowed: syncAllowed != null
          ? d.Value(syncAllowed)
          : const d.Value.absent(),
      version: d.Value(expectedVersion + 1),
      updatedAt: d.Value(now),
      completedAt: d.Value(_completedAtFor(state, now)),
    ));
    return updated > 0;
  }

  DateTime? _completedAtFor(String state, DateTime now) {
    switch (state) {
      case BillingCaseState.completed:
      case BillingCaseState.cancelled:
      case BillingCaseState.permanentFailure:
        return now;
      default:
        return null;
    }
  }

  // --- Automation Task ---

  @override
  Future<bool> insertAutomationTaskIfAbsent({
    required int caseId,
    required String kind,
    String state = BillingAutomationTaskState.ready,
  }) async {
    // 依赖 `(case_id, kind)` 唯一约束：插入已存在的组合会抛异常，这里捕获后
    // 视为已存在返回 false，保证同一 Case 同一任务类型不重复。
    try {
      await db.into(db.billingAutomationTasks).insert(
            BillingAutomationTasksCompanion.insert(
              caseId: caseId,
              kind: kind,
              state: d.Value(state),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BillingAutomationTask?> findAutomationTask(int id) async {
    return await (db.select(db.billingAutomationTasks)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<BillingAutomationTask>> findAutomationTasksByCase(
      int caseId) async {
    return await (db.select(db.billingAutomationTasks)
          ..where((t) => t.caseId.equals(caseId)))
        .get();
  }

  @override
  Future<BillingAutomationLease?> claimAutomationTask({
    required String workerIdentity,
    required Duration leaseDuration,
    String? kindFilter,
  }) async {
    final now = DateTime.now();
    // Drift 默认 SQLite DateTime 为秒精度；与旧 Billing Job lease 保持一致。
    final newLease = _persistedDeadline(now, leaseDuration);

    return db.transaction(() async {
      // 查找一个可抢占的任务：ready，或 running 但 lease 已过期，或 retry_wait
      // 且到时。按可用时间排序，可选按 kind 过滤。
      final query = db.select(db.billingAutomationTasks)
        ..where((t) =>
            t.state.equals(BillingAutomationTaskState.ready) |
            (t.state.equals(BillingAutomationTaskState.running) &
                (t.leaseUntil.isNull() |
                    t.leaseUntil.isSmallerOrEqualValue(now))) |
            (t.state.equals(BillingAutomationTaskState.retryWait) &
                t.availableAt.isSmallerOrEqualValue(now)))
        ..orderBy([
          (t) => d.OrderingTerm.asc(t.availableAt),
          (t) => d.OrderingTerm.asc(t.id)
        ])
        ..limit(1);
      if (kindFilter != null) {
        query.where((t) => t.kind.equals(kindFilter));
      }
      final candidate = await query.getSingleOrNull();
      if (candidate == null) return null;

      // 每次 claim 增加 generation。仅当任务未被并发改动时成功。
      final newGeneration = candidate.leaseGeneration + 1;
      final updated = await (db.update(db.billingAutomationTasks)
            ..where((t) =>
                t.id.equals(candidate.id) &
                t.leaseGeneration.equals(candidate.leaseGeneration)))
          .write(BillingAutomationTasksCompanion(
        state: const d.Value(BillingAutomationTaskState.running),
        leaseOwner: d.Value(workerIdentity),
        leaseGeneration: d.Value(newGeneration),
        leaseUntil: d.Value(newLease),
        availableAt: d.Value(now),
        updatedAt: d.Value(now),
      ));
      if (updated == 0) return null;
      return BillingAutomationLease(
        taskId: candidate.id,
        leaseUntil: newLease,
        leaseOwner: workerIdentity,
        leaseGeneration: newGeneration,
      );
    });
  }

  @override
  Future<T> runFenced<T>(
    BillingAutomationLease lease,
    Future<T> Function() action,
  ) {
    return db.transaction(() async {
      // 先校验 generation 匹配且 lease 未过期。旧 owner 携带过期 generation
      // 永远提交失败。见规格 §6.2 / §21.1 不变量 3。
      final stillCurrent = await (db.update(db.billingAutomationTasks)
            ..where((t) =>
                t.id.equals(lease.taskId) &
                t.leaseGeneration.equals(lease.leaseGeneration) &
                t.leaseUntil.isBiggerThanValue(DateTime.now())))
          .write(BillingAutomationTasksCompanion(
        updatedAt: d.Value(DateTime.now()),
      ));
      if (stillCurrent == 0) {
        throw BillingAutomationLeaseLost(lease);
      }
      return action();
    });
  }

  @override
  Future<bool> completeAutomationTask(int id) async {
    final now = DateTime.now();
    final updated = await (db.update(db.billingAutomationTasks)
          ..where((t) => t.id.equals(id)))
        .write(BillingAutomationTasksCompanion(
      state: const d.Value(BillingAutomationTaskState.completed),
      leaseOwner: const d.Value(null),
      leaseUntil: const d.Value(null),
      updatedAt: d.Value(now),
    ));
    return updated > 0;
  }

  @override
  Future<bool> failAutomationTask(
    int id, {
    required String errorCode,
    required bool permanent,
  }) async {
    final now = DateTime.now();
    final task = await findAutomationTask(id);
    if (task == null) return false;
    final updated = await (db.update(db.billingAutomationTasks)
          ..where((t) => t.id.equals(id)))
        .write(BillingAutomationTasksCompanion(
      state: d.Value(permanent
          ? BillingAutomationTaskState.permanentFailure
          : BillingAutomationTaskState.retryWait),
      attempt: d.Value(task.attempt + 1),
      lastErrorCode: d.Value(errorCode),
      leaseOwner: const d.Value(null),
      leaseUntil: const d.Value(null),
      updatedAt: d.Value(now),
    ));
    return updated > 0;
  }

  // --- User Task ---

  @override
  Future<bool> insertUserTaskIfAbsent({
    required int caseId,
    required String kind,
    int? transactionId,
    String? draftJson,
  }) async {
    try {
      await db.into(db.billingUserTasks).insert(
            BillingUserTasksCompanion.insert(
              caseId: caseId,
              kind: kind,
              transactionId: d.Value(transactionId),
              draftJson: d.Value(draftJson),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BillingUserTask?> findUserTask(int id) async {
    return await (db.select(db.billingUserTasks)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<BillingUserTask>> findOpenUserTasks() async {
    return await (db.select(db.billingUserTasks)
          ..where((t) => t.state.equals(BillingUserTaskState.open))
          ..orderBy([(t) => d.OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  @override
  Future<List<BillingUserTask>> findOpenUserTasksByCase(int caseId) async {
    return await (db.select(db.billingUserTasks)
          ..where((t) =>
              t.caseId.equals(caseId) &
              t.state.equals(BillingUserTaskState.open)))
        .get();
  }

  @override
  Future<bool> resolveUserTask(
    int id, {
    required int expectedVersion,
    String? resolutionJson,
    int? transactionId,
  }) async {
    final now = DateTime.now();
    // 乐观并发：只有 state=open 且 version 匹配才能成功。
    final updated = await (db.update(db.billingUserTasks)
          ..where((t) =>
              t.id.equals(id) &
              t.state.equals(BillingUserTaskState.open) &
              t.version.equals(expectedVersion)))
        .write(BillingUserTasksCompanion(
      state: const d.Value(BillingUserTaskState.resolved),
      resolutionJson: d.Value(resolutionJson),
      transactionId: transactionId != null
          ? d.Value(transactionId)
          : const d.Value.absent(),
      version: d.Value(expectedVersion + 1),
      resolvedAt: d.Value(now),
    ));
    return updated > 0;
  }

  @override
  Future<bool> cancelUserTask(
    int id, {
    required int expectedVersion,
  }) async {
    final now = DateTime.now();
    final updated = await (db.update(db.billingUserTasks)
          ..where((t) =>
              t.id.equals(id) &
              t.state.equals(BillingUserTaskState.open) &
              t.version.equals(expectedVersion)))
        .write(BillingUserTasksCompanion(
      state: const d.Value(BillingUserTaskState.cancelled),
      version: d.Value(expectedVersion + 1),
      resolvedAt: d.Value(now),
    ));
    return updated > 0;
  }

  // --- Outbox ---

  @override
  Future<int> insertOutboxEvent({
    required int caseId,
    required String eventType,
    int? userTaskId,
    String? payloadJson,
  }) async {
    return db.into(db.billingOutbox).insert(
          BillingOutboxCompanion.insert(
            caseId: caseId,
            eventType: eventType,
            userTaskId: d.Value(userTaskId),
            payloadJson: d.Value(payloadJson),
          ),
        );
  }

  @override
  Future<List<BillingOutboxData>> findPendingOutboxEvents() async {
    return await (db.select(db.billingOutbox)
          ..where((t) => t.state.equals(BillingOutboxState.pending))
          ..orderBy([(t) => d.OrderingTerm.asc(t.availableAt)]))
        .get();
  }

  @override
  Future<bool> markOutboxDelivered(int id) async {
    final updated = await (db.update(db.billingOutbox)
          ..where((t) => t.id.equals(id)))
        .write(BillingOutboxCompanion(
      state: const d.Value(BillingOutboxState.delivered),
      deliveredAt: d.Value(DateTime.now()),
    ));
    return updated > 0;
  }

  // --- 事务 ---

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    return db.transaction(action);
  }
}

DateTime _persistedDeadline(DateTime now, Duration leaseDuration) {
  final requested = now.add(leaseDuration);
  return DateTime.fromMillisecondsSinceEpoch(
    ((requested.millisecondsSinceEpoch + 999) ~/ 1000) * 1000,
  );
}
