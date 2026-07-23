import '../payment_method_semantics.dart';
import '../regression_sample_store.dart';
import 'billing_rule_models.dart';
import 'billing_rule_quadrant_evaluator.dart';

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
  final String? message;

  const NormalizationUpgradePreparationResult({
    required this.status,
    this.quadrants,
    this.failedGates = const [],
    this.preparedRevisions = const [],
    this.message,
  });

  bool get isPrepared =>
      status == NormalizationUpgradePreparationStatus.prepared;
}

class NormalizationUpgradeCoordinator {
  final RegressionExpectedRevisionStore expectedRevisionStore;
  final BillingRuleQuadrantEvaluator quadrantEvaluator;

  const NormalizationUpgradeCoordinator({
    required this.expectedRevisionStore,
    this.quadrantEvaluator = const BillingRuleQuadrantEvaluator(),
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
    );
  }

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
