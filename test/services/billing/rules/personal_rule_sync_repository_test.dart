import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/personal_note_preference_store.dart';
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

  test('历史空 syncId 账本首次记住规则时原子回填兼容身份并同步', () async {
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '历史默认账本'),
        );

    await SqlitePersonalCategoryRuleStore(db).remember(
      matchText: '历史商户',
      categorySyncId: 'category-food',
      ledgerId: ledgerId,
    );

    final ledger = await (db.select(db.ledgers)
          ..where((item) => item.id.equals(ledgerId)))
        .getSingle();
    expect(ledger.syncId, ledgerId.toString());
    final pending = (await repository.pendingUpload()).single;
    expect(pending.scopeKey, 'ledger:$ledgerId');
    expect(pending.payload['ledger_sync_id'], ledgerId.toString());
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

  test('同一来源规则的连续及并发本地写入使用持久化单调版本', () async {
    Future<void> save(String id) => repository.saveLocal(PersonalRuleRevision(
          revisionId: id,
          ruleId: 'note:merchant:test',
          originDeviceId: '',
          originVersion: 1,
          kind: PersonalRuleSyncKind.notePreference,
          scopeKey: 'merchant',
          conditionKey: 'test',
          payload: {'suffix': id},
        ));

    await save('local-1');
    await save('local-2');
    await Future.wait([save('local-3'), save('local-4')]);

    final revisions = (await repository.pendingUpload())
        .where((revision) => revision.ruleId == 'note:merchant:test')
        .toList()
      ..sort((a, b) => a.originVersion.compareTo(b.originVersion));
    expect(revisions.map((revision) => revision.originVersion), [1, 2, 3, 4]);
    expect(revisions.map((revision) => revision.originVersion).toSet(),
        hasLength(4));
    await expectLater(
      PersonalRuleSyncService(localDeviceId: await repository.localDeviceId())
          .merge(revisions),
      completes,
    );
  });

  test('同一本地修订重试幂等且不消耗新的单调版本', () async {
    final retried = PersonalRuleRevision(
      revisionId: 'retry-same-revision',
      ruleId: 'note:merchant:retry',
      originDeviceId: '',
      originVersion: 999,
      kind: PersonalRuleSyncKind.notePreference,
      scopeKey: 'merchant',
      conditionKey: 'retry',
      payload: const {'suffix': '工作餐'},
    );
    await repository.saveLocal(retried);
    await repository.saveLocal(retried);
    await repository.saveLocal(PersonalRuleRevision(
      revisionId: 'retry-next-revision',
      ruleId: retried.ruleId,
      originDeviceId: '',
      originVersion: 777,
      kind: retried.kind,
      scopeKey: retried.scopeKey,
      conditionKey: retried.conditionKey,
      payload: const {'suffix': '早餐'},
    ));

    final revisions = (await repository.pendingUpload())
        .where((revision) => revision.ruleId == retried.ruleId)
        .toList()
      ..sort((a, b) => a.originVersion.compareTo(b.originVersion));
    expect(revisions, hasLength(2));
    expect(revisions.map((revision) => revision.originVersion), [1, 2]);
  });

  test('分类和备注真实写路径共享单调版本分配器', () async {
    await SqlitePersonalNotePreferenceStore(db).remember(
      matchText: '天津海河测试餐厅甲',
      supplementalNote: '工作餐',
    );
    await SqlitePersonalNotePreferenceStore(db).remember(
      matchText: '天津海河测试餐厅甲',
      supplementalNote: '早餐',
    );
    final revisions = (await repository.pendingUpload())
        .where((revision) => revision.ruleId == 'note:merchant:天津海河测试餐厅甲')
        .toList()
      ..sort((a, b) => a.originVersion.compareTo(b.originVersion));
    expect(revisions.map((revision) => revision.originVersion), [1, 2]);
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

  test('冲突可查询并由用户选择候选后立即恢复且生成待上传解决修订', () async {
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
    final originals = [
      category('food-revision', 'device-a', 'food'),
      category('travel-revision', 'device-b', 'travel'),
    ];
    await repository.mergeRemote(
      originals,
      localDeviceId: 'local-device',
    );

    final conflicts = await repository.listConflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.matchKey, 'category|global|天津海河测试餐厅甲');
    expect(
      conflicts.single.revisions.map((item) => item.revisionId),
      ['food-revision', 'travel-revision'],
    );

    final resolved = await repository.resolveConflict(
      matchKey: conflicts.single.matchKey,
      chosenRevisionId: 'food-revision',
    );

    expect(resolved.pausedMatchKeys, isEmpty);
    expect((await repository.listConflicts()), isEmpty);
    expect(
      (await SqlitePersonalCategoryRuleStore(db).loadActiveRules())
          .single
          .categorySyncId,
      'food',
    );
    final pending = await repository.pendingUpload();
    expect(pending, hasLength(1));
    expect(
      pending.single.resolvedRevisionIds,
      containsAll(['food-revision', 'travel-revision']),
    );

    final remoteDb = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(remoteDb.close);
    final remoteRepository = PersonalRuleSyncRepository(remoteDb);
    expect(
      (await remoteRepository.mergeRemote(
        originals,
        localDeviceId: 'other-device',
      ))
          .requiresConfirmation,
      isTrue,
    );
    final converged = await remoteRepository.mergeRemote(
      [pending.single],
      localDeviceId: 'other-device',
    );
    expect(converged.pausedMatchKeys, isEmpty);
    expect(
      (await SqlitePersonalCategoryRuleStore(remoteDb).loadActiveRules())
          .single
          .categorySyncId,
      'food',
    );
  });

  test('冲突解决物化失败时不遗留半成品解决修订', () async {
    final revisions = [
      PersonalRuleRevision(
        revisionId: 'atomic-a',
        ruleId: 'atomic-a',
        originDeviceId: 'device-a',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'global',
        conditionKey: '天津海河测试餐厅甲',
        payload: const {
          'match_text': '天津海河测试餐厅甲',
          'category_sync_id': 'daily',
        },
      ),
      PersonalRuleRevision(
        revisionId: 'atomic-b',
        ruleId: 'atomic-b',
        originDeviceId: 'device-b',
        originVersion: 1,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'global',
        conditionKey: '天津海河测试餐厅甲',
        payload: const {
          'match_text': '天津海河测试餐厅甲',
          'category_sync_id': 'food',
        },
      ),
    ];
    await repository.mergeRemote(
      revisions,
      localDeviceId: await repository.localDeviceId(),
    );
    await db.customStatement('''CREATE TRIGGER reject_food_resolution
      BEFORE INSERT ON personal_category_rules
      WHEN NEW.category_sync_id = 'food'
      BEGIN
        SELECT RAISE(ABORT, 'injected materialization failure');
      END''');

    await expectLater(
      repository.resolveConflict(
        matchKey: revisions.first.matchKey,
        chosenRevisionId: 'atomic-b',
      ),
      throwsA(anything),
    );

    expect(await repository.pendingUpload(), isEmpty);
    expect(await repository.listConflicts(), hasLength(1));
  });

  test('远端提取冲突必须先通过本机回归才能由用户采用', () async {
    const template = BillingRuleTemplate(
      id: 'remote-amount',
      match: BillingRuleTemplateMatch(
        sourcePackages: ['com.example.pay'],
        keywordsAll: ['金额'],
      ),
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
      revisionId: 'remote-extraction',
      ruleId: 'remote-amount',
      originDeviceId: 'remote-device',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '["com.example.pay"]',
      conditionKey: '{"required_keywords":["金额"]}',
      payload: {'template': template.toJson()},
    );
    await repository.mergeRemote(
      [remote],
      localDeviceId: await repository.localDeviceId(),
    );

    final conflict = (await repository.listConflicts()).single;
    await expectLater(
      repository.resolveConflict(
        matchKey: conflict.matchKey,
        chosenRevisionId: remote.revisionId,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await repository.listConflicts()), hasLength(1));

    final resolved = await repository.resolveConflict(
      matchKey: conflict.matchKey,
      chosenRevisionId: remote.revisionId,
      regressionGate: (_) async => LocalRegressionVerdict.passed,
    );
    expect(resolved.pausedMatchKeys, isEmpty);
    expect(
      resolved.states.values,
      contains(PersonalRuleRevisionState.active),
    );
  });

  test('冲突监听会在远端合并和本机解决后立即刷新', () async {
    final snapshots = <List<PersonalRuleSyncConflict>>[];
    final subscription = repository.watchConflicts().listen(snapshots.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    await repository.mergeRemote(
      [
        PersonalRuleRevision(
          revisionId: 'watch-a',
          ruleId: 'watch-a',
          originDeviceId: 'device-a',
          originVersion: 1,
          kind: PersonalRuleSyncKind.category,
          scopeKey: 'global',
          conditionKey: '便利店',
          payload: const {
            'match_text': '便利店',
            'category_sync_id': 'daily',
          },
        ),
        PersonalRuleRevision(
          revisionId: 'watch-b',
          ruleId: 'watch-b',
          originDeviceId: 'device-b',
          originVersion: 1,
          kind: PersonalRuleSyncKind.category,
          scopeKey: 'global',
          conditionKey: '便利店',
          payload: const {
            'match_text': '便利店',
            'category_sync_id': 'food',
          },
        ),
      ],
      localDeviceId: await repository.localDeviceId(),
    );

    await expectLater(
      repository.watchConflicts().first,
      completion(hasLength(1)),
    );
    expect(snapshots.last, hasLength(1));
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

  test('远端提取候选全部回归失败时仍暂停运行时并进入用户确认', () async {
    const template = BillingRuleTemplate(
      id: 'rejected-amount',
      match: BillingRuleTemplateMatch(keywordsAll: ['金额']),
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
      revisionId: 'rejected-remote',
      ruleId: template.id,
      originDeviceId: 'old-device',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '[]',
      conditionKey: 'amount-label',
      payload: {'template': template.toJson()},
    );

    final result = await repository.mergeRemote(
      [remote],
      localDeviceId: 'new-device',
      regressionGate: (_) async => LocalRegressionVerdict.rejected,
    );

    expect(result.pausedMatchKeys, [remote.matchKey]);
    final conflicts = await repository.listConflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.revisions.single.revisionId, remote.revisionId);
    final paused = await repository.loadPausedExtractionRuleSet();
    expect(paused.templates.single.id, template.id);
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
