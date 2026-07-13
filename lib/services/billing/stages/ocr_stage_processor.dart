import 'dart:convert';

import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../../platform/screenshot_source_info.dart';
import '../billing_job_runner.dart';
import '../ocr_service.dart';

/// OCR 服务抽象：调用完整 OCR + 规则提取，返回 OcrResult。
/// enableAiEnhancement=false 以跳过 AI。
abstract class OcrServiceInterface {
  Future<OcrResult> recognize(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  });
}

/// OCR 阶段处理器。
/// 调用 OcrService（OCR + 规则提取，一次完成），存储 rawText 和完整 OcrResult JSON。
/// 后续阶段可从 PipelineContext 获取 OcrResult，无需重新 OCR。
class OcrStageProcessor implements StageProcessor {
  final OcrServiceInterface ocrService;
  final BillingJobRepository repo;

  OcrStageProcessor({required this.ocrService, required this.repo});

  @override
  String get stageName => BillingJobStage.ocrDone;

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    // 幂等：已有 rawText 则跳过
    if (job.rawText != null && job.rawText!.isNotEmpty) {
      ctx.rawText = job.rawText;
      // 尝试从 ruleResultJson 恢复 OcrResult
      if (job.ruleResultJson != null && job.ruleResultJson!.isNotEmpty) {
        try {
          ctx.ocrFields =
              jsonDecode(job.ruleResultJson!) as Map<String, dynamic>;
        } catch (_) {}
      }
      return const StageResult.success();
    }

    try {
      ctx.ensureCanStartSideEffect();
      await ctx.ensureJobOwned();
      final ocrResult = await ocrService.recognize(
        job.imagePath,
        sourceInfo: ctx.sourceInfo,
      );
      if (ocrResult.rawText.isEmpty) {
        return const StageResult.failure('ocr_empty_text');
      }

      // 存储 rawText
      await ctx.requireOwnedWrite(
        (lease) => repo.updateRawText(
          job.id,
          ocrResult.rawText,
          lease: lease,
        ),
      );
      ctx.rawText = ocrResult.rawText;

      // 存储完整 OcrResult JSON 到 ruleResultJson（规则阶段为空操作）
      final ocrJson = jsonEncode(ocrResult.toJson());
      await ctx.requireOwnedWrite(
        (lease) => repo.updateRuleResultJson(
          job.id,
          ocrJson,
          lease: lease,
        ),
      );
      ctx.ocrFields = ocrResult.toJson();

      return const StageResult.success();
    } on BillingJobExecutionCancelled {
      rethrow;
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
