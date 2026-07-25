import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('生产活动快照在个人规则启用后改变未来分享且保留公共规则', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final personal = SqlitePersonalRuleRevisionStore(db);
    final service = BillingJobService.createProductionRuleService(
      db,
      publicRuleRepository: const _Rules(_publicRules),
    );

    final publicBefore = await service.evaluate(
      baseResult: OcrResult(
        rawText: '公共账单\n总额\n12.00',
        allNumbers: ['12.00'],
      ),
    );
    expect(publicBefore.result.amount, 12);

    await personal.activate(
      _personalRule,
      expectedActiveVersion: await personal.activeVersion(),
    );

    final futureSimilarShare = await service.evaluate(
      baseResult: OcrResult(
        rawText: '公共账单\n专属金额\n18.50',
        allNumbers: ['18.50'],
      ),
    );
    expect(futureSimilarShare.result.amount, 18.5);
    expect(
      futureSimilarShare.result.billingRuleTrace?.matchedRules,
      contains(predicate<Map<String, dynamic>>(
        (rule) => rule['origin'] == BillingRuleOrigin.personal.name,
      )),
    );

    final publicAfter = await service.evaluate(
      baseResult: OcrResult(
        rawText: '公共账单\n总额\n12.00',
        allNumbers: ['12.00'],
      ),
    );
    expect(publicAfter.result.amount, 12);
  });

  test('同步只物化通过回归的个人提取 revision', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final sync = PersonalRuleSyncRepository(db);
    final active = _syncRevision('active', _personalRule);
    final pending = _syncRevision('pending', _pendingRule);

    await sync.mergeRemote(
      [active],
      localDeviceId: 'new-device',
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    );
    await sync.mergeRemote(
      [active, pending],
      localDeviceId: 'new-device',
      regressionGate: (revision) async => revision.revisionId == 'active'
          ? LocalRegressionVerdict.passed
          : LocalRegressionVerdict.insufficient,
    );

    final repository = ActiveBillingRuleRepository(
      publicRepository: const _Rules(_publicRules),
      loadActivePersonalRules:
          SqlitePersonalRuleRevisionStore(db).loadActiveRuleSet,
    );
    final snapshot = await repository.loadActiveRuleSet();
    expect(snapshot.templates.map((rule) => rule.id),
        containsAll(['public-amount', 'personal-amount']));
    expect(snapshot.templates.map((rule) => rule.id),
        isNot(contains('pending-personal-amount')));
  });

  test('同步冲突会暂停匹配范围并从生产快照移除', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final sync = PersonalRuleSyncRepository(db);
    final first = _syncRevision('conflict-a', _personalRule,
        scopeKey: 'same', conditionKey: 'same');
    final second = _syncRevision('conflict-b', _pendingRule,
        scopeKey: 'same', conditionKey: 'same');

    final result = await sync.mergeRemote(
      [first, second],
      localDeviceId: 'new-device',
      regressionGate: (_) async => LocalRegressionVerdict.insufficient,
    );

    expect(result.pausedMatchKeys, isNotEmpty);
    expect(result.stateFor(first.revisionId),
        PersonalRuleRevisionState.pendingValidation);
    expect(result.stateFor(second.revisionId),
        PersonalRuleRevisionState.pendingValidation);
    final snapshot = await ActiveBillingRuleRepository(
      publicRepository: const _Rules(_publicRules),
      loadActivePersonalRules:
          SqlitePersonalRuleRevisionStore(db).loadActiveRuleSet,
    ).loadActiveRuleSet();
    expect(snapshot.templates.map((rule) => rule.id), ['public-amount']);
  });

  test('提取冲突范围即使公共规则可命中也强制待确认', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final sync = PersonalRuleSyncRepository(db);
    final first = _syncRevision('conflict-public-a', _personalRule,
        scopeKey: 'same', conditionKey: 'same');
    final second = _syncRevision(
      'conflict-public-b',
      _conflictingPersonalRule,
      scopeKey: 'same',
      conditionKey: 'same',
    );
    await sync.mergeRemote(
      [first, second],
      localDeviceId: 'new-device',
      regressionGate: (_) async => LocalRegressionVerdict.insufficient,
    );
    final service = BillingJobService.createProductionRuleService(
      db,
      publicRuleRepository: const _Rules(_publicRules),
    );

    final evaluated = await service.evaluate(
      baseResult: OcrResult(
        rawText: '公共账单\n总额\n12.00\n专属金额\n18.50',
        allNumbers: const ['12.00', '18.50'],
        time: DateTime(2026, 7, 17),
        paymentChannel: '测试',
      ),
    );

    expect(evaluated.result.amount, 12);
    expect(
      evaluated.result.fastBillingRejectReasons,
      contains('sync_extraction_conflict'),
    );
    expect(evaluated.accepted, isFalse);
  });
}

PersonalRuleRevision _syncRevision(
        String revisionId, BillingRuleTemplate template,
        {String? scopeKey, String? conditionKey}) =>
    PersonalRuleRevision(
      revisionId: revisionId,
      ruleId: template.id,
      originDeviceId: 'old-device-$revisionId',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: scopeKey ?? revisionId,
      conditionKey: conditionKey ?? revisionId,
      payload: {'template': template.toJson()},
    );

const _publicRules = BillingRuleSet(
  schemaVersion: 1,
  rulePackageVersion: 2,
  rulesVersion: 'public-test',
  normalizationVersion: 1,
  paymentChannels: [],
  templates: [
    BillingRuleTemplate(
      id: 'public-amount',
      origin: BillingRuleOrigin.public,
      match: BillingRuleTemplateMatch(keywordsAll: ['公共账单']),
      extractors: [
        BillingFieldExtractorRule(
          field: 'amount',
          type: 'labelNextLine',
          label: '总额',
          parser: 'amount',
          confidence: 0.95,
        ),
      ],
    ),
  ],
);

const _personalRule = BillingRuleTemplate(
  id: 'personal-amount',
  origin: BillingRuleOrigin.personal,
  match: BillingRuleTemplateMatch(
    keywordsAll: ['公共账单', '专属金额'],
  ),
  extractors: [
    BillingFieldExtractorRule(
      field: 'amount',
      type: 'labelNextLine',
      label: '专属金额',
      parser: 'amount',
      confidence: 0.99,
    ),
  ],
);

const _pendingRule = BillingRuleTemplate(
  id: 'pending-personal-amount',
  origin: BillingRuleOrigin.personal,
  match: BillingRuleTemplateMatch(keywordsAll: ['待验证金额']),
  extractors: [
    BillingFieldExtractorRule(
      field: 'amount',
      type: 'labelNextLine',
      label: '待验证金额',
      parser: 'amount',
      confidence: 0.99,
    ),
  ],
);

const _conflictingPersonalRule = BillingRuleTemplate(
  id: 'conflicting-personal-amount',
  origin: BillingRuleOrigin.personal,
  match: BillingRuleTemplateMatch(
    keywordsAll: ['公共账单', '专属金额'],
  ),
  extractors: [
    BillingFieldExtractorRule(
      field: 'amount',
      type: 'regex',
      pattern: r'总额\s+(\d+(?:\.\d{1,2})?)',
      parser: 'amount',
      confidence: 0.99,
    ),
  ],
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
