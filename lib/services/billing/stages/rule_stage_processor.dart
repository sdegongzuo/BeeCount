import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../billing_job_runner.dart';

/// 规则提取阶段处理器。
/// OCR 生产服务已使用活动规则快照完成提取；本阶段校验其持久化交接。
class RuleStageProcessor implements StageProcessor {
  const RuleStageProcessor();

  @override
  String get stageName => BillingJobStage.ruleDone;

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    if (job.ruleResultJson != null && job.ruleResultJson!.isNotEmpty) {
      return const StageResult.success();
    }

    return const StageResult.failure('rule_result_missing');
  }
}
