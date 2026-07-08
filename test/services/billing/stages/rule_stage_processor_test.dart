import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/stages/rule_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRuleExtractionService implements RuleExtractionService {
  final String? resultToReturn;
  bool called = false;

  FakeRuleExtractionService({this.resultToReturn = '{"amount": 100}'});

  @override
  Future<String?> extractRules(String rawText, String imagePath) async {
    called = true;
    return resultToReturn;
  }
}

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late RuleStageProcessor processor;
  late FakeRuleExtractionService ruleService;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    ruleService = FakeRuleExtractionService();
    processor = RuleStageProcessor(ruleService: ruleService, repo: repo);
  });

  tearDown(() async {
    await db.close();
  });

  test('rule extraction populates rule_result_json', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some ocr text');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.ruleResultJson, isNotNull);
  });

  test('rule extraction skips if rule_result_json exists', () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    await repo.updateRuleResultJson(job.id, '{"existing": true}');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await processor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    expect(ruleService.called, isFalse);
  });

  test('rule extraction proceeds with empty match', () async {
    final emptyService = FakeRuleExtractionService(resultToReturn: null);
    final emptyProcessor = RuleStageProcessor(ruleService: emptyService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await emptyProcessor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.ruleResultJson, isNull);
  });

  test('rule extraction merges legacy regex results', () async {
    final mergeService = FakeRuleExtractionService(
      resultToReturn: '{"toml": {"amount": 50}, "legacy": {"note": "coffee"}}',
    );
    final mergeProcessor = RuleStageProcessor(ruleService: mergeService, repo: repo);
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, 'some text');
    final updatedJob = await repo.findById(job.id);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    final result = await mergeProcessor.process(updatedJob!, deadline, PipelineContext());

    expect(result.success, isTrue);
    final updated = await repo.findById(job.id);
    expect(updated!.ruleResultJson, contains('toml'));
    expect(updated.ruleResultJson, contains('legacy'));
  });
}
