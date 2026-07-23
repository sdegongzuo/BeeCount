import 'package:beecount/services/billing/payment_method_semantics.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_quadrant_evaluator.dart';
import 'package:beecount/services/billing/rules/normalization_upgrade_coordinator.dart';
import 'package:beecount/services/billing/rules/normalization_upgrade_journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NormalizationUpgradeCoordinator.prepare', () {
    test('runs four quadrants then prepares every expected revision', () async {
      final store = _RecordingExpectedRevisionStore();
      final result = await NormalizationUpgradeCoordinator(
        expectedRevisionStore: store,
      ).prepare(
        request: NormalizationUpgradePreparationRequest(
          migrationDecisionId: 'migration-2',
          changeKind: BillingRuleChangeKind.ruleAndNormalization,
          currentRuleSet: _ruleSet('rules-1', 1, '旧值'),
          candidateRuleSet: _ruleSet('rules-2', 2, '候选值'),
          currentSemantics: const PaymentMethodSemantics(),
          candidateSemantics: const _MappingSemantics({
            '旧值': '归一化旧值',
          }),
          ocrText: '账单',
          expectedRevisions: const [
            NormalizationExpectedRevisionDraft(
              sampleId: 'sample-1',
              expectedFields: {'paymentMethod': '候选值'},
            ),
            NormalizationExpectedRevisionDraft(
              sampleId: 'sample-2',
              expectedFields: {'paymentMethod': '归一化旧值'},
              derivedFromRevisionId: 'revision-old',
            ),
          ],
          gates: const NormalizationUpgradeGateResults.passed(),
        ),
      );

      expect(result.status, NormalizationUpgradePreparationStatus.prepared);
      expect(result.quadrants?.a.result.paymentMethod, '旧值');
      expect(result.quadrants?.b.result.paymentMethod, '候选值');
      expect(result.quadrants?.c.result.paymentMethod, '归一化旧值');
      expect(result.quadrants?.d.result.paymentMethod, '候选值');
      expect(store.prepared.map((item) => item.sampleId),
          ['sample-1', 'sample-2']);
      expect(store.prepared.every((item) => item.normalizationVersion == 2),
          isTrue);
    });

    test('does not write revisions when any required gate fails', () async {
      final store = _RecordingExpectedRevisionStore();
      final result = await NormalizationUpgradeCoordinator(
        expectedRevisionStore: store,
      ).prepare(
        request: NormalizationUpgradePreparationRequest(
          migrationDecisionId: 'migration-2',
          changeKind: BillingRuleChangeKind.normalization,
          currentRuleSet: _ruleSet('rules-1', 1, '旧值'),
          candidateRuleSet: _ruleSet('rules-1', 2, '旧值'),
          currentSemantics: const PaymentMethodSemantics(),
          candidateSemantics: const _MappingSemantics({'旧值': '归一化旧值'}),
          ocrText: '账单',
          expectedRevisions: const [
            NormalizationExpectedRevisionDraft(
              sampleId: 'sample-1',
              expectedFields: {'paymentMethod': '归一化旧值'},
            ),
          ],
          gates: const NormalizationUpgradeGateResults(
            coveragePassed: true,
            publicRegressionPassed: true,
            personalRegressionPassed: false,
            performancePassed: true,
          ),
        ),
      );

      expect(
        result.status,
        NormalizationUpgradePreparationStatus.gateRejected,
      );
      expect(result.failedGates, ['personalRegression']);
      expect(store.prepared, isEmpty);
    });

    test('rejects a D-only interaction before preparing revisions', () async {
      final store = _RecordingExpectedRevisionStore();
      final result = await NormalizationUpgradeCoordinator(
        expectedRevisionStore: store,
      ).prepare(
        request: NormalizationUpgradePreparationRequest(
          migrationDecisionId: 'migration-2',
          changeKind: BillingRuleChangeKind.ruleAndNormalization,
          currentRuleSet: _ruleSet('rules-1', 1, '旧值'),
          candidateRuleSet: _ruleSet('rules-2', 2, '候选值'),
          currentSemantics: const PaymentMethodSemantics(),
          candidateSemantics: const _MappingSemantics({
            '旧值': '正常值',
            '候选值': '组合异常值',
          }),
          ocrText: '账单',
          expectedRevisions: const [],
          gates: const NormalizationUpgradeGateResults.passed(),
        ),
      );

      expect(
        result.status,
        NormalizationUpgradePreparationStatus.interactionRejected,
      );
      expect(store.prepared, isEmpty);
    });
  });

  group('NormalizationUpgradeCoordinator activation', () {
    test('switches rules and expected revisions as one committed transition',
        () async {
      final expectedStore = _RecordingExpectedRevisionStore(activeVersion: 1);
      final journal = _MemoryJournalStore();
      final current = _ruleSet('rules-1', 1, '旧值');
      final candidate = _ruleSet('rules-2', 2, '候选值');
      final controller =
          _RuleController(current: current, candidate: candidate);
      final coordinator = NormalizationUpgradeCoordinator(
        expectedRevisionStore: expectedStore,
        journalStore: journal,
      );
      final preparation = await coordinator.prepare(
        request: _preparationRequest(current, candidate),
      );

      final result = await coordinator.activatePrepared(
        preparation: preparation,
        ruleController: controller,
      );

      expect(result.status, NormalizationUpgradeActivationStatus.activated);
      expect(controller.active, same(candidate));
      expect(expectedStore.activeVersion, 2);
      expect(expectedStore.previousVersion, 1);
      expect(
          journal.value?.state, NormalizationUpgradeActivationState.committed);
    });

    test('failed expected activation restores both old active pointers',
        () async {
      final expectedStore = _RecordingExpectedRevisionStore(
        activeVersion: 1,
        failActivation: true,
      );
      final journal = _MemoryJournalStore();
      final current = _ruleSet('rules-1', 1, '旧值');
      final candidate = _ruleSet('rules-2', 2, '候选值');
      final controller =
          _RuleController(current: current, candidate: candidate);
      final coordinator = NormalizationUpgradeCoordinator(
        expectedRevisionStore: expectedStore,
        journalStore: journal,
      );
      final preparation = await coordinator.prepare(
        request: _preparationRequest(current, candidate),
      );

      final result = await coordinator.activatePrepared(
        preparation: preparation,
        ruleController: controller,
      );

      expect(result.status, NormalizationUpgradeActivationStatus.restored);
      expect(controller.active, same(current));
      expect(expectedStore.activeVersion, 1);
      expect(
          journal.value?.state, NormalizationUpgradeActivationState.committed);
    });

    test('recovery completes expected activation after the rule switch',
        () async {
      final expectedStore = _RecordingExpectedRevisionStore(activeVersion: 1);
      final journal = _MemoryJournalStore();
      final current = _ruleSet('rules-1', 1, '旧值');
      final candidate = _ruleSet('rules-2', 2, '候选值');
      final controller = _RuleController(current: current, candidate: candidate)
        ..active = candidate;
      journal.value = NormalizationUpgradeJournal(
        state: NormalizationUpgradeActivationState.ruleSwitched,
        operation: NormalizationUpgradeOperation.activate,
        migrationDecisionId: 'migration-2',
        currentRulePackageVersion: current.rulePackageVersion,
        currentRulesVersion: current.rulesVersion,
        currentNormalizationVersion: current.normalizationVersion,
        candidateRulePackageVersion: candidate.rulePackageVersion,
        candidateRulesVersion: candidate.rulesVersion,
        candidateNormalizationVersion: candidate.normalizationVersion,
      );
      final coordinator = NormalizationUpgradeCoordinator(
        expectedRevisionStore: expectedStore,
        journalStore: journal,
      );
      await expectedStore.prepareExpectedRevision(
        sampleId: 'sample-1',
        normalizationVersion: 2,
        expectedFields: const {'paymentMethod': '候选值'},
        migrationDecisionId: 'migration-2',
      );

      final result = await coordinator.recover(ruleController: controller);

      expect(result.status, NormalizationUpgradeActivationStatus.recovered);
      expect(controller.active, same(candidate));
      expect(expectedStore.activeVersion, 2);
      expect(
          journal.value?.state, NormalizationUpgradeActivationState.committed);
    });

    test('one-step rollback restores previous rules and normalization',
        () async {
      final expectedStore = _RecordingExpectedRevisionStore(
        activeVersion: 2,
        previousVersion: 1,
      );
      final current = _ruleSet('rules-1', 1, '旧值');
      final candidate = _ruleSet('rules-2', 2, '候选值');
      final controller = _RuleController(current: current, candidate: candidate)
        ..active = candidate;
      final coordinator = NormalizationUpgradeCoordinator(
        expectedRevisionStore: expectedStore,
      );

      final result = await coordinator.rollback(ruleController: controller);

      expect(result.status, NormalizationUpgradeActivationStatus.rolledBack);
      expect(controller.active, same(current));
      expect(expectedStore.activeVersion, 1);
      expect(expectedStore.previousVersion, 2);
    });
  });
}

