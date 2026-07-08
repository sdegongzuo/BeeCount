import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../billing_error_classifier.dart';
import '../billing_job_runner.dart';

/// AI 增强服务抽象。
abstract class AiEnhancementService {
  Future<Map<String, dynamic>> enhanceTransaction(int transactionId, String rawText);
}

/// AI 增强阶段处理器。
/// 如果 transactionId 为 null，跳过。
/// 错误分类统一使用 BillingErrorClassifier。
class AiStageProcessor implements StageProcessor {
  final AiEnhancementService aiService;
  final BillingJobRepository repo;
  final BillingErrorClassifier _classifier;

  AiStageProcessor({
    required this.aiService,
    required this.repo,
    BillingErrorClassifier? classifier,
  }) : _classifier = classifier ?? BillingErrorClassifier();

  @override
  String get stageName => BillingJobStage.aiDone;

  @override
  Future<StageResult> process(BillingJob job, DateTime deadline, PipelineContext ctx) async {
    // 优先从 PipelineContext 读取 transactionId（解决快照过期问题）
    final txId = ctx.transactionId ?? job.transactionId;
    if (txId == null) {
      return const StageResult.failure('no_transaction');
    }
    try {
      final result = await aiService.enhanceTransaction(
        txId,
        ctx.rawText ?? job.rawText ?? '',
      );
      await repo.updateFinalResultJson(job.id, result.toString());
      return const StageResult.success();
    } catch (e) {
      final classification = _classifier.classify(e);
      return StageResult.failure(classification.errorCode, retryable: classification.retryable);
    }
  }
}
