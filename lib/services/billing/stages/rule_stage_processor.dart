import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../billing_job_runner.dart';

/// 规则提取服务抽象。
abstract class RuleExtractionService {
  Future<String?> extractRules(String rawText, String imagePath);
}

/// 规则提取阶段处理器。
/// 如果 ruleResultJson 已有值（幂等），跳过。
class RuleStageProcessor implements StageProcessor {
  final RuleExtractionService ruleService;
  final BillingJobRepository repo;

  RuleStageProcessor({required this.ruleService, required this.repo});

  @override
  String get stageName => BillingJobStage.ruleDone;

  @override
  Future<StageResult> process(BillingJob job, DateTime deadline, PipelineContext ctx) async {
    if (job.ruleResultJson != null && job.ruleResultJson!.isNotEmpty) {
      return const StageResult.success();
    }

    try {
      final result = await ruleService.extractRules(
        ctx.rawText ?? job.rawText ?? '',
        job.imagePath,
      );
      if (result != null && result.isNotEmpty) {
        await repo.updateRuleResultJson(job.id, result);
      }
      return const StageResult.success();
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