NormalizationUpgradePreparationRequest _preparationRequest(
  BillingRuleSet current,
  BillingRuleSet candidate,
) =>
    NormalizationUpgradePreparationRequest(
      migrationDecisionId: 'migration-2',
      changeKind: BillingRuleChangeKind.ruleAndNormalization,
      currentRuleSet: current,
      candidateRuleSet: candidate,
      currentSemantics: const PaymentMethodSemantics(),
      candidateSemantics: const _MappingSemantics({'旧值': '归一化旧值'}),
      ocrText: '账单',
      expectedRevisions: const [
        NormalizationExpectedRevisionDraft(
          sampleId: 'sample-1',
          expectedFields: {'paymentMethod': '候选值'},
        ),
      ],
      gates: const NormalizationUpgradeGateResults.passed(),
    );

class _MappingSemantics extends PaymentMethodSemantics {
  final Map<String, String> replacements;

  const _MappingSemantics(this.replacements);

  @override
  PaymentMethodNormalizationResult canonicalize(String? input) {
    final replacement = replacements[input];
    return replacement == null
        ? super.canonicalize(input)
        : PaymentMethodNormalizationResult.normalized(replacement);
  }
}

class _PreparedCall {
  final String sampleId;
  final int normalizationVersion;

  const _PreparedCall(this.sampleId, this.normalizationVersion);
}

