import 'dart:convert';

import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../../platform/screenshot_source_info.dart';
import '../billing_job_runner.dart';
import '../ocr_service.dart';
import '../rules/billing_rule_engine.dart';
import '../rules/billing_rule_models.dart';
import '../rules/billing_rule_repository.dart';
import '../rules/personal_rule_lifecycle_service.dart';

abstract class BillingJobRuleSnapshotSource {
  Future<BillingRuleSet> loadLatest();

  Future<BillingRuleSet?> loadPinned(BillingRuleExecutionSnapshot snapshot);
}

class ActiveBillingJobRuleSnapshotSource
    implements BillingJobRuleSnapshotSource {
  final BillingRuleRepository repository;

  const ActiveBillingJobRuleSnapshotSource(this.repository);

  @override
  Future<BillingRuleSet> loadLatest() => repository.loadActiveRuleSet();

  @override
  Future<BillingRuleSet?> loadPinned(
    BillingRuleExecutionSnapshot snapshot,
  ) async {
    final active = await repository.loadActiveRuleSet();
    return _sameSnapshot(_snapshotOf(active), snapshot) ? active : null;
  }
}

class PersistentBillingJobRuleSnapshotSource
    implements BillingJobRuleSnapshotSource {
  final RuntimeBillingRuleRepository publicRules;
  final SqlitePersonalRuleRevisionStore personalRules;

  const PersistentBillingJobRuleSnapshotSource({
    required this.publicRules,
    required this.personalRules,
  });

  @override
  Future<BillingRuleSet> loadLatest() async => BillingRuleSet.activeSnapshot(
        publicRules: await publicRules.loadActiveRuleSet(),
        personalRules: await personalRules.loadActiveRuleSet(),
      );

  @override
  Future<BillingRuleSet?> loadPinned(
    BillingRuleExecutionSnapshot snapshot,
  ) async {
    final public = await publicRules.loadPublicSnapshot(
      rulePackageVersion: snapshot.rulePackageVersion,
      rulesVersion: snapshot.rulesVersion,
      normalizationVersion: snapshot.normalizationVersion,
    );
    final personal = await personalRules
        .loadRuleSetAtVersion(snapshot.personalRulesRevision);
    if (public == null ||
        personal == null ||
        (personal.templates.isNotEmpty &&
            personal.normalizationVersion != snapshot.normalizationVersion)) {
      return null;
    }
    return BillingRuleSet.activeSnapshot(
      publicRules: public,
      personalRules: personal,
    );
  }
}

class RuleStageProcessor implements StageProcessor {
  final BillingJobRepository repo;
  final BillingJobRuleSnapshotSource snapshots;
  final BillingRuleEngine engine;

  const RuleStageProcessor({
    required this.repo,
    required this.snapshots,
    required this.engine,
  });

  @override
  String get stageName => BillingJobStage.ruleDone;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async {
    if (job.rawText == null || job.rawText!.isEmpty) {
      return const StageResult.failure('ocr_text_missing');
    }
    final pinned = _snapshotFromJob(job);
    if (job.stage == BillingJobStage.ruleDone) {
      if (pinned == null ||
          job.ruleResultJson == null ||
          job.ruleResultJson!.isEmpty ||
          await snapshots.loadPinned(pinned) == null) {
        await ctx.requireOwnedWrite(
          (lease) => repo.migrateUnavailableRuleSnapshotToOcrDone(
            job.id,
            lease: lease,
          ),
        );
        return const StageResult.failure('snapshot_migrated');
      }
      ctx.ocrFields = jsonDecode(job.ruleResultJson!) as Map<String, dynamic>;
      return const StageResult.success();
    }

    final ruleSet = await snapshots.loadLatest();
    final snapshot = _snapshotOf(ruleSet);
    final sourceInfo = ctx.sourceInfo;
    final result = await engine.evaluate(
      ruleSet: ruleSet,
      ocrText: job.rawText!,
      sourcePackage: _sourcePackage(sourceInfo),
      sourceAppName: sourceInfo?.appName,
      sourcePaymentChannel: sourceInfo?.paymentChannel,
    );
    final ocrResult = OcrResult(
      amount: result.amount,
      note: result.note,
      time: result.time,
      rawText: job.rawText!,
      allNumbers: const [],
      paymentMethod: result.paymentMethod,
      paymentChannel: result.paymentChannel,
      counterparty: result.counterparty,
      merchantFullName: result.merchantFullName,
      acquirer: result.acquirer,
      details: result.details,
      billingRuleResult: result,
    );
    final json = jsonEncode(ocrResult.toJson());
    await ctx.requireOwnedWrite(
      (lease) => repo.commitRuleResultSnapshot(
        id: job.id,
        ruleResultJson: json,
        snapshot: snapshot,
        lease: lease,
      ),
    );
    ctx.ocrFields = ocrResult.toJson();
    return const StageResult.success();
  }
}

BillingRuleExecutionSnapshot _snapshotOf(BillingRuleSet rules) {
  final marker = RegExp(r'^(.*)\+personal-(\d+)$').firstMatch(
    rules.rulesVersion,
  );
  return BillingRuleExecutionSnapshot(
    rulePackageVersion: rules.rulePackageVersion,
    rulesVersion: marker?.group(1) ?? rules.rulesVersion,
    normalizationVersion: rules.normalizationVersion,
    personalRulesRevision: int.tryParse(marker?.group(2) ?? '') ?? 0,
  );
}

BillingRuleExecutionSnapshot? _snapshotFromJob(BillingJob job) {
  final package = job.rulePackageVersion;
  final rules = job.rulesVersion;
  final normalization = job.normalizationVersion;
  final personal = job.personalRulesRevision;
  if (package == null ||
      rules == null ||
      normalization == null ||
      personal == null) {
    return null;
  }
  return BillingRuleExecutionSnapshot(
    rulePackageVersion: package,
    rulesVersion: rules,
    normalizationVersion: normalization,
    personalRulesRevision: personal,
  );
}

String? _sourcePackage(ScreenshotSourceInfo? sourceInfo) {
  if (sourceInfo == null) return null;
  return sourceInfo.hasPaymentChannel || sourceInfo.confidence >= 0.75
      ? sourceInfo.packageName
      : null;
}

bool _sameSnapshot(
  BillingRuleExecutionSnapshot left,
  BillingRuleExecutionSnapshot right,
) =>
    left.rulePackageVersion == right.rulePackageVersion &&
    left.rulesVersion == right.rulesVersion &&
    left.normalizationVersion == right.normalizationVersion &&
    left.personalRulesRevision == right.personalRulesRevision;
