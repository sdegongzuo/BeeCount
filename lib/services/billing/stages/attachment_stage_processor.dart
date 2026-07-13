import 'dart:async';

import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../../system/logger_service.dart';
import '../billing_job_runner.dart';

/// 附件保存服务抽象。
abstract class AttachmentSaveServiceInterface {
  Future<void> saveAttachment(
    String imagePath,
    Future<int> transactionId, {
    int? billingJobId,
    BillingJobLease? lease,
  });
}

/// 附件保存阶段处理器。
/// 如果 attachmentDone 已为 true（幂等），跳过。
class AttachmentStageProcessor implements StageProcessor {
  final AttachmentSaveServiceInterface attachmentService;
  final BillingJobRepository repo;

  AttachmentStageProcessor(
      {required this.attachmentService, required this.repo});

  @override
  String get stageName => 'attachment';

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    if (job.attachmentDone) {
      return const StageResult.success();
    }

    try {
      ctx.ensureCanStartSideEffect();
      await ctx.ensureJobOwned();
      final txFuture = job.transactionId != null
          ? Future<int>.value(job.transactionId)
          : ctx.transactionIdFuture;
      unawaited(
        attachmentService
            .saveAttachment(
          job.imagePath,
          txFuture,
          billingJobId: job.id,
          lease: ctx.lease,
        )
            .then((_) {
          return ctx.requireOwnedWrite(
            (lease) => repo.markAttachmentDone(job.id, lease: lease),
          );
        }).catchError((Object e, StackTrace st) {
          logger.error('AttachmentStage', '附件后台保存失败', e, st);
        }),
      );
      return const StageResult.success();
    } on BillingJobExecutionCancelled {
      rethrow;
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
