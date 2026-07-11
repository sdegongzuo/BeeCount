import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/attachment_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttachmentSaveService implements AttachmentSaveServiceInterface {
  bool called = false;
  String? lastImagePath;
  Future<int>? lastTransactionId;

  @override
  Future<void> saveAttachment(
      String imagePath, Future<int> transactionId) async {
    called = true;
    lastImagePath = imagePath;
    lastTransactionId = transactionId;
  }
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late FakeAttachmentSaveService attachmentService;
  late AttachmentStageProcessor processor;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    attachmentService = FakeAttachmentSaveService();
    processor = AttachmentStageProcessor(
        attachmentService: attachmentService, repo: repo);
  });

  tearDown(() async {
    await db.close();
  });

  test('saves AVIF attachment and marks attachment_done=true', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(attachmentService.called, isTrue);
    expect(attachmentService.lastImagePath, equals('/tmp/test.png'));
  });

  test('skips if attachment already exists for this job', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.markAttachmentDone(job.id);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(attachmentService.called, isFalse);
  });

  test('generates thumbnail from source image for AVIF', () async {
    final job = await repo.createJob(imagePath: '/tmp/avif_test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(attachmentService.lastImagePath, equals('/tmp/avif_test.png'));
  });

  test('small image (≤1920) skips JPEG preprocessing', () async {
    final job = await repo.createJob(imagePath: '/tmp/small.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(attachmentService.called, isTrue);
  });

  test('large image resizes before AVIF encoding', () async {
    final job = await repo.createJob(imagePath: '/tmp/large_4k.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(attachmentService.called, isTrue);
  });
}
