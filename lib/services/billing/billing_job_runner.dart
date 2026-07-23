import 'dart:async';

import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import '../platform/screenshot_source_info.dart';

typedef BillingJobStatusReporter = FutureOr<void> Function(String status);

class BillingJobExecutionCancelled implements Exception {
  final Object? cause;
  const BillingJobExecutionCancelled([this.cause]);

  @override
  String toString() =>
      'BillingJobExecutionCancelled${cause == null ? '' : ': $cause'}';
}

/// 阶段间传递的上下文，用于在 stage 之间共享数据。
/// 避免重复调用 OCR 等昂贵操作，并解决 job 快照过期问题。
class PipelineContext {
  /// OCR 阶段输出的原始文本。
  String? rawText;

  /// OCR 阶段输出的完整结果（包含金额、备注、时间、支付通道等）。
  Map<String, dynamic>? ocrFields;

  /// 交易创建阶段写入的交易 ID。
  /// AI 和附件阶段可从此处获取，无需等待 job 刷新。
  int? transactionId;
  final Completer<int> _transactionIdCompleter = Completer<int>();
  bool _transactionIdFutureRequested = false;

  /// 分享来源信息，供 OCR/规则阶段保留 app 来源和支付通道证据。
  ScreenshotSourceInfo? sourceInfo;

  /// 应用启动恢复时一次性建立的附件文件名索引。
  Set<String>? attachmentRecoveryFileNames;

  void Function()? _ensureDeliveryOwned;
  BillingJobRepository? _leaseRepository;
  BillingJobLease? _lease;

  PipelineContext({void Function()? ensureDeliveryOwned})
      : _ensureDeliveryOwned = ensureDeliveryOwned;

  BillingJobLease? get lease => _lease;

  void configureOwnership({
    required BillingJobRepository repository,
    required BillingJobLease lease,
    void Function()? ensureDeliveryOwned,
  }) {
    _leaseRepository = repository;
    _lease = lease;
    if (ensureDeliveryOwned != null) {
      _ensureDeliveryOwned = ensureDeliveryOwned;
    }
  }

  void ensureCanStartSideEffect() {
    try {
      _ensureDeliveryOwned?.call();
    } catch (error) {
      throw BillingJobExecutionCancelled(error);
    }
  }

  Future<void> ensureJobOwned() async {
    final repository = _leaseRepository;
    final currentLease = _lease;
    if (repository != null &&
        currentLease != null &&
        !await repository.isLeaseOwner(currentLease)) {
      throw const BillingJobExecutionCancelled('billing_job_lease_lost');
    }
  }

  Future<void> requireOwnedWrite(
    Future<bool> Function(BillingJobLease? lease) write,
  ) async {
    await ensureJobOwned();
    if (!await write(_lease)) {
      throw const BillingJobExecutionCancelled('billing_job_cas_rejected');
    }
  }

  Future<int> get transactionIdFuture {
    _transactionIdFutureRequested = true;
    return _transactionIdCompleter.future;
  }

  void completeTransactionId(int id) {
    transactionId = id;
    if (!_transactionIdCompleter.isCompleted) {
      _transactionIdCompleter.complete(id);
    }
  }

  void failTransactionId(Object? error) {
    if (_transactionIdFutureRequested && !_transactionIdCompleter.isCompleted) {
      _transactionIdCompleter.completeError(
        error ?? StateError('transaction_not_created'),
      );
    }
  }
}

abstract class StageProcessor {
  String get stageName;
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx);
}

abstract class AttachmentRecoveryProcessor {
  Future<Set<String>> indexRecoveryFiles();
}

class StageResult {
  final bool success;
  final bool retryable;
  final bool awaitingConfirmation;
  final String? error;

  const StageResult.success()
      : success = true,
        retryable = false,
        awaitingConfirmation = false,
        error = null;
  const StageResult.awaitingConfirmation()
      : success = false,
        retryable = false,
        awaitingConfirmation = true,
        error = null;
  const StageResult.failure(this.error, {this.retryable = false})
      : success = false,
        awaitingConfirmation = false;
}

class BillingJobRunner {
  final BillingJobRepository repo;
  final StageProcessor ocrProcessor;
  final StageProcessor ruleProcessor;
  final StageProcessor txProcessor;
  final StageProcessor aiProcessor;
  final StageProcessor? attachmentProcessor;
  final BillingJobStatusReporter? statusReporter;

