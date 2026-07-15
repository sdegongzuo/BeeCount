import 'dart:async';
import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/stages/transaction_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransactionCreationService implements TransactionCreationService {
  final int txIdToReturn;
  bool called = false;
  int callCount = 0;

  FakeTransactionCreationService({this.txIdToReturn = 42});

  @override
  Future<int> createTransaction(OcrResult ocrResult) async {
    called = true;
    callCount++;
    return txIdToReturn;
  }
}

class BlockingTransactionCreationService implements TransactionCreationService {
  final started = Completer<void>();
  final result = Completer<int>();
  int callCount = 0;

  @override
  Future<int> createTransaction(OcrResult ocrResult) {
    callCount++;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _LeaseBreakingTransactionCreationService
    implements TransactionCreationService {
  _LeaseBreakingTransactionCreationService(this.db);

  final BeeDatabase db;

  @override
  Future<int> createTransaction(OcrResult ocrResult) async {
    await db.customStatement('INSERT INTO atomic_tx_marker (id) VALUES (901)');
    await db.customStatement(
      'UPDATE billing_jobs SET lease_until = 0 WHERE image_path = ?',
      ['/tmp/atomic-rollback.png'],
    );
    return 901;
  }
}

class _MarkerTransactionCreationService implements TransactionCreationService {
  _MarkerTransactionCreationService(this.db);

  final BeeDatabase db;
  int calls = 0;

  @override
  Future<int> createTransaction(OcrResult ocrResult) async {
    calls++;
    await db.customStatement('INSERT INTO atomic_tx_marker (id) VALUES (902)');
    return 902;
  }
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates transaction and saves transaction_id', () async {
    final txService = FakeTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some ocr text');
    // Store OcrResult JSON in ruleResultJson
    final ocrResult = OcrResult(
      rawText: 'some ocr text',
      allNumbers: [],
      amount: 100,
      time: DateTime(2026, 7, 12, 10, 30),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(42));
  });

