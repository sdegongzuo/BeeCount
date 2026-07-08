import 'dart:convert';

import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../billing_job_runner.dart';
import '../ocr_service.dart';

/// 交易创建服务抽象。
/// 接收 OcrResult（由 OcrStageProcessor 通过 PipelineContext 或 ruleResultJson 传递），返回交易 ID。
abstract class TransactionCreationService {
  Future<int> createTransaction(OcrResult ocrResult);
}

/// 交易创建阶段处理器。
/// 如果 transactionId 已存在（幂等），跳过创建。
class TransactionStageProcessor implements StageProcessor {
  final TransactionCreationService txService;
  final BillingJobRepository repo;

  TransactionStageProcessor({required this.txService, required this.repo});

  @override
  String get stageName => BillingJobStage.transactionCreated;

  @override
  Future<StageResult> process(BillingJob job, DateTime deadline, PipelineContext ctx) async {
    if (job.transactionId != null) {
      return const StageResult.success();
    }

    try {
      // 从 PipelineContext 获取 OcrResult，或从 ruleResultJson 解析
      OcrResult ocrResult;
      if (ctx.ocrFields != null) {
        ocrResult = OcrResult.fromJson(ctx.ocrFields!);
      } else if (job.ruleResultJson != null && job.ruleResultJson!.isNotEmpty) {
        final json = jsonDecode(job.ruleResultJson!) as Map<String, dynamic>;
        ocrResult = OcrResult.fromJson(json);
      } else {
        return const StageResult.failure('no_ocr_result');
      }

      final txId = await txService.createTransaction(ocrResult);
      await repo.updateTransactionId(job.id, txId);
      ctx.transactionId = txId; // 写入 PipelineContext，供后续阶段使用
      return const StageResult.success();
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
