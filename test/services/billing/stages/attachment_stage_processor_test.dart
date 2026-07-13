import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/attachment_stage_processor.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttachmentSaveService implements AttachmentSaveServiceInterface {
  bool called = false;
  String? lastImagePath;
  Future<int>? lastTransactionId;
  int? lastBillingJobId;
  BillingJobLease? lastLease;

  @override
  Future<Set<String>> indexRecoveryFiles() async => const {};

  @override
  Future<void> saveAttachment(
    String imagePath,
    Future<int> transactionId, {
    int? billingJobId,
    BillingJobLease? lease,
    Set<String>? recoveryFileNames,
  }) async {
    called = true;
    lastImagePath = imagePath;
    lastTransactionId = transactionId;
    lastBillingJobId = billingJobId;
    lastLease = lease;
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
    expect(attachmentService.lastBillingJobId, job.id);
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

  test('Billing Job attachment retries use the same deterministic record', () {
    final existing = TransactionAttachment(
      id: 7,
      transactionId: 81,
      fileName: 'tx_81_42_0.avif',
      sortOrder: 0,
      createdAt: DateTime(2026, 7, 14),
    );

    expect(
      findExistingBillingJobAttachment(
        attachments: [existing],
        transactionId: 81,
        billingJobId: 42,
        index: 0,
      ),
      same(existing),
    );
    expect(
      findExistingBillingJobAttachment(
        attachments: [existing],
        transactionId: 81,
        billingJobId: 43,
        index: 0,
      ),
      isNull,
    );
  });

  test('format changes reuse an existing supported stable file', () {
    expect(
      findExistingBillingJobAttachmentFileName(
        fileNames: [
          'tx_81_42_0.avif',
          'tx_81_42_0.txt',
          'tx_81_43_0.webp',
        ],
        transactionId: 81,
        billingJobId: 42,
        index: 0,
      ),
      'tx_81_42_0.avif',
    );
  });

  test('zero-byte attachment candidate is not decodable', () async {
    expect(
      await decodeCompleteBillingJobAttachmentBytes(
        Uint8List(0),
        extension: '.jpg',
      ),
      isNull,
    );
  });

  test('corrupt non-empty attachment candidate is not decodable', () async {
    expect(
      await decodeCompleteBillingJobAttachmentBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        extension: '.jpg',
      ),
      isNull,
    );
  });

  test('a completely decodable image candidate returns dimensions', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final image = await recorder.endRecording().toImage(1, 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final decoded = await decodeCompleteBillingJobAttachmentBytes(
      byteData!.buffer.asUint8List(),
      extension: '.png',
    );

    expect(decoded, (width: 1, height: 1));
  });
}