  test('rule-quality rejection does not block valid amount and time', () async {
    final txService = FakeTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/low-confidence.png');
    final candidate = OcrResult(
      rawText: '疑似金额 18.00',
      allNumbers: const ['18.00'],
      amount: 18,
      time: DateTime(2026, 7, 12, 10, 30),
      fastBillingRejectReasons: const ['amount_low_confidence'],
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(candidate.toJson()));

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.success, isTrue);
    expect(txService.called, isTrue);
  });

  test('missing critical field saves a recoverable confirmation draft',
      () async {
    final txService = FakeTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/unreliable.png');
    final candidate = OcrResult(
      rawText: '付款金额\n¥18.00',
      allNumbers: const ['18.00'],
      amount: 18,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(candidate.toJson()));

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.awaitingConfirmation, isTrue);
    expect(txService.called, isFalse);
    final updated = await repo.findById(job.id);
    expect(updated!.status, BillingJobStatus.awaitingConfirmation);
    expect(updated.transactionId, isNull);
    expect(jsonDecode(updated.finalResultJson!)['amount'], 18.0);
    expect(updated.imagePath, '/tmp/unreliable.png');
  });

  test('non-positive amount remains blocked even when time exists', () async {
    final txService = FakeTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/non-positive.png');
    final candidate = OcrResult(
      rawText: '支付金额 0.00',
      allNumbers: const ['0.00'],
      amount: 0,
      time: DateTime(2026, 7, 16, 10, 30),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(candidate.toJson()));

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.awaitingConfirmation, isTrue);
    expect(txService.called, isFalse);
  });

  test('skips creation if transaction_id already exists', () async {
    final txService = FakeTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 99);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(txService.called, isFalse);
  });

  test(
      'an already-started transaction is fenced into its job before delivery cancellation',
      () async {
    final txService = BlockingTransactionCreationService();
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/lost-delivery.png');
    final candidate = OcrResult(
      rawText: '付款 18.00',
      allNumbers: const ['18.00'],
      amount: 18,
      time: DateTime(2026, 7, 14, 1, 2, 3),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(candidate.toJson()));
    final lease =
        (await repo.claimJobLease(job.id, const Duration(seconds: 5)))!;
    var deliveryOwned = true;
    final context = PipelineContext(
      ensureDeliveryOwned: () {
        if (!deliveryOwned) throw StateError('delivery lease lost');
      },
    )..configureOwnership(repository: repo, lease: lease);

    final first = processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 5)),
      context,
    );
    await txService.started.future;
    deliveryOwned = false;
    txService.result.complete(812);

    expect((await first).success, isTrue);
    expect((await repo.findById(job.id))!.transactionId, 812);

    final second = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 5)),
      PipelineContext(),
    );
    expect(second.success, isTrue);
    expect(txService.callCount, 1);
  });

  test('production atomic creator rolls back a transaction if job CAS fails',
      () async {
    await db.customStatement(
      'CREATE TABLE atomic_tx_marker (id INTEGER PRIMARY KEY)',
    );
    final job = await repo.createJob(imagePath: '/tmp/atomic-rollback.png');
    final candidate = OcrResult(
      rawText: '付款 9.01',
      allNumbers: const ['9.01'],
      amount: 9.01,
      time: DateTime(2026, 7, 14, 2, 3, 4),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(candidate.toJson()));
    final lease =
        (await repo.claimJobLease(job.id, const Duration(seconds: 5)))!;
    final context = PipelineContext()
      ..configureOwnership(repository: repo, lease: lease);
    final processor = TransactionStageProcessor(
      txService: AtomicBillingJobTransactionCreationService(
        database: db,
        delegate: _LeaseBreakingTransactionCreationService(db),
      ),
      repo: repo,
    );

    await expectLater(
      processor.process(
        (await repo.findById(job.id))!,
        DateTime.now().add(const Duration(seconds: 5)),
        context,
      ),
      throwsA(isA<BillingJobExecutionCancelled>()),
    );

    expect((await repo.findById(job.id))!.transactionId, isNull);
    final markerCount = await db
        .customSelect(
          'SELECT COUNT(*) AS count FROM atomic_tx_marker',
        )
        .getSingle();
    expect(markerCount.read<int>('count'), 0);
  });

  test('concurrent atomic creators serialize and reuse the committed bill',
      () async {
    await db.customStatement(
      'CREATE TABLE atomic_tx_marker (id INTEGER PRIMARY KEY)',
    );
    final job = await repo.createJob(imagePath: '/tmp/atomic-concurrent.png');
    final lease =
        (await repo.claimJobLease(job.id, const Duration(seconds: 5)))!;
    final candidate = OcrResult(
      rawText: '付款 9.02',
      allNumbers: const ['9.02'],
      amount: 9.02,
      time: DateTime(2026, 7, 14, 2, 3, 5),
      fastBillingAccepted: true,
    );
    final delegate = _MarkerTransactionCreationService(db);
    final creator = AtomicBillingJobTransactionCreationService(
      database: db,
      delegate: delegate,
    );

    final results = await Future.wait([
      creator.createTransactionForJob(
        jobId: job.id,
        lease: lease,
        ocrResult: candidate,
      ),
      creator.createTransactionForJob(
        jobId: job.id,
        lease: lease,
        ocrResult: candidate,
      ),
    ]);

    expect(results, [902, 902]);
    expect(delegate.calls, 1);
    expect((await repo.findById(job.id))!.transactionId, 902);
    final markerCount = await db
        .customSelect(
          'SELECT COUNT(*) AS count FROM atomic_tx_marker',
        )
        .getSingle();
    expect(markerCount.read<int>('count'), 1);
  });

  test('deduplicates by time+amount within same second', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 77);
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final ocrResult = OcrResult(
        rawText: 'text',
        allNumbers: [],
        amount: 50,
        time: DateTime(2026, 7, 7, 12, 0, 0),
        fastBillingAccepted: true);

    final job1 = await repo.createJob(imagePath: '/tmp/test1.png');
    await repo.updateRawText(job1.id, 'text');
    await repo.updateRuleResultJson(job1.id, jsonEncode(ocrResult.toJson()));
    final updated1 = await repo.findById(job1.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final result1 =
        await processor.process(updated1!, deadline, PipelineContext());

    final job2 = await repo.createJob(imagePath: '/tmp/test2.png');
    await repo.updateRawText(job2.id, 'text');
    await repo.updateRuleResultJson(job2.id, jsonEncode(ocrResult.toJson()));
    final updated2 = await repo.findById(job2.id);
    final result2 =
        await processor.process(updated2!, deadline, PipelineContext());

    expect(result1.success, isTrue);
    expect(result2.success, isTrue);
    expect(txService.callCount, equals(2));
  });

  test('assigns default category when match fails', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 88);
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final ocrResult = OcrResult(
      rawText: 'some text',
      allNumbers: const [],
      amount: 12,
      time: DateTime(2026, 7, 12),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(88));
  });

  test('assigns default account when match fails', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 99);
    final processor =
        TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final ocrResult = OcrResult(
      rawText: 'some text',
      allNumbers: const [],
      amount: 12,
      time: DateTime(2026, 7, 12),
      fastBillingAccepted: true,
    );
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(99));
  });
}
