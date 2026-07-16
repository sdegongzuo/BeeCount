import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_runtime_evaluator.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late PersonalRuleSyncRepository repository;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = PersonalRuleSyncRepository(db);
  });

  tearDown(() => db.close());

  test('真实分类写路径经待上传载荷在远端物化活动规则且不包含 OCR', () async {
    final ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          syncId: const Value('ledger-sync'),
        ));
    await SqlitePersonalCategoryRuleStore(db).remember(
      matchText: '天津海河测试餐厅甲',
      categorySyncId: 'category-food',
      ledgerId: ledgerId,
    );

    final pending = await repository.pendingUpload();
    expect(pending, hasLength(1));
    expect(pending.single.kind, PersonalRuleSyncKind.category);
    expect(pending.single.originDeviceId, isNotEmpty);
    expect(
        pending.single.toSyncJson(),
        containsPair('payload', {
          'match_text': '天津海河测试餐厅甲',
          'category_sync_id': 'category-food',
          'ledger_sync_id': 'ledger-sync',
        }));
    expect(pending.single.toSyncJson().toString().toLowerCase(),
        isNot(contains('ocr')));

    final remoteDb = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(remoteDb.close);
    await remoteDb.into(remoteDb.ledgers).insert(LedgersCompanion.insert(
          name: '远端测试账本',
          syncId: const Value('ledger-sync'),
        ));
    final wireRevision = PersonalRuleRevision.fromSyncJson(
      Map<String, Object?>.from(pending.single.toSyncJson()),
    );
    final merged = await PersonalRuleSyncRepository(remoteDb).mergeRemote(
      [wireRevision],
      localDeviceId: 'remote-install',
    );
    expect(merged.stateFor(wireRevision.revisionId),
        PersonalRuleRevisionState.active);
    final active =
        await SqlitePersonalCategoryRuleStore(remoteDb).loadActiveRules();
    expect(active, hasLength(1));
    expect(active.single.categorySyncId, 'category-food');
  });

  test('本地修订来源首次落库即固定且读取待上传不会改写', () async {
    final revision = PersonalRuleRevision(
      revisionId: 'immutable-origin',
      ruleId: 'note:merchant:test',
      originDeviceId: '',
      originVersion: 1,
      kind: PersonalRuleSyncKind.notePreference,
      scopeKey: 'merchant',
      conditionKey: 'test',
      payload: const {'suffix': '工作餐'},
    );
    await repository.saveLocal(revision);
    final first = (await repository.pendingUpload()).single;
    final second = (await repository.pendingUpload()).single;
    expect(first.originDeviceId, isNotEmpty);
    expect(second.originDeviceId, first.originDeviceId);
  });

  test('远端合并裁决失败会原子回滚修订与物化状态', () async {
    final remote = PersonalRuleRevision(
      revisionId: 'rollback-remote',
      ruleId: 'amount-rule',
      originDeviceId: 'remote-device',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '[]',
      conditionKey: 'amount',
      payload: const {
        'template': {'id': 'amount-rule'}
      },
    );
    await expectLater(
      repository.mergeRemote(
        [remote],
        localDeviceId: 'local-device',
        regressionGate: (_) async => throw StateError('gate failed'),
      ),
      throwsStateError,
    );
    final rows = await db.customSelect(
        'SELECT revision_id FROM personal_rule_sync_revisions WHERE revision_id = ?',
        variables: [Variable.withString(remote.revisionId)]).get();
    expect(rows, isEmpty);
  });

  test('乱序重复和离线并发下载持久化冲突并暂停真实分类活动状态', () async {
    PersonalRuleRevision category(String id, String device, String target) =>
        PersonalRuleRevision(
          revisionId: id,
          ruleId: 'merchant-coffee',
          originDeviceId: device,
          originVersion: 1,
          kind: PersonalRuleSyncKind.category,
          scopeKey: 'global',
          conditionKey: '天津海河测试餐厅甲',
          payload: {'match_text': '天津海河测试餐厅甲', 'category_sync_id': target},
        );

    await repository.mergeRemote(
      [category('b', 'device-b', 'travel')],
      localDeviceId: 'device-new',
    );
    final result = await repository.mergeRemote(
      [category('a', 'device-a', 'food'), category('b', 'device-b', 'travel')],
      localDeviceId: 'device-new',
    );

    expect(result.requiresConfirmation, isTrue);
    expect(result.stateFor('a'), PersonalRuleRevisionState.conflict);
    expect(result.stateFor('b'), PersonalRuleRevisionState.conflict);
    final pauses = await db
        .customSelect('SELECT match_key FROM personal_rule_sync_pauses')
        .get();
    expect(pauses, hasLength(1));
    expect(
        await SqlitePersonalCategoryRuleStore(db).loadActiveRules(), isEmpty);
  });

  test('新设备提取修订保持待验证且不写入活动快照', () async {
    final remote = PersonalRuleRevision(
      revisionId: 'remote-extraction',
      ruleId: 'amount-rule',
      originDeviceId: 'old-device',
      originVersion: 3,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '["wechat"]',
      conditionKey: 'amount-label',
      payload: const {
        'template': {'id': 'amount-rule'}
      },
    );
    final result = await repository.mergeRemote(
      [remote],
      localDeviceId: 'new-device',
      regressionGate: (_) async => LocalRegressionVerdict.insufficient,
    );
    expect(result.stateFor(remote.revisionId),
        PersonalRuleRevisionState.pendingValidation);
    final active =
        await SqlitePersonalRuleRevisionStore(db).loadActiveRuleSet();
    expect(active.templates, isEmpty);
  });

  test('公共等价归档成为物化抑制状态，远端旧修订重放也不会复活', () async {
    const template = BillingRuleTemplate(
      id: 'archived-amount',
      match: BillingRuleTemplateMatch(keywordsAll: ['账单']),
      extractors: [
        BillingFieldExtractorRule(
          field: 'amount',
          type: 'labelNextLine',
          label: '金额',
          parser: 'amount',
        ),
      ],
    );
    final remote = PersonalRuleRevision(
      revisionId: 'old-remote-revision',
      ruleId: template.id,
      originDeviceId: 'origin-device',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '[]',
      conditionKey: 'amount-label',
      payload: {'template': template.toJson()},
    );
    await repository.mergeRemote(
      [remote],
      localDeviceId: 'origin-device',
    );
    final revisions = SqlitePersonalRuleRevisionStore(db);
    final activeVersion = await revisions.activeVersion();
    expect((await revisions.loadActiveRuleSet()).templates, hasLength(1));
    await revisions.reconcilePublicRules(
      BillingRulePersonalRegressionResult.passed(
        equivalentPersonalRuleIds: [template.id],
        expectedPersonalRulesVersion: activeVersion,
      ),
      publicRulesVersion: 'public-2',
    );
    final resolution = await db
        .customSelect(
          'SELECT resolved_revision_id FROM personal_rule_public_archive_resolutions',
        )
        .getSingle();
    expect(resolution.read<String>('resolved_revision_id'), remote.revisionId);

    final replay = await repository.mergeRemote(
      [remote],
      localDeviceId: 'different-device',
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    );

    expect(replay.stateFor(remote.revisionId),
        PersonalRuleRevisionState.archivedEquivalent);
    expect((await revisions.loadActiveRuleSet()).templates, isEmpty);
  });
}
