import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/ocr_stage_processor.dart';
import 'package:beecount/services/platform/screenshot_source_info.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOcrService implements OcrServiceInterface {
  final String textToReturn;
  bool called = false;

  FakeOcrService({this.textToReturn = 'Sample receipt text'});

  @override
  Future<OcrStageOutput> recognizeText(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  }) async {
    called = true;
    return OcrStageOutput(rawText: textToReturn, engine: 'fake');
  }
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late OcrStageProcessor processor;
  late FakeOcrService ocrService;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    ocrService = FakeOcrService();
    processor = OcrStageProcessor(ocrService: ocrService, repo: repo);
  });

  tearDown(() async {
    await db.close();
  });

  test('OCR extracts raw_text from valid image', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isTrue);

    final updated = await repo.findById(job.id);
    expect(updated!.rawText, equals('Sample receipt text'));
    expect(updated.ruleResultJson, isNull);
    expect(updated.rulesVersion, isNull);
  });

  test('OCR skips if raw_text already exists (idempotent)', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'already existing text');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(ocrService.called, isFalse);
  });

  test('OCR fails when engine returns empty text', () async {
    final emptyService = FakeOcrService(textToReturn: '');
    final emptyProcessor =
        OcrStageProcessor(ocrService: emptyService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/empty.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await emptyProcessor.process(job, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.error, equals('ocr_empty_text'));

    final updated = await repo.findById(job.id);
    expect(updated!.rawText, isNull);
  });

  test('OCR fails on corrupted image file', () async {
    final corruptService = _ThrowingOcrService();
    final corruptProcessor =
        OcrStageProcessor(ocrService: corruptService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/corrupt.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await corruptProcessor.process(job, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isFalse);

    final updated = await repo.findById(job.id);
    expect(updated!.rawText, isNull);
  });
}

class _ThrowingOcrService implements OcrServiceInterface {
  @override
  Future<OcrStageOutput> recognizeText(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  }) async {
    throw Exception('corrupted image file');
  }
}