  BillingJobRunner({
    required this.repo,
    required this.ocrProcessor,
    required this.ruleProcessor,
    required this.txProcessor,
    required this.aiProcessor,
    this.attachmentProcessor,
    this.statusReporter,
  });

  Future<bool> runJob(
    BillingJob job,
    DateTime deadline, {
    PipelineContext? initialContext,
  }) async {
    initialContext?.ensureCanStartSideEffect();
    final remaining = deadline.difference(DateTime.now());
    final lease = await repo.claimJobLease(
      job.id,
      remaining.isNegative ? const Duration(seconds: 1) : remaining,
    );
    if (lease == null) return false;

    final ctx = initialContext ?? PipelineContext();
    ctx.configureOwnership(
      repository: repo,
      lease: lease,
      ensureDeliveryOwned: ctx._ensureDeliveryOwned,
    );
    try {
      ctx.ensureCanStartSideEffect();
      await _reportStatus('已接收图片，准备识别账单');
      await _dispatchAttachment(job, deadline, ctx);
      await _runProcessors(job, deadline,
          [ocrProcessor, ruleProcessor, txProcessor, aiProcessor], ctx);

      // 附件在主流程完成后启动（此时 transactionId 已在 ctx 中）
      final current = await repo.findById(job.id);
      if (current == null) return true;
      if (current.status != BillingJobStatus.failed &&
          current.status != BillingJobStatus.retryableFailed &&
          current.status != BillingJobStatus.awaitingConfirmation) {
        await _completeJob(job.id, ctx);
      }
    } on BillingJobExecutionCancelled catch (error) {
      ctx.failTransactionId(error);
    }
    return true;
  }

