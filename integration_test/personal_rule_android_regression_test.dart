import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/pending_bill_confirmation_service.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/platform/screenshot_source_info.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 待确认校正原子启用后下一张相似分享使用活动个人规则', (tester) async {
    const encryptedStore = RegressionSampleStore();
    final runMarker = 'android-${DateTime.now().microsecondsSinceEpoch}';
    for (var index = 0; index < 500; index++) {
      await encryptedStore.save(RegressionSampleDraft(
        normalizedOcr: '$runMarker-$index\n实付金额\n18.50',
        expectedFields: const {'amount': 18.5},
        sensitiveEvidence: const {'source_package': 'android.share.test'},
        structureDescriptor: '$runMarker-$index',
        protection: RegressionSampleProtection.none,
      ));
    }

    final source = _RunSamples(
      const PlatformPersonalRuleRegressionSampleSource(encryptedStore),
      runMarker,
    );
    final elapsed = <int>[];
    for (var run = 0; run < 20; run++) {
      elapsed.add(await _runProductionSeam(source, runMarker, run));
    }
    elapsed.sort();
    final p95Micros = elapsed[18];
    final worstMicros = elapsed.last;
    // ignore: avoid_print
    print('ANDROID_PERSONAL_RULE_PERF runs=20 count=500 '
        'p95Ms=${p95Micros / 1000} worstMs=${worstMicros / 1000}');
    expect(p95Micros, lessThanOrEqualTo(500000));
    expect(worstMicros, lessThanOrEqualTo(1000000));
  });
}

Future<int> _runProductionSeam(
    _RunSamples source, String runMarker, int run) async {
  final db = BeeDatabase.forTesting(NativeDatabase.memory());
  try {
    final revisions = SqlitePersonalRuleRevisionStore(db);
    final lifecycle =
        await BillingJobService.createProductionPersonalRuleLifecycle(
      db,
      publicRuleRepository: const _Rules(_publicRules),
      regressionSamples: source,
    );
    final jobs = LocalBillingJobRepository(db);
    final confirmation = PendingBillConfirmationService(
      repo: jobs,
      createTransaction: (_, {required ledgerId}) async => 1000 + run,
      applyCorrection: lifecycle.applyCorrection,
    );
    final learnedJob = await _awaitingJob(jobs,
        imagePath: '/android/$runMarker-learn-$run.png',
        rawText: '$runMarker-new\n实付金额\n18.50');
    final watch = Stopwatch()..start();
    final learned = await confirmation.confirm(
      jobId: learnedJob.id,
      amount: 18.5,
      time: DateTime(2026, 7, 12, 11),
      supplementalNote: '',
      rememberForSimilarBills: true,
    );
    watch.stop();
    expect(
        learned.ruleResults.single.status, PersonalRuleLifecycleStatus.enabled);
    expect(
        await revisions.activeVersion(), learned.ruleResults.single.revision);
    expect(source.lastBatch.samples, hasLength(500));
    expect(source.lastBatch.keyUnwrapCount, 1);

    final productionRules = BillingJobService.createProductionRuleService(db,
        publicRuleRepository: const _Rules(_publicRules));
    final future = await productionRules.evaluate(
        baseResult: OcrResult(
            rawText: '$runMarker-future\n实付金额\n29.90',
            allNumbers: const ['29.90']),
        sourceInfo: const ScreenshotSourceInfo(
            packageName: 'android.share.test',
            appName: 'Android Share Test',
            confidence: 1,
            method: 'integration_test'));
    expect(future.result.amount, 29.9);
    expect(
        future.result.billingRuleTrace?.matchedRules,
        contains(predicate<Map<String, dynamic>>(
            (rule) => rule['origin'] == BillingRuleOrigin.personal.name)));

    if (run == 0) {
      final active = await revisions.activeVersion();
      final revisionsBefore = await _revisionCount(db);
      final currentOnlyJob = await _awaitingJob(jobs,
          imagePath: '/android/$runMarker-current-only.png',
          rawText: '$runMarker-current\n实付金额\n31.20');
      final currentOnly = await confirmation.confirm(
          jobId: currentOnlyJob.id,
          amount: 31.2,
          time: DateTime(2026, 7, 12, 11),
          supplementalNote: '',
          rememberForSimilarBills: false);
      expect(currentOnly.ruleResults, isEmpty);
      expect(await revisions.activeVersion(), active);
      expect(await _revisionCount(db), revisionsBefore);
      await _expectRejectedAndTimedOutSnapshotsStayActive(
          db, jobs, active!, revisionsBefore, runMarker);
    }
    return watch.elapsedMicroseconds;
  } finally {
    await db.close();
  }
}

Future<int> _revisionCount(BeeDatabase db) async => (await db
        .customSelect('SELECT COUNT(*) AS count FROM personal_rule_revisions')
        .getSingle())
    .read<int>('count');

