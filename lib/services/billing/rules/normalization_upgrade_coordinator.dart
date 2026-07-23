import '../payment_method_semantics.dart';
import '../regression_sample_store.dart';
import 'billing_rule_engine.dart';
import 'billing_rule_models.dart';
import 'billing_rule_quadrant_evaluator.dart';
import 'billing_rule_update_service.dart';
import 'normalization_upgrade_journal.dart';

class NormalizationExpectedRevisionDraft {
  final String sampleId;
  final Map<String, Object?> expectedFields;
  final String? derivedFromRevisionId;

  const NormalizationExpectedRevisionDraft({
    required this.sampleId,
    required this.expectedFields,
    this.derivedFromRevisionId,
  });
}

class NormalizationUpgradeGateResults {
  final bool coveragePassed;
  final bool publicRegressionPassed;
  final bool personalRegressionPassed;
  final bool performancePassed;

  const NormalizationUpgradeGateResults({
    required this.coveragePassed,
    required this.publicRegressionPassed,
    required this.personalRegressionPassed,
    required this.performancePassed,
  });

  const NormalizationUpgradeGateResults.passed()
      : coveragePassed = true,
        publicRegressionPassed = true,
        personalRegressionPassed = true,
        performancePassed = true;

  List<String> get failedGates => [
        if (!coveragePassed) 'coverage',
        if (!publicRegressionPassed) 'publicRegression',
        if (!personalRegressionPassed) 'personalRegression',
        if (!performancePassed) 'performance',
      ];
}

class NormalizationUpgradePreparationRequest {
  final String migrationDecisionId;
  final BillingRuleChangeKind changeKind;
  final BillingRuleSet currentRuleSet;
  final BillingRuleSet candidateRuleSet;
  final PaymentMethodSemantics currentSemantics;
  final PaymentMethodSemantics candidateSemantics;
  final String ocrText;
  final OcrPreprocessResult? preprocessResult;
  final String? sourcePackage;
  final String? sourceAppName;
  final String? sourcePaymentChannel;
  final List<NormalizationExpectedRevisionDraft> expectedRevisions;
  final NormalizationUpgradeGateResults gates;

  const NormalizationUpgradePreparationRequest({
    required this.migrationDecisionId,
    required this.changeKind,
    required this.currentRuleSet,
    required this.candidateRuleSet,
    required this.currentSemantics,
    required this.candidateSemantics,
    required this.ocrText,
    required this.expectedRevisions,
    required this.gates,
    this.preprocessResult,
    this.sourcePackage,
    this.sourceAppName,
    this.sourcePaymentChannel,
  });
}

enum NormalizationUpgradePreparationStatus {
  prepared,
  gateRejected,
  interactionRejected,
  invalidVersionTransition,
  revisionPreparationFailed,
}

class NormalizationUpgradePreparationResult {
  final NormalizationUpgradePreparationStatus status;
  final BillingRuleQuadrantReport? quadrants;
  final List<String> failedGates;
  final List<RegressionExpectedRevision> preparedRevisions;
  final BillingRuleSet? currentRuleSet;
  final BillingRuleSet? candidateRuleSet;
  final String? migrationDecisionId;
  final String? message;

  const NormalizationUpgradePreparationResult({
    required this.status,
    this.quadrants,
    this.failedGates = const [],
    this.preparedRevisions = const [],
    this.currentRuleSet,
    this.candidateRuleSet,
    this.migrationDecisionId,
    this.message,
  });

  bool get isPrepared =>
      status == NormalizationUpgradePreparationStatus.prepared;
}

class NormalizationUpgradeCoordinator {
  final RegressionExpectedRevisionStore expectedRevisionStore;
  final BillingRuleQuadrantEvaluator quadrantEvaluator;
  final NormalizationUpgradeJournalPersistence? journalStore;

  const NormalizationUpgradeCoordinator({
    required this.expectedRevisionStore,
    this.quadrantEvaluator = const BillingRuleQuadrantEvaluator(),
    this.journalStore,
  });

