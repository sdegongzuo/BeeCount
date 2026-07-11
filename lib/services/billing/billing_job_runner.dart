import 'dart:async';

import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import '../platform/screenshot_source_info.dart';

typedef BillingJobStatusReporter = FutureOr<void> Function(String status);

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

  PipelineContext();

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

class StageResult {
  final bool success;
  final bool retryable;
  final String? error;

  const StageResult.success()
      : success = true,
        retryable = false,
        error = null;
  const StageResult.failure(this.error, {this.retryable = false})
      : success = false;
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

  Future<void> runJob(
    BillingJob job,
    DateTime deadline, {
    PipelineContext? initialContext,
  }) async {
    final claimed =
        await repo.claimJob(job.id, deadline.difference(DateTime.now()));
    if (!claimed) return;

    final ctx = initialContext ?? PipelineContext();
    await _reportStatus('已接收图片，准备识别账单');
    await _dispatchAttachment(job, deadline, ctx);
    await _runProcessors(job, deadline,
        [ocrProcessor, ruleProcessor, txProcessor, aiProcessor], ctx);

    // 附件在主流程完成后启动（此时 transactionId 已在 ctx 中）
    final current = await repo.findById(job.id);
    if (current == null) return;
    if (current.status != BillingJobStatus.failed &&
        current.status != BillingJobStatus.retryableFailed) {
      await _completeJob(job.id);
    }
  }

  Future<void> resumeJob(
    BillingJob job,
    DateTime deadline, {
    PipelineContext? initialContext,
  }) async {
    final claimed =
        await repo.claimJob(job.id, deadline.difference(DateTime.now()));
    if (!claimed) return;

    final ctx = initialContext ?? PipelineContext();
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
    if (current == null) return;

    if (current.status == BillingJobStatus.retryableFailed) {
      await repo.updateStatus(current.id, BillingJobStatus.pending);
      final refreshed = await repo.findById(job.id);
      if (refreshed == null) return;
      await _completeJob(job.id);
      return;
    }

    if (current.status != BillingJobStatus.failed) {
      await _completeJob(job.id);
    }
  }

  Future<void> _completeJob(int jobId) async {
    await repo.updateStage(jobId, BillingJobStage.completed);
    await _reportStatus('账单识别完成，正在收尾');
    await repo.markSucceeded(jobId);
  }

  Future<void> _dispatchAttachment(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    if (attachmentProcessor == null) return;
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
        return 2;
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
        await repo.updateStatus(job.id, BillingJobStatus.retryableFailed,
            lastError: 'foreground_timeout');
        return;
      }
      await _reportStatus(_statusForProcessor(processor));
      final result = await processor.process(currentJob, deadline, ctx);
      if (result.success) {
        await repo.updateStage(job.id, processor.stageName);
        // 刷新 job 快照，让下一阶段看到最新数据
        final refreshed = await repo.findById(job.id);
        if (refreshed != null) currentJob = refreshed;
      } else {
        if (ctx.transactionId == null) {
          ctx.failTransactionId(result.error);
        }
        await _reportStatus(
          result.retryable ? '账单识别暂时失败，等待重试' : '账单识别失败',
        );
        await repo.updateStatus(
          job.id,
          result.retryable
              ? BillingJobStatus.retryableFailed
              : BillingJobStatus.failed,
          lastError: result.error,
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