class _RecordingExpectedRevisionStore
    implements RegressionExpectedRevisionStore {
  final List<_PreparedCall> prepared = [];
  int? activeVersion;
  int? previousVersion;
  String? decisionId;
  final bool failActivation;

  _RecordingExpectedRevisionStore({
    this.activeVersion,
    this.previousVersion,
    this.failActivation = false,
  });

  @override
  Future<RegressionExpectedRevision> prepareExpectedRevision({
    required String sampleId,
    required int normalizationVersion,
    required Map<String, Object?> expectedFields,
    required String migrationDecisionId,
    String? derivedFromRevisionId,
  }) async {
    prepared.add(_PreparedCall(sampleId, normalizationVersion));
    return RegressionExpectedRevision(
      revisionId: 'revision-$sampleId',
      sampleId: sampleId,
      normalizationVersion: normalizationVersion,
      migrationDecisionId: migrationDecisionId,
      state: RegressionExpectedRevisionState.prepared,
      derivedFromRevisionId: derivedFromRevisionId,
    );
  }

  @override
  Future<RegressionExpectedActivationResult> activateExpectedRevisions({
    required int normalizationVersion,
    required String migrationDecisionId,
  }) async {
    if (failActivation) throw StateError('activation failed');
    final old = activeVersion;
    previousVersion = old;
    activeVersion = normalizationVersion;
    decisionId = migrationDecisionId;
    return RegressionExpectedActivationResult(
      activeNormalizationVersion: normalizationVersion,
      previousNormalizationVersion: old,
      activatedRevisionCount: prepared.length,
    );
  }

  @override
  Future<RegressionExpectedActivationResult> rollbackExpectedRevisions() async {
    final target = previousVersion;
    if (target == null) throw StateError('no rollback');
    final old = activeVersion;
    activeVersion = target;
    previousVersion = old;
    return RegressionExpectedActivationResult(
      activeNormalizationVersion: target,
      previousNormalizationVersion: old,
      activatedRevisionCount: prepared.length,
    );
  }

  @override
  Future<RegressionExpectedActivationState>
      readExpectedActivationState() async => RegressionExpectedActivationState(
            activeNormalizationVersion: activeVersion,
            previousNormalizationVersion: previousVersion,
            migrationDecisionId: decisionId,
          );
}

class _MemoryJournalStore implements NormalizationUpgradeJournalPersistence {
  NormalizationUpgradeJournal? value;

  @override
  Future<NormalizationUpgradeJournal?> read() async => value;

  @override
  Future<void> write(NormalizationUpgradeJournal journal) async {
    value = journal;
  }
}

class _RuleController implements NormalizationRuleActivationController {
  final BillingRuleSet current;
  final BillingRuleSet candidate;
  late BillingRuleSet active = current;

  _RuleController({required this.current, required this.candidate});

  @override
  Future<void> activateCandidate(BillingRuleSet candidate) async {
    active = candidate;
  }

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async => active;

  @override
  Future<void> rollbackToPrevious() async {
    active = identical(active, candidate) ? current : candidate;
  }
}

BillingRuleSet _ruleSet(
  String rulesVersion,
  int normalizationVersion,
  String paymentMethod,
) =>
    BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: rulesVersion,
      normalizationVersion: normalizationVersion,
      paymentChannels: const [],
      templates: [
        BillingRuleTemplate(
          id: rulesVersion,
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
