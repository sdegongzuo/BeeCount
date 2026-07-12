import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/rule_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late RuleStageProcessor processor;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    processor = const RuleStageProcessor();
  });

  tearDown(() async {
    await db.close();
  });

  test('rule stage rejects a missing OCR rule handoff', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some ocr text');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isFalse);
    expect(result.error, 'rule_result_missing');
    final updated = await repo.findById(job.id);
    expect(updated!.ruleResultJson, isNull);
  });

  test('rule extraction skips if rule_result_json exists', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    await repo.updateRuleResultJson(job.id, '{"existing": true}');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result =
        await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
  });
}
