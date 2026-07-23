import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../../platform/screenshot_source_info.dart';
import '../billing_job_runner.dart';

class OcrStageOutput {
  final String rawText;
  final String? engine;

  const OcrStageOutput({required this.rawText, this.engine});
}

abstract class OcrServiceInterface {
  Future<OcrStageOutput> recognizeText(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  });
}

/// OCR 阶段处理器。
/// 只执行图片文字识别并保存 rawText；规则执行由下一 Stage 完成。
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
      return const StageResult.success();
    }

    try {
      ctx.ensureCanStartSideEffect();
      await ctx.ensureJobOwned();
      final ocrResult = await ocrService.recognizeText(
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

      return const StageResult.success();
    } on BillingJobExecutionCancelled {
      rethrow;
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
