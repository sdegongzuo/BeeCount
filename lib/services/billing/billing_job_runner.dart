import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import '../platform/screenshot_source_info.dart';

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

  /// 分享来源信息，供 OCR/规则阶段保留 app 来源和支付通道证据。
  ScreenshotSourceInfo? sourceInfo;

  PipelineContext();
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

  BillingJobRunner({
    required this.repo,
    required this.ocrProcessor,
    required this.ruleProcessor,
    required this.txProcessor,
    required this.aiProcessor,
    this.attachmentProcessor,
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
    final processors = [ocrProcessor, ruleProcessor, txProcessor, aiProcessor];
    await _runProcessors(job, deadline, processors, ctx);

    // 附件在主流程完成后启动（此时 transactionId 已在 ctx 中）
    if (attachmentProcessor != null) {
      final freshJob = await repo.findById(job.id);
      if (freshJob != null) {
        await attachmentProcessor!.process(freshJob, deadline, ctx);
      }
    }

    final current = await repo.findById(job.id);
    if (current == null) return;
    if (current.status != BillingJobStatus.failed &&
        current.status != BillingJobStatus.retryableFailed) {
      await repo.markSucceeded(job.id);
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
    // 恢复时，从已有 stage 之前的数据重建 ctx
    ctx.rawText = job.rawText;
    ctx.transactionId = job.transactionId;

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
    if (attachmentProcessor != null) {
      final freshJob = await repo.findById(job.id);
      if (freshJob != null) {
        await attachmentProcessor!.process(freshJob, deadline, ctx);
      }
    }

    final current = await repo.findById(job.id);
    if (current == null) return;

    if (current.status == BillingJobStatus.retryableFailed) {
      await repo.updateStatus(current.id, BillingJobStatus.pending);
      final refreshed = await repo.findById(job.id);
      if (refreshed == null) return;
      await repo.markSucceeded(job.id);
      return;
    }

    if (current.status != BillingJobStatus.failed) {
      await repo.markSucceeded(job.id);
    }
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
        await repo.updateStatus(job.id, BillingJobStatus.retryableFailed,
            lastError: 'foreground_timeout');
        return;
      }
      final result = await processor.process(currentJob, deadline, ctx);
      if (result.success) {
        await repo.updateStage(job.id, processor.stageName);
        // 刷新 job 快照，让下一阶段看到最新数据
        final refreshed = await repo.findById(job.id);
        if (refreshed != null) currentJob = refreshed;
      } else {
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
}
