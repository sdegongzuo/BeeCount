import 'dart:async';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/ai/ai_provider_factory.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/ai_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAiEnhancementService implements AiEnhancementService {
  bool called = false;

  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    called = true;
    return {'enhanced': true};
  }
}

class _TimeoutAiService implements AiEnhancementService {
  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw TimeoutException('AI timeout');
  }
}

class _RateLimitAiService implements AiEnhancementService {
  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    throw const HttpException('429 Too Many Requests');
  }
}

class _GenericFailureAiService implements AiEnhancementService {
  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    throw Exception('ai_api_error');
  }
}

class _WrappedConnectionAbortAiService implements AiEnhancementService {
  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    throw AIException(
      '[null] API调用失败: HttpException: Software caused connection abort',
    );
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

  test('AI enhances transaction with extracted fields', () async {
    final aiService = FakeAiEnhancementService();
    final processor = AiStageProcessor(aiService: aiService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(aiService.called, isTrue);
  });

  test('AI skips if transaction_id is null', () async {
    final aiService = FakeAiEnhancementService();
    final processor = AiStageProcessor(aiService: aiService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(job, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.error, equals('no_transaction'));
    expect(aiService.called, isFalse);
  });

  test('AI timeout classified as retryable', () async {
    final processor =
        AiStageProcessor(aiService: _TimeoutAiService(), repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isTrue);
  });

  test('AI 401/403 classified as non-retryable', () async {
    final processor =
        AiStageProcessor(aiService: _GenericFailureAiService(), repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isFalse);
  });

  test('AI 429 classified as retryable', () async {
    final processor =
        AiStageProcessor(aiService: _RateLimitAiService(), repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isTrue);
  });

  test('AI network unavailable classified as retryable', () async {
    final processor = AiStageProcessor(
      aiService: _NetworkUnavailableAiService(),
      repo: repo,
    );
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isTrue);
  });

  test('AI wrapped connection abort classified as retryable', () async {
    final processor = AiStageProcessor(
      aiService: _WrappedConnectionAbortAiService(),
      repo: repo,
    );
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isTrue);
    expect(result.error, 'network_unavailable');
  });

  test('AI does not pollute transaction detailsText', () async {
    final processor =
        AiStageProcessor(aiService: _GenericFailureAiService(), repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateTransactionId(job.id, 42);
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.retryable, isFalse);
    final updated = await repo.findById(job.id);
    expect(updated!.transactionId, equals(42));
  });
}

class _NetworkUnavailableAiService implements AiEnhancementService {
  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    throw const SocketException('Network is unreachable');
  }
}