  Future<bool> resumeJob(
    BillingJob job,
    DateTime deadline, {
    PipelineContext? initialContext,
  }) async {
    initialContext?.ensureCanStartSideEffect();
    final remaining = deadline.difference(DateTime.now());
    final lease = await repo.claimJobLease(
      job.id,
      remaining.isNegative ? const Duration(seconds: 1) : remaining,
    );
    if (lease == null) return false;

    final ctx = initialContext ?? PipelineContext();
    ctx.configureOwnership(
      repository: repo,
      lease: lease,
      ensureDeliveryOwned: ctx._ensureDeliveryOwned,
    );
    try {
      ctx.ensureCanStartSideEffect();
      await _reportStatus('正在恢复未完成的账单识别');
      // 恢复时，从已有 stage 之前的数据重建 ctx
      ctx.rawText = job.rawText;
      ctx.transactionId = job.transactionId;
      if (job.transactionId != null) {
        ctx.completeTransactionId(job.transactionId!);
      }
      await _dispatchAttachment(job, deadline, ctx);

      final allProcessors = [
        ocrProcessor,
        ruleProcessor,
        txProcessor,
        aiProcessor
      ];
      final startIndex = _startIndexForStage(job.stage);
      final processors = allProcessors.sublist(startIndex);
      await _runProcessors(job, deadline, processors, ctx);

      // 附件在主流程完成后启动
      final current = await repo.findById(job.id);
      if (current == null) return true;

      if (current.status == BillingJobStatus.retryableFailed) {
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStatus(
            current.id,
            BillingJobStatus.pending,
            lease: lease,
          ),
        );
        final refreshed = await repo.findById(job.id);
        if (refreshed == null) return true;
        await _completeJob(job.id, ctx);
        return true;
      }

      if (current.status != BillingJobStatus.failed &&
          current.status != BillingJobStatus.awaitingConfirmation) {
        await _completeJob(job.id, ctx);
      }
    } on BillingJobExecutionCancelled catch (error) {
      ctx.failTransactionId(error);
    }
    return true;
  }

  /// 仅恢复已创建交易但尚未完成的附件，不重复执行 OCR、规则或交易创建。
  Future<bool> resumeAttachment(
    BillingJob job,
    DateTime deadline,
    Set<String>? recoveryFileNames,
  ) async {
    if (attachmentProcessor == null || job.transactionId == null) return false;
    final remaining = deadline.difference(DateTime.now());
    final lease = await repo.claimAttachmentRecoveryLease(
      job.id,
      remaining.isNegative ? const Duration(seconds: 1) : remaining,
    );
    if (lease == null) return false;

    final ctx = PipelineContext()
      ..configureOwnership(repository: repo, lease: lease)
      ..attachmentRecoveryFileNames = recoveryFileNames
      ..completeTransactionId(job.transactionId!);
    try {
      await _dispatchAttachment(job, deadline, ctx);
    } on BillingJobExecutionCancelled catch (error) {
      ctx.failTransactionId(error);
    }
    return true;
  }

  Future<Set<String>> indexAttachmentRecoveryFiles() async {
    final processor = attachmentProcessor;
    if (processor is AttachmentRecoveryProcessor) {
      return (processor as AttachmentRecoveryProcessor).indexRecoveryFiles();
    }
    return const {};
  }

  Future<void> _completeJob(int jobId, PipelineContext ctx) async {
    await ctx.requireOwnedWrite(
      (lease) => repo.updateStage(
        jobId,
        BillingJobStage.completed,
        lease: lease,
      ),
    );
    ctx.ensureCanStartSideEffect();
    await _reportStatus('账单识别完成，正在收尾');
    await ctx.requireOwnedWrite(
      (lease) => repo.markSucceeded(jobId, lease: lease),
    );
  }

  Future<void> _dispatchAttachment(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    if (attachmentProcessor == null) return;
    ctx.ensureCanStartSideEffect();
    await ctx.ensureJobOwned();
    final freshJob = await repo.findById(job.id);
    if (freshJob == null || freshJob.attachmentDone) return;
    await _reportStatus('正在保存账单图片');
    await attachmentProcessor!.process(freshJob, deadline, ctx);
  }

  int _startIndexForStage(String stage) {
    switch (stage) {
      case BillingJobStage.received:
        return 0;
      case BillingJobStage.ocrDone:
        return 1;
      case BillingJobStage.ruleDone:
        // 先让 RuleStage 校验固定快照仍可用；不可用时显式迁回 ocr_done。
        return 1;
      case BillingJobStage.transactionCreated:
        return 3;
      case BillingJobStage.aiDone:
      case BillingJobStage.completed:
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _runProcessors(
    BillingJob job,
    DateTime deadline,
    List<StageProcessor> processors,
    PipelineContext ctx,
  ) async {
    // 每个阶段后从 DB 刷新 job，避免快照过期
    var currentJob = job;
    for (final processor in processors) {
      if (DateTime.now().isAfter(deadline)) {
        ctx.failTransactionId('foreground_timeout');
        await _reportStatus('账单识别超时，等待重试');
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStatus(
            job.id,
            BillingJobStatus.retryableFailed,
            lastError: 'foreground_timeout',
            lease: lease,
            releaseLease: true,
          ),
        );
        return;
      }
      ctx.ensureCanStartSideEffect();
      await ctx.ensureJobOwned();
      await _reportStatus(_statusForProcessor(processor));
      final result = await processor.process(currentJob, deadline, ctx);
      if (result.success) {
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStage(
            job.id,
            processor.stageName,
            lease: lease,
          ),
        );
        // 刷新 job 快照，让下一阶段看到最新数据
        final refreshed = await repo.findById(job.id);
        if (refreshed != null) currentJob = refreshed;
      } else {
        if (result.awaitingConfirmation) {
          ctx.failTransactionId('awaiting_confirmation');
          await _reportStatus('账单需要确认，请检查金额和时间');
          return;
        }
        if (ctx.transactionId == null) {
          ctx.failTransactionId(result.error);
        }
        await _reportStatus(
          result.retryable ? '账单识别暂时失败，等待重试' : '账单识别失败',
        );
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStatus(
            job.id,
            result.retryable
                ? BillingJobStatus.retryableFailed
                : BillingJobStatus.failed,
            lastError: result.error,
            lease: lease,
            releaseLease: true,
          ),
        );
        return;
      }
    }
  }

  String _statusForProcessor(StageProcessor processor) {
    switch (processor.stageName) {
      case BillingJobStage.ocrDone:
        return '正在识别账单文字';
      case BillingJobStage.ruleDone:
        return '正在提取账单字段';
      case BillingJobStage.transactionCreated:
        return '正在创建账单';
      case BillingJobStage.aiDone:
        return '正在完善账单信息';
      default:
        return '正在处理账单';
    }
  }

  Future<void> _reportStatus(String status) async {
    final reporter = statusReporter;
    if (reporter == null) return;
    await reporter(status);
  }
}
