import '../db.dart';

/// V2 分享图片记账工作流的状态、类型常量与值对象。
///
/// 本文件只声明领域不变量（状态值、任务类型、裁决结果）和与数据库行互通的
/// 不可变值对象，不包含 Repository 行为。状态字符串与 `lib/data/db.dart` 表
/// 的 `withDefault` 值及规格 docs/specs/share-image-billing-workflow-v2.md §4
/// 一致。Repository 接口见 `lib/data/repositories/billing_case_repository.dart`。

// ---------------------------------------------------------------------------
// Billing Case 宏观状态（规格 §4.1）
// ---------------------------------------------------------------------------

/// Billing Case 宏观状态常量。
abstract final class BillingCaseState {
  /// 已可靠接收，尚未开始自动处理。
  static const accepted = 'accepted';
  /// 至少有一个自动任务可运行、运行中或等待重试。
  static const automating = 'automating';
  /// 金额或时间需要用户裁决。
  static const waitingConfirmation = 'waiting_confirmation';
  /// 交易已创建，分类需要用户裁决。
  static const waitingClassification = 'waiting_classification';
  /// 交易已创建且无待处理用户任务。
  static const completed = 'completed';
  /// 用户放弃尚未创建交易的待确认工作。
  static const cancelled = 'cancelled';
  /// 自动重试耗尽或遇到不可恢复错误。
  static const permanentFailure = 'permanent_failure';

  static const _all = {
    accepted,
    automating,
    waitingConfirmation,
    waitingClassification,
    completed,
    cancelled,
    permanentFailure,
  };

  static bool isValid(String value) => _all.contains(value);
}

// ---------------------------------------------------------------------------
// Automation Task（规格 §4.2）
// ---------------------------------------------------------------------------

/// 机器可抢占、可重试的本地工作类型。
abstract final class BillingAutomationKind {
  static const recognizeImage = 'recognize_image';
  static const extractBill = 'extract_bill';
  static const createTransaction = 'create_transaction';
  static const prepareAttachment = 'prepare_attachment';
  static const publishAttachment = 'publish_attachment';
  static const learnPersonalRule = 'learn_personal_rule';
  static const deliverOutbox = 'deliver_outbox';
  static const cleanupArtifacts = 'cleanup_artifacts';
}

/// Automation Task 状态常量。
abstract final class BillingAutomationTaskState {
  static const ready = 'ready';
  static const running = 'running';
  static const retryWait = 'retry_wait';
  static const completed = 'completed';
  static const permanentFailure = 'permanent_failure';
  static const cancelled = 'cancelled';
}

// ---------------------------------------------------------------------------
// User Task（规格 §4.3）
// ---------------------------------------------------------------------------

/// 等待本设备用户裁决的持久工作类型。
abstract final class BillingUserTaskKind {
  /// 从 OCR 证据选择或编辑金额、时间。
  static const confirmBill = 'confirm_bill';
  /// 为已经创建的交易选择分类。
  static const classifyTransaction = 'classify_transaction';
}

/// User Task 状态常量。
abstract final class BillingUserTaskState {
  static const open = 'open';
  static const resolved = 'resolved';
  static const cancelled = 'cancelled';
  static const expired = 'expired';
}

// ---------------------------------------------------------------------------
// Prepared Attachment（规格 §4.4）
// ---------------------------------------------------------------------------

/// Prepared Attachment 状态常量。
abstract final class BillingPreparedAttachmentState {
  static const pending = 'pending';
  static const preparing = 'preparing';
  static const prepared = 'prepared';
  static const publishing = 'publishing';
  static const published = 'published';
  static const retryWait = 'retry_wait';
  static const permanentFailure = 'permanent_failure';
}

// ---------------------------------------------------------------------------
// Outbox 事件类型（规格 §4.5）
// ---------------------------------------------------------------------------

