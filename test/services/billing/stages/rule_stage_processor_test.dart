import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_runner.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/stages/rule_stage_processor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late BillingJobRepository repo;
  late _SnapshotSource source;
  late RuleStageProcessor processor;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingJobRepository(db);
    source = _SnapshotSource(_ruleSet());
    processor = RuleStageProcessor(
      repo: repo,
      snapshots: source,
      engine: const BillingRuleEngineImpl(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('ocr_done evaluates the latest real rule snapshot and pins it',
      () async {
    final job = await repo.createJob(imagePath: '/tmp/test.png');
    await repo.updateRawText(job.id, '账单');
    await repo.updateStage(job.id, BillingJobStage.ocrDone);

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.success, isTrue);
    final updated = (await repo.findById(job.id))!;
    expect(updated.stage, BillingJobStage.ruleDone);
    expect(updated.rulePackageVersion, 12);
    expect(updated.rulesVersion, 'rules-2');
    expect(updated.normalizationVersion, 2);
    expect(updated.personalRulesRevision, 37);
    expect(
      jsonDecode(updated.ruleResultJson!)['payment_method'],
      '候选支付方式',
    );
  });

  test('rule_done retry keeps using its available pinned snapshot', () async {
    final job = await _committedJob(repo);
    source.active = _ruleSet(paymentMethod: '新活动值');

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.success, isTrue);
    expect(
      jsonDecode(
          (await repo.findById(job.id))!.ruleResultJson!)['payment_method'],
      '候选支付方式',
    );
  });

  test('missing pinned snapshot explicitly returns to ocr_done', () async {
    final job = await _committedJob(repo);
    source.pinnedAvailable = false;

    final result = await processor.process(
      (await repo.findById(job.id))!,
      DateTime.now().add(const Duration(seconds: 30)),
      PipelineContext(),
    );

    expect(result.success, isFalse);
    expect(result.error, 'snapshot_migrated');
    final migrated = (await repo.findById(job.id))!;
    expect(migrated.stage, BillingJobStage.ocrDone);
    expect(migrated.ruleResultJson, isNull);
    expect(migrated.ruleSnapshotStatus, 'snapshot_migrated');
  });
}

class _SnapshotSource implements BillingJobRuleSnapshotSource {
  BillingRuleSet active;
  bool pinnedAvailable = true;

  _SnapshotSource(this.active);

  @override
  Future<BillingRuleSet> loadLatest() async => active;

  @override
  Future<BillingRuleSet?> loadPinned(
    BillingRuleExecutionSnapshot snapshot,
  ) async =>
      pinnedAvailable ? _ruleSet() : null;
}

Future<BillingJob> _committedJob(BillingJobRepository repo) async {
  final job = await repo.createJob(imagePath: '/tmp/pinned.png');
  await repo.updateRawText(job.id, '账单');
  await repo.updateStage(job.id, BillingJobStage.ocrDone);
  await repo.commitRuleResultSnapshot(
    id: job.id,
    ruleResultJson: jsonEncode({'payment_method': '候选支付方式'}),
    snapshot: const BillingRuleExecutionSnapshot(
      rulePackageVersion: 12,
      rulesVersion: 'rules-2',
      normalizationVersion: 2,
      personalRulesRevision: 37,
    ),
  );
  return (await repo.findById(job.id))!;
}

BillingRuleSet _ruleSet({String paymentMethod = '候选支付方式'}) => BillingRuleSet(
      schemaVersion: 1,
      rulePackageVersion: 12,
      rulesVersion: 'rules-2+personal-37',
      normalizationVersion: 2,
      paymentChannels: const [],
      templates: [
        BillingRuleTemplate(
          id: 'receipt',
          match: const BillingRuleTemplateMatch(keywordsAll: ['账单']),
          extractors: [
            BillingFieldExtractorRule(
              field: 'paymentMethod',
              type: BillingRuleExtractorTypes.constant,
              value: paymentMethod,
            ),
          ],
        ),
      ],
    );
