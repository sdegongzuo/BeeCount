import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/attachment_stage_processor.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAttachmentSaveService implements AttachmentSaveServiceInterface {
  bool called = false;
  String? lastImagePath;
  Future<int>? lastTransactionId;
  int? lastBillingJobId;
  BillingJobLease? lastLease;
  Object? saveError;

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
    if (saveError case final error?) throw error;
    called = true;
    lastImagePath = imagePath;
    lastTransactionId = transactionId;
    lastBillingJobId = billingJobId;
    lastLease = lease;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

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

  test('a failed attachment save does not mark attachment_done', () async {
    final job = await repo.createJob(imagePath: '/tmp/failure.png');
    attachmentService.saveError = StateError('write failed');

    final result = await processor.process(
      job,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(result.success, isTrue);
    expect((await repo.findById(job.id))!.attachmentDone, isFalse);
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

  group('database attachment recovery validation', () {
    late BeeDatabase attachmentDb;
    late LocalRepository attachmentRepo;
    late Directory attachmentDir;
    late ProviderContainer container;
    late AttachmentService service;
    late File sourceFile;
    late Uint8List validImageBytes;

    setUp(() async {
      attachmentDb = BeeDatabase.forTesting(NativeDatabase.memory());
      attachmentRepo = LocalRepository(attachmentDb);
      attachmentDir = await Directory(
        '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}beecount_attachment_recovery_'
        '${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      validImageBytes = await _onePixelPngBytes();
      sourceFile =
          File('${attachmentDir.path}${Platform.pathSeparator}source.png');
      await sourceFile.writeAsBytes(validImageBytes, flush: true);
      final testServiceProvider = Provider<AttachmentService>(
        (ref) => _TestAttachmentService(ref, attachmentDir),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(attachmentRepo)],
      );
      service = container.read(testServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await attachmentDb.close();
    });

    test('a database row with a missing file is rebuilt and upserted',
        () async {
      final originalId = await attachmentRepo.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: 'tx_61_9_0.jpg',
        fileSize: 999,
      );

      final recovered = await service.saveAttachmentWhenTransactionReady(
        transactionId: Future.value(61),
        sourceFile: sourceFile,
        index: 0,
        billingJobId: 9,
        recoveryFileNames: const {},
      );

      expect(recovered!.id, originalId);
      expect(recovered.originKey, 'billing:9:0');
      expect(recovered.fileSize, isNot(999));
      expect(
        await decodeCompleteBillingJobAttachmentBytes(
          await File('${attachmentDir.path}${Platform.pathSeparator}'
                  '${recovered.fileName}')
              .readAsBytes(),
          extension: '.jpg',
        ),
        isNotNull,
      );
      expect(
          await attachmentRepo.getAttachmentsByTransaction(61), hasLength(1));
    });

    test('a database row with corrupt bytes is rebuilt and upserted', () async {
      final fileName = 'tx_61_9_0.jpg';
      await File('${attachmentDir.path}${Platform.pathSeparator}$fileName')
          .writeAsBytes([1, 2, 3, 4], flush: true);
      final originalId = await attachmentRepo.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: fileName,
        fileSize: 4,
      );

      final recovered = await service.saveAttachmentWhenTransactionReady(
        transactionId: Future.value(61),
        sourceFile: sourceFile,
        index: 0,
        billingJobId: 9,
        recoveryFileNames: {fileName},
      );

      expect(recovered!.id, originalId);
      expect(recovered.originKey, 'billing:9:0');
      expect(
        await decodeCompleteBillingJobAttachmentBytes(
          await File('${attachmentDir.path}${Platform.pathSeparator}$fileName')
              .readAsBytes(),
          extension: '.jpg',
        ),
        isNotNull,
      );
      expect(
          await attachmentRepo.getAttachmentsByTransaction(61), hasLength(1));
    });

    test('a database row with a complete image is reused', () async {
      final fileName = 'tx_61_9_0.jpg';
      await File('${attachmentDir.path}${Platform.pathSeparator}$fileName')
          .writeAsBytes(validImageBytes, flush: true);
      final originalId = await attachmentRepo.upsertBillingAttachment(
        originKey: 'billing:9:0',
        transactionId: 61,
        fileName: fileName,
        fileSize: validImageBytes.length,
      );
      final unavailableSource = File(
        '${attachmentDir.path}${Platform.pathSeparator}unavailable-source.png',
      );

      final recovered = await service.saveAttachmentWhenTransactionReady(
        transactionId: Future.value(61),
        sourceFile: unavailableSource,
        index: 0,
        billingJobId: 9,
        recoveryFileNames: {fileName},
      );

      expect(recovered!.id, originalId);
      expect(recovered.fileName, fileName);
      expect(
          await attachmentRepo.getAttachmentsByTransaction(61), hasLength(1));
    });
  });
}

final class _TestAttachmentService extends AttachmentService {
  final Directory attachmentDirectory;

  _TestAttachmentService(super.ref, this.attachmentDirectory);

  @override
  Future<Directory> getAttachmentDirectory() async => attachmentDirectory;
}

Future<Uint8List> _onePixelPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(1, 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
