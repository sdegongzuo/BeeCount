import '../db.dart';
import '../models/billing_case.dart';

/// V2 分享图片记账工作流的持久化 Repository 接口。
///
/// 本接口是顶层工作流（BillingIngress / BillingAutomation / BillingUserWork /
/// BillingArtifactLifecycle）与 SQLite 之间的 seam。调用方通过它创建 Case、
/// 任务和 Outbox，无需了解 SQL 顺序；领域不变量放在数据库约束和 Repository
/// 行为里，而不是依赖页面或调用顺序。
///
/// 见 docs/specs/share-image-billing-workflow-v2.md §6 / §7。
abstract class BillingCaseRepository {
  // --- Billing Case ---

  /// 按 [requestId] 原子 get-or-create Billing Case。
  ///
  /// 重复 requestId 返回同一个 Case。返回值包含 id 与当前状态；调用方据此
  /// 决定是否创建初始任务。见规格 §21.1 核心不变量 1。
  Future<BillingCase> getOrCreateCaseByRequestId({
    required String requestId,
    required String sourceImagePath,
    int? ledgerId,
    String? sourceInfoJson,
    Future<void> Function(int caseId)? onCreate,
  });

  Future<BillingCase?> findCaseById(int id);

  Future<BillingCase?> findCaseByRequestId(String requestId);

  Future<BillingCase?> findCaseByTransactionId(int transactionId);

  /// 更新 Case 状态。仅当当前 version 匹配 [expectedVersion] 时成功，用于
  /// 防止并发写入覆盖。返回是否更新成功。
  Future<bool> updateCaseState(
    int id, {
    required String state,
    required int expectedVersion,
    int? transactionId,
    bool? syncAllowed,
  });

  // --- Automation Task ---

  /// 插入 Automation Task，若同 Case 同类型已存在则忽略。
  /// 依赖 `(case_id, kind)` 唯一约束保证同一 Case 同一任务类型不重复。
  Future<bool> insertAutomationTaskIfAbsent({
    required int caseId,
    required String kind,
    String state = BillingAutomationTaskState.ready,
  });

  Future<BillingAutomationTask?> findAutomationTask(int id);

  Future<List<BillingAutomationTask>> findAutomationTasksByCase(int caseId);

  /// 抢占一个 ready 或到期 running / 到时 retry_wait 的任务。
  ///
  /// 每次 claim 增加 lease_generation 并写入 owner、leaseUntil。返回租约
  /// token；返回 null 表示无任务可抢占或竞争失败。见规格 §6.2 / §9。
  Future<BillingAutomationLease?> claimAutomationTask({
    required String workerIdentity,
    required Duration leaseDuration,
    String? kindFilter,
  });

  /// 在已 claim 的任务上下文内执行 fenced 副作用。
  ///
  /// 校验当前 lease_generation 与 lease 未过期后才执行 [action]；过期则抛
  /// [BillingAutomationLeaseLost]。所有副作用提交必须经过此入口。
  Future<T> runFenced<T>(
    BillingAutomationLease lease,
    Future<T> Function() action,
  );

  /// 标记任务完成。必须在 fenced 事务内调用。
  Future<bool> completeAutomationTask(int id);

  /// 标记任务进入重试等待或永久失败。
  Future<bool> failAutomationTask(
    int id, {
    required String errorCode,
    required bool permanent,
  });

  // --- User Task ---

  /// 创建 User Task，若同 Case 同类型已存在则忽略。
  Future<bool> insertUserTaskIfAbsent({
    required int caseId,
    required String kind,
    int? transactionId,
    String? draftJson,
  });

  Future<BillingUserTask?> findUserTask(int id);

  Future<List<BillingUserTask>> findOpenUserTasks();

  Future<List<BillingUserTask>> findOpenUserTasksByCase(int caseId);

  /// 以 open + version 为条件解决 User Task。
  ///
  /// 乐观并发控制：重复提交不会产生第二次业务动作。返回是否更新成功。
  Future<bool> resolveUserTask(
    int id, {
    required int expectedVersion,
    String? resolutionJson,
    int? transactionId,
  });

  /// 以 open + version 为条件取消 User Task。
  Future<bool> cancelUserTask(
    int id, {
    required int expectedVersion,
  });

  // --- Outbox ---

  /// 插入 Outbox 事件，业务状态已提交、等待本地外部交付。
  Future<int> insertOutboxEvent({
    required int caseId,
    required String eventType,
    int? userTaskId,
    String? payloadJson,
  });

  Future<List<BillingOutboxData>> findPendingOutboxEvents();

  /// 标记 Outbox 事件已交付。
  Future<bool> markOutboxDelivered(int id);

  // --- 事务 ---

  /// 在单个短 SQLite 事务内执行 [action]。
  Future<T> transaction<T>(Future<T> Function() action);
}
