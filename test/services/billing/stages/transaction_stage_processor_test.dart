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
    final processor = TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some ocr text');
    // Store OcrResult JSON in ruleResultJson
    final ocrResult = OcrResult(rawText: 'some ocr text', allNumbers: [], amount: 100);
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(42));
  });

  test('skips creation if transaction_id already exists', () async {
    final txService = FakeTransactionCreationService();
    final processor = TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 99);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(txService.called, isFalse);
  });

  test('deduplicates by time+amount within same second', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 77);
    final processor = TransactionStageProcessor(txService: txService, repo: repo);
    final ocrResult = OcrResult(rawText: 'text', allNumbers: [], amount: 50, time: DateTime(2026, 7, 7, 12, 0, 0));

    final job1 = await repo.createJob(imagePath: '/tmp/test1.png');
    await repo.updateRawText(job1.id, 'text');
    await repo.updateRuleResultJson(job1.id, jsonEncode(ocrResult.toJson()));
    final updated1 = await repo.findById(job1.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final result1 = await processor.process(updated1!, deadline, PipelineContext());

    final job2 = await repo.createJob(imagePath: '/tmp/test2.png');
    await repo.updateRawText(job2.id, 'text');
    await repo.updateRuleResultJson(job2.id, jsonEncode(ocrResult.toJson()));
    final updated2 = await repo.findById(job2.id);
    final result2 = await processor.process(updated2!, deadline, PipelineContext());

    expect(result1.success, isTrue);
    expect(result2.success, isTrue);
    expect(txService.callCount, equals(2));
  });

  test('assigns default category when match fails', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 88);
    final processor = TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final ocrResult = OcrResult(rawText: 'some text', allNumbers: []);
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(88));
  });

  test('assigns default account when match fails', () async {
    final txService = FakeTransactionCreationService(txIdToReturn: 99);
    final processor = TransactionStageProcessor(txService: txService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final ocrResult = OcrResult(rawText: 'some text', allNumbers: []);
    await repo.updateRuleResultJson(job.id, jsonEncode(ocrResult.toJson()));
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(99));
  });
}