  Future<NormalizationUpgradePreparationResult> prepare({
    required NormalizationUpgradePreparationRequest request,
  }) async {
    final versionError = _validateVersionTransition(request);
    if (versionError != null) {
      return NormalizationUpgradePreparationResult(
        status: NormalizationUpgradePreparationStatus.invalidVersionTransition,
        message: versionError,
      );
    }
    final quadrants = await quadrantEvaluator.evaluate(
      changeKind: request.changeKind,
      currentRuleSet: request.currentRuleSet,
      candidateRuleSet: request.candidateRuleSet,
      currentSemantics: request.currentSemantics,
      candidateSemantics: request.candidateSemantics,
      ocrText: request.ocrText,
      preprocessResult: request.preprocessResult,
      sourcePackage: request.sourcePackage,
      sourceAppName: request.sourceAppName,
      sourcePaymentChannel: request.sourcePaymentChannel,
    );
    if (quadrants.hasInteractionAnomaly) {
      return NormalizationUpgradePreparationResult(
        status: NormalizationUpgradePreparationStatus.interactionRejected,
        quadrants: quadrants,
        failedGates: const ['quadrantInteraction'],
      );
    }
    final failedGates = request.gates.failedGates;
    if (failedGates.isNotEmpty) {
      return NormalizationUpgradePreparationResult(
        status: NormalizationUpgradePreparationStatus.gateRejected,
        quadrants: quadrants,
        failedGates: failedGates,
      );
    }

    final prepared = <RegressionExpectedRevision>[];
    try {
      for (final revision in request.expectedRevisions) {
        prepared.add(
          await expectedRevisionStore.prepareExpectedRevision(
            sampleId: revision.sampleId,
            normalizationVersion: request.candidateRuleSet.normalizationVersion,
            expectedFields: revision.expectedFields,
            migrationDecisionId: request.migrationDecisionId,
            derivedFromRevisionId: revision.derivedFromRevisionId,
          ),
        );
      }
    } catch (error) {
      return NormalizationUpgradePreparationResult(
        status: NormalizationUpgradePreparationStatus.revisionPreparationFailed,
        quadrants: quadrants,
        preparedRevisions: prepared,
        message: error.toString(),
      );
    }
    return NormalizationUpgradePreparationResult(
      status: NormalizationUpgradePreparationStatus.prepared,
      quadrants: quadrants,
      preparedRevisions: prepared,
      currentRuleSet: request.currentRuleSet,
      candidateRuleSet: request.candidateRuleSet,
      migrationDecisionId: request.migrationDecisionId,
    );
  }

