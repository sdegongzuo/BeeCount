import 'package:beecount/services/billing/payment_method_semantics.dart';
import 'package:beecount/services/billing/regression_sample_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_quadrant_evaluator.dart';
import 'package:beecount/services/billing/rules/normalization_upgrade_coordinator.dart';
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
}

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
  }) =>
      throw UnimplementedError();

  @override
  Future<RegressionExpectedActivationResult> rollbackExpectedRevisions() =>
      throw UnimplementedError();
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