Future<void> _expectRejectedAndTimedOutSnapshotsStayActive(
  BeeDatabase db,
  BillingJobRepository jobs,
  int activeVersion,
  int revisionCount,
  String runMarker,
) async {
  final rejectedSource = _FixedSamples([
    DecryptedRegressionSample(
      id: 'rejected',
      normalizedOcr: '实付金额\n12.00',
      expectedFields: const {'amount': 99.0},
      sensitiveEvidence: const {
        'source_package': 'android.failure.test',
        'source_app_name': 'Android Share Test',
      },
      exactFingerprint: 'rejected',
      structureFingerprint: 'rejected',
      protection: RegressionSampleProtection.negative,
      keyVersion: 1,
    ),
  ]);
  final rejectedLifecycle =
      await BillingJobService.createProductionPersonalRuleLifecycle(db,
          publicRuleRepository: const _Rules(_publicRules),
          regressionSamples: rejectedSource);
  final rejected = await _confirmWithLifecycle(
      jobs, rejectedLifecycle, '$runMarker-rejected', 'android.failure.test');
  expect(rejected.ruleResults.single.status,
      PersonalRuleLifecycleStatus.regressionRejected);
  expect(
      await SqlitePersonalRuleRevisionStore(db).activeVersion(), activeVersion);
  expect(await _revisionCount(db), revisionCount);

  final timeoutLifecycle =
      await BillingJobService.createProductionPersonalRuleLifecycle(db,
          publicRuleRepository: const _Rules(_publicRules),
          regressionSamples:
              const _FixedSamples([], delay: Duration(milliseconds: 1001)));
  final timedOut = await _confirmWithLifecycle(
      jobs, timeoutLifecycle, '$runMarker-timeout', 'android.timeout.test');
  expect(timedOut.ruleResults.single.status,
      PersonalRuleLifecycleStatus.pendingValidation);
  expect(
      await SqlitePersonalRuleRevisionStore(db).activeVersion(), activeVersion);
  expect(await _revisionCount(db), revisionCount);
}

Future<PendingBillConfirmationResult> _confirmWithLifecycle(
    BillingJobRepository jobs,
    PersonalRuleLifecycleService lifecycle,
    String marker,
    String sourcePackage) async {
  final job = await _awaitingJob(jobs,
      imagePath: '/android/$marker.png',
      rawText: '$marker\n实付金额\n18.50',
      sourcePackage: sourcePackage);
  return PendingBillConfirmationService(
    repo: jobs,
    createTransaction: (_, {required ledgerId}) async => marker.hashCode,
    applyCorrection: lifecycle.applyCorrection,
  ).confirm(
      jobId: job.id,
      amount: 18.5,
      time: DateTime(2026, 7, 12, 11),
      supplementalNote: '',
      rememberForSimilarBills: true);
}

class _FixedSamples implements PersonalRuleRegressionSampleSource {
  const _FixedSamples(this.samples, {this.delay = Duration.zero});

  final List<DecryptedRegressionSample> samples;
  final Duration delay;

  @override
  Future<RegressionSampleBatch> readBatch() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return RegressionSampleBatch(
      samples: samples,
      unreadableSampleIds: const [],
      keyUnwrapCount: 1,
      timings: const RegressionSampleTimings(
          keyUnwrapMs: 0,
          sampleReadMs: 0,
          decryptMs: 0,
          decodeMs: 0,
          totalMs: 0),
    );
  }
}

Future<BillingJob> _awaitingJob(
  BillingJobRepository jobs, {
  required String imagePath,
  required String rawText,
  String sourcePackage = 'android.share.test',
}) async {
  final job = await jobs.createJob(imagePath: imagePath);
  await jobs.updateSourceInfoJson(
      job.id,
      jsonEncode({
        'sourceAppPackage': sourcePackage,
        'sourceAppName': 'Android Share Test',
      }));
  await jobs.updateRawText(job.id, rawText);
  await jobs.updateFinalResultJson(
    job.id,
    jsonEncode(OcrResult(
      amount: 12,
      time: DateTime(2026, 7, 12, 11),
      rawText: rawText,
      allNumbers: const ['12.00', '18.50'],
    ).toJson()),
  );
  await jobs.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
  return (await jobs.findById(job.id))!;
}

class _RunSamples implements PersonalRuleRegressionSampleSource {
  _RunSamples(this.delegate, this.runMarker);

  final PersonalRuleRegressionSampleSource delegate;
  final String runMarker;
  late RegressionSampleBatch lastBatch;

  @override
  Future<RegressionSampleBatch> readBatch() async {
    final batch = await delegate.readBatch();
    lastBatch = RegressionSampleBatch(
      samples: batch.samples
          .where((sample) => _compatibleSample(sample, runMarker))
          .take(500)
          .toList(growable: false),
      unreadableSampleIds: batch.unreadableSampleIds,
      keyUnwrapCount: batch.keyUnwrapCount,
      timings: batch.timings,
    );
    return lastBatch;
  }
}

bool _compatibleSample(DecryptedRegressionSample sample, String runMarker) =>
    sample.expectedFields['amount'] == 18.5 &&
    sample.sensitiveEvidence['source_package'] == 'android.share.test' &&
    sample.normalizedOcr.startsWith(runMarker) &&
    sample.normalizedOcr.contains('实付金额\n18.50');

const _publicRules = BillingRuleSet(
  schemaVersion: 1,
  rulesVersion: 'android-public',
  paymentChannels: [],
  templates: [],
);

class _Rules implements BillingRuleRepository {
  const _Rules(this.rules);

  final BillingRuleSet rules;

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async => rules;

  @override
  Future<BillingRuleSet> loadBuiltInRuleSet() async => rules;

  @override
  Future<BillingRuleSet?> loadDebugOverrideRuleSet() async => null;

  @override
  Future<void> validateRuleSet(BillingRuleSet ruleSet) async {}
}