  Future<NormalizationUpgradeActivationResult> activatePrepared({
    required NormalizationUpgradePreparationResult preparation,
    required NormalizationRuleActivationController ruleController,
  }) async {
    final current = preparation.currentRuleSet;
    final candidate = preparation.candidateRuleSet;
    final decisionId = preparation.migrationDecisionId;
    final store = journalStore;
    if (!preparation.isPrepared ||
        current == null ||
        candidate == null ||
        decisionId == null ||
        store == null) {
      return const NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.notPrepared,
      );
    }
    var journal = _activationJournal(
      current: current,
      candidate: candidate,
      decisionId: decisionId,
    );
    await store.write(journal);
    try {
      await ruleController.activateCandidate(candidate);
      final activeRules = await ruleController.loadActiveRuleSet();
      if (!_sameRuleIdentity(activeRules, candidate)) {
        throw StateError('活动规则包未切换到候选完整版本');
      }
      journal = journal.copyWith(
        state: NormalizationUpgradeActivationState.ruleSwitched,
      );
      await store.write(journal);
      final activation = await expectedRevisionStore.activateExpectedRevisions(
        normalizationVersion: candidate.normalizationVersion,
        migrationDecisionId: decisionId,
      );
      if (activation.activeNormalizationVersion !=
              candidate.normalizationVersion ||
          activation.activatedRevisionCount !=
              preparation.preparedRevisions.length) {
        throw StateError('expected 修订激活结果与候选准备集不一致');
      }
      journal = journal.copyWith(
        state: NormalizationUpgradeActivationState.normalizationSwitched,
      );
      await store.write(journal);
      await store.write(
        journal.copyWith(
          state: NormalizationUpgradeActivationState.committed,
        ),
      );
      return NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.activated,
        activeNormalizationVersion: activation.activeNormalizationVersion,
        previousNormalizationVersion: activation.previousNormalizationVersion,
      );
    } catch (error) {
      return _restoreAfterActivationFailure(
        journal: journal,
        ruleController: ruleController,
        error: error,
      );
    }
  }

  Future<NormalizationUpgradeActivationResult> recover({
    required NormalizationRuleActivationController ruleController,
  }) async {
    final store = journalStore;
    if (store == null) {
      return const NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.recoveryUnavailable,
      );
    }
    final journal = await store.read();
    if (journal == null ||
        journal.state == NormalizationUpgradeActivationState.committed) {
      return const NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.alreadyConsistent,
      );
    }
    final activeRules = await ruleController.loadActiveRuleSet();
    final expected = await expectedRevisionStore.readExpectedActivationState();
    final rulesAreCandidate = _matchesJournalCandidate(activeRules, journal);
    final rulesAreCurrent = _matchesJournalCurrent(activeRules, journal);
    final expectedIsCandidate = expected.activeNormalizationVersion ==
            journal.candidateNormalizationVersion &&
        expected.migrationDecisionId == journal.migrationDecisionId;
    final expectedIsCurrent = expected.activeNormalizationVersion ==
        journal.currentNormalizationVersion;

    if (rulesAreCandidate && expectedIsCandidate) {
      await store.write(
        journal.copyWith(
          state: NormalizationUpgradeActivationState.committed,
        ),
      );
      return NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.recovered,
        activeNormalizationVersion: expected.activeNormalizationVersion,
        previousNormalizationVersion: expected.previousNormalizationVersion,
      );
    }
    if (rulesAreCandidate && expectedIsCurrent) {
      try {
        final activated = await expectedRevisionStore.activateExpectedRevisions(
          normalizationVersion: journal.candidateNormalizationVersion,
          migrationDecisionId: journal.migrationDecisionId,
        );
        await store.write(
          journal.copyWith(
            state: NormalizationUpgradeActivationState.committed,
          ),
        );
        return NormalizationUpgradeActivationResult(
          status: NormalizationUpgradeActivationStatus.recovered,
          activeNormalizationVersion: activated.activeNormalizationVersion,
          previousNormalizationVersion: activated.previousNormalizationVersion,
        );
      } catch (error) {
        return _restoreAfterActivationFailure(
          journal: journal,
          ruleController: ruleController,
          error: error,
        );
      }
    }
    if (rulesAreCurrent && expectedIsCandidate) {
      final rolledBack =
          await expectedRevisionStore.rollbackExpectedRevisions();
      await store.write(
        journal.copyWith(
          state: NormalizationUpgradeActivationState.committed,
          lastError: '启动恢复：规则仍为旧版本，已回滚 expected 修订。',
        ),
      );
      return NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.restored,
        activeNormalizationVersion: rolledBack.activeNormalizationVersion,
        previousNormalizationVersion: rolledBack.previousNormalizationVersion,
      );
    }
    if (rulesAreCurrent && expectedIsCurrent) {
      await store.write(
        journal.copyWith(
          state: NormalizationUpgradeActivationState.committed,
          lastError: '启动恢复：联合切换尚未开始，继续使用旧活动版本。',
        ),
      );
      return NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.restored,
        activeNormalizationVersion: expected.activeNormalizationVersion,
        previousNormalizationVersion: expected.previousNormalizationVersion,
      );
    }
    return const NormalizationUpgradeActivationResult(
      status: NormalizationUpgradeActivationStatus.inconsistent,
    );
  }

  Future<NormalizationUpgradeActivationResult> rollback({
    required NormalizationRuleActivationController ruleController,
  }) async {
    final before = await expectedRevisionStore.readExpectedActivationState();
    if (before.previousNormalizationVersion == null) {
      return const NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.rollbackUnavailable,
      );
    }
    await ruleController.rollbackToPrevious();
    final rolledBack = await expectedRevisionStore.rollbackExpectedRevisions();
    final activeRules = await ruleController.loadActiveRuleSet();
    if (activeRules.normalizationVersion !=
        rolledBack.activeNormalizationVersion) {
      return NormalizationUpgradeActivationResult(
        status: NormalizationUpgradeActivationStatus.inconsistent,
        activeNormalizationVersion: rolledBack.activeNormalizationVersion,
        previousNormalizationVersion: rolledBack.previousNormalizationVersion,
      );
    }
    return NormalizationUpgradeActivationResult(
      status: NormalizationUpgradeActivationStatus.rolledBack,
      activeNormalizationVersion: rolledBack.activeNormalizationVersion,
      previousNormalizationVersion: rolledBack.previousNormalizationVersion,
    );
  }

  Future<NormalizationUpgradeActivationResult> _restoreAfterActivationFailure({
    required NormalizationUpgradeJournal journal,
    required NormalizationRuleActivationController ruleController,
    required Object error,
  }) async {
    final store = journalStore!;
    await store.write(
      journal.copyWith(
        state: NormalizationUpgradeActivationState.restoring,
        lastError: error.toString(),
      ),
    );
    final expected = await expectedRevisionStore.readExpectedActivationState();
    if (expected.activeNormalizationVersion ==
        journal.candidateNormalizationVersion) {
      await expectedRevisionStore.rollbackExpectedRevisions();
    }
    final activeRules = await ruleController.loadActiveRuleSet();
    if (_matchesJournalCandidate(activeRules, journal)) {
      await ruleController.rollbackToPrevious();
    }
    final restoredRules = await ruleController.loadActiveRuleSet();
    final restoredExpected =
        await expectedRevisionStore.readExpectedActivationState();
    final restored = _matchesJournalCurrent(restoredRules, journal) &&
        restoredExpected.activeNormalizationVersion ==
            journal.currentNormalizationVersion;
    await store.write(
      journal.copyWith(
        state: restored
            ? NormalizationUpgradeActivationState.committed
            : NormalizationUpgradeActivationState.restoring,
        lastError: error.toString(),
      ),
    );
    return NormalizationUpgradeActivationResult(
      status: restored
          ? NormalizationUpgradeActivationStatus.restored
          : NormalizationUpgradeActivationStatus.inconsistent,
      activeNormalizationVersion: restoredExpected.activeNormalizationVersion,
      previousNormalizationVersion:
          restoredExpected.previousNormalizationVersion,
      message: error.toString(),
    );
  }

  NormalizationUpgradeJournal _activationJournal({
    required BillingRuleSet current,
    required BillingRuleSet candidate,
    required String decisionId,
  }) =>
      NormalizationUpgradeJournal(
        state: NormalizationUpgradeActivationState.prepared,
        operation: NormalizationUpgradeOperation.activate,
        migrationDecisionId: decisionId,
        currentRulePackageVersion: current.rulePackageVersion,
        currentRulesVersion: current.rulesVersion,
        currentNormalizationVersion: current.normalizationVersion,
        candidateRulePackageVersion: candidate.rulePackageVersion,
        candidateRulesVersion: candidate.rulesVersion,
        candidateNormalizationVersion: candidate.normalizationVersion,
      );

  bool _sameRuleIdentity(BillingRuleSet left, BillingRuleSet right) =>
      left.rulePackageVersion == right.rulePackageVersion &&
      left.rulesVersion == right.rulesVersion &&
      left.normalizationVersion == right.normalizationVersion;

  bool _matchesJournalCandidate(
    BillingRuleSet rules,
    NormalizationUpgradeJournal journal,
  ) =>
      rules.rulePackageVersion == journal.candidateRulePackageVersion &&
      rules.rulesVersion == journal.candidateRulesVersion &&
      rules.normalizationVersion == journal.candidateNormalizationVersion;

  bool _matchesJournalCurrent(
    BillingRuleSet rules,
    NormalizationUpgradeJournal journal,
  ) =>
      rules.rulePackageVersion == journal.currentRulePackageVersion &&
      rules.rulesVersion == journal.currentRulesVersion &&
      rules.normalizationVersion == journal.currentNormalizationVersion;

  String? _validateVersionTransition(
    NormalizationUpgradePreparationRequest request,
  ) {
    final rulesChanged = request.currentRuleSet.rulesVersion !=
        request.candidateRuleSet.rulesVersion;
    final normalizationChanged = request.currentRuleSet.normalizationVersion !=
        request.candidateRuleSet.normalizationVersion;
    final matchesDeclaration = switch (request.changeKind) {
      BillingRuleChangeKind.rule => rulesChanged && !normalizationChanged,
      BillingRuleChangeKind.normalization =>
        !rulesChanged && normalizationChanged,
      BillingRuleChangeKind.ruleAndNormalization =>
        rulesChanged && normalizationChanged,
    };
    if (!matchesDeclaration) {
      return 'changeKind 与 rulesVersion/normalizationVersion 变化不一致';
    }
    if (!request.candidateRuleSet.supportsNormalizationVersion(
      request.candidateRuleSet.normalizationVersion,
    )) {
      return '候选规则包不支持其候选归一化版本';
    }
    return null;
  }
}