/// Outbox 事件类型常量。
abstract final class BillingOutboxEventType {
  static const billingProcessing = 'billing_processing';
  static const billingCreated = 'billing_created';
  static const confirmationRequired = 'confirmation_required';
  static const classificationRequired = 'classification_required';
  static const billingCompleted = 'billing_completed';
  static const billingFailed = 'billing_failed';
  static const attachmentFailed = 'attachment_failed';
}

/// Outbox 事件投递状态常量。
abstract final class BillingOutboxState {
  static const pending = 'pending';
  static const delivered = 'delivered';
}

// ---------------------------------------------------------------------------
// Case Artifact（规格 §6.6）
// ---------------------------------------------------------------------------

/// 文件级清理记录的种类。
abstract final class BillingArtifactKind {
  static const sourceImage = 'source_image';
  static const prepared = 'prepared';
  static const intermediate = 'intermediate';
}

/// 文件清理记录状态。
abstract final class BillingArtifactState {
  static const active = 'active';
  static const deleted = 'deleted';
}

// ---------------------------------------------------------------------------
// Lease fencing（规格 §6.2 / §8）
// ---------------------------------------------------------------------------

/// Automation Task 的租约 token。每次 claim 增加 generation，所有副作用提交
/// 必须匹配当前 generation 且 lease 未过期。lease 丢失表示并发资格失效，不计入
/// 业务失败次数。见规格 §6.2 与 `runFencedPublication`。
class BillingAutomationLease {
  /// 持有 lease 的 Automation Task id。
  final int taskId;

  /// claim 时写入的不可变 lease 截止时间，作为 CAS 版本。
  final DateTime leaseUntil;

  /// claim 时分配的 owner 标识。
  final String leaseOwner;

  /// claim 时增加的 generation；旧 owner 携带过期 generation 永远提交失败。
  final int leaseGeneration;

  const BillingAutomationLease({
    required this.taskId,
    required this.leaseUntil,
    required this.leaseOwner,
    required this.leaseGeneration,
  });

  @override
  String toString() =>
      'BillingAutomationLease(taskId=$taskId, generation=$leaseGeneration, '
      'owner=$leaseOwner, until=$leaseUntil)';
}

/// 提交副作用时租约已丢失或已过期。
class BillingAutomationLeaseLost implements Exception {
  final BillingAutomationLease lease;

  const BillingAutomationLeaseLost(this.lease);

  @override
  String toString() =>
      'BillingAutomationLeaseLost(taskId=${lease.taskId}, '
      'generation=${lease.leaseGeneration})';
}

// ---------------------------------------------------------------------------
// 与数据库行互通的不可变值对象
// ---------------------------------------------------------------------------

/// Billing Case 的领域快照，用于工作流事务内传递与测试断言。
class BillingCaseSummary {
  final int id;
  final String requestId;
  final int? ledgerId;
  final String sourceImagePath;
  final String state;
  final int version;
  final int? transactionId;
  final bool syncAllowed;
  final DateTime? evidencePurgeAfter;
  final DateTime? workflowDeleteAfter;
  final DateTime createdAt;
  final DateTime? completedAt;

  const BillingCaseSummary({
    required this.id,
    required this.requestId,
    required this.ledgerId,
    required this.sourceImagePath,
    required this.state,
    required this.version,
    required this.transactionId,
    required this.syncAllowed,
    required this.evidencePurgeAfter,
    required this.workflowDeleteAfter,
    required this.createdAt,
    required this.completedAt,
  });

  factory BillingCaseSummary.fromRow(BillingCase row) {
    return BillingCaseSummary(
      id: row.id,
      requestId: row.requestId,
      ledgerId: row.ledgerId,
      sourceImagePath: row.sourceImagePath,
      state: row.state,
      version: row.version,
      transactionId: row.transactionId,
      syncAllowed: row.syncAllowed,
      evidencePurgeAfter: row.evidencePurgeAfter,
      workflowDeleteAfter: row.workflowDeleteAfter,
      createdAt: row.createdAt,
      completedAt: row.completedAt,
    );
  }
}