abstract class NormalizationRuleActivationController {
  Future<void> activateCandidate(BillingRuleSet candidate);

  Future<void> rollbackToPrevious();

  Future<BillingRuleSet> loadActiveRuleSet();
}

class BillingRuleUpdateActivationController
    implements NormalizationRuleActivationController {
  final BillingRuleUpdateService updateService;
  final BillingRuleRepository repository;

  const BillingRuleUpdateActivationController({
    required this.updateService,
    required this.repository,
  });

  @override
  Future<void> activateCandidate(BillingRuleSet candidate) async {
    final result = await updateService.checkForUpdate();
    if (result.status != BillingRuleUpdateStatus.activated &&
        result.status != BillingRuleUpdateStatus.alreadyLatest) {
      throw StateError('规则包激活失败：${result.status.name}');
    }
  }

  @override
  Future<BillingRuleSet> loadActiveRuleSet() => repository.loadActiveRuleSet();

  @override
  Future<void> rollbackToPrevious() async {
    final result = await updateService.rollback();
    if (result.status != BillingRuleUpdateStatus.rolledBack) {
      throw StateError('规则包回滚失败：${result.status.name}');
    }
  }
}

enum NormalizationUpgradeActivationStatus {
  activated,
  restored,
  recovered,
  alreadyConsistent,
  rolledBack,
  notPrepared,
  rollbackUnavailable,
  recoveryUnavailable,
  inconsistent,
}

class NormalizationUpgradeActivationResult {
  final NormalizationUpgradeActivationStatus status;
  final int? activeNormalizationVersion;
  final int? previousNormalizationVersion;
  final String? message;

  const NormalizationUpgradeActivationResult({
    required this.status,
    this.activeNormalizationVersion,
    this.previousNormalizationVersion,
    this.message,
  });
}
