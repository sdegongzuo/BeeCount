import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/personal_note_preference_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/personal_rule_lifecycle_service.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PersonalRuleCloudProvider extends BeeCountCloudProvider {
  _PersonalRuleCloudProvider({
    this.pullResult = const BeeCountCloudPullResult(
      changes: [],
      serverCursor: 0,
      hasMore: false,
    ),
  });

  final BeeCountCloudPullResult pullResult;
  final List<Map<String, dynamic>> pushed = [];

  @override
  CloudAuthService get auth => NoopAuthService();

  @override
  CloudStorageService get storage => NoopStorageService();

  @override
  Future<void> pushChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    pushed.addAll(changes);
  }

  @override
  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
  }) async =>
      pullResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实 push 同步提取分类备注修订且载荷不包含完整 OCR', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '同步账本',
            syncId: const Value('ledger-sync-1'),
          ),
        );
    final repository = PersonalRuleSyncRepository(db);
    await repository.saveLocal(PersonalRuleRevision(
      revisionId: 'extract-upload',
      ruleId: _template.id,
      originDeviceId: '',
      originVersion: 1,
      kind: PersonalRuleSyncKind.extraction,
      scopeKey: '["com.example.pay"]',
      conditionKey: 'amount-label',
      payload: {'template': _template.toJson()},
    ));
    await SqlitePersonalCategoryRuleStore(db).remember(
      matchText: '天津海河测试餐厅甲',
      categorySyncId: 'food-sync-id',
      ledgerId: null,
    );
    await SqlitePersonalNotePreferenceStore(db).remember(
      matchText: '天津海河测试餐厅甲',
      supplementalNote: '工作日咖啡',
    );

    final provider = _PersonalRuleCloudProvider();
    final engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: ChangeTracker(db),
      repo: LocalRepository(db),
    );
    final result = await engine.sync(ledgerId: ledgerId.toString());

    final changes = provider.pushed
        .where((change) => change['entity_type'] == 'personal_rule_revision')
        .toList(growable: false);
    expect(changes, hasLength(3));
    expect(result.pushed, 3);
    expect(
      changes.map((change) => (change['payload'] as Map)['kind']).toSet(),
      {'extraction', 'category', 'note_preference'},
    );
    final encoded = jsonEncode(changes).toLowerCase();
    expect(encoded, isNot(contains('ocr_text')));
    expect(encoded, isNot(contains('normalized_ocr')));
    expect(encoded, isNot(contains('regression_samples')));
    expect(await repository.pendingUpload(), isEmpty);
  });

  test('真实 pull 在新设备物化分类备注但保持远端提取规则待验证', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '同步账本',
            syncId: const Value('ledger-sync-1'),
          ),
        );
    final revisions = [
      PersonalRuleRevision(
        revisionId: 'extract-download',
        ruleId: _template.id,
        originDeviceId: 'old-device',
        originVersion: 1,
        kind: PersonalRuleSyncKind.extraction,
        scopeKey: '["com.example.pay"]',
        conditionKey: 'amount-label',
        payload: {'template': _template.toJson()},
      ),
      PersonalRuleRevision(
        revisionId: 'category-download',
        ruleId: 'category:global:天津海河测试餐厅甲',
        originDeviceId: 'old-device',
        originVersion: 2,
        kind: PersonalRuleSyncKind.category,
        scopeKey: 'global',
        conditionKey: '天津海河测试餐厅甲',
        payload: const {
          'match_text': '天津海河测试餐厅甲',
          'category_sync_id': 'food-sync-id',
        },
      ),
      PersonalRuleRevision(
        revisionId: 'note-download',
        ruleId: 'note:merchant:天津海河测试餐厅甲',
        originDeviceId: 'old-device',
        originVersion: 3,
        kind: PersonalRuleSyncKind.notePreference,
        scopeKey: 'merchant',
        conditionKey: '天津海河测试餐厅甲',
        payload: const {'suffix': '工作日咖啡'},
      ),
    ];
    final changes = <BeeCountCloudSyncChange>[
      for (var index = 0; index < revisions.length; index++)
        BeeCountCloudSyncChange(
          changeId: index + 1,
          ledgerId: 'ledger-sync-1',
          entityType: 'personal_rule_revision',
          entitySyncId: revisions[index].revisionId,
          action: 'upsert',
          payload: revisions[index].toSyncJson(),
        ),
    ];
    final provider = _PersonalRuleCloudProvider(
      pullResult: BeeCountCloudPullResult(
        changes: changes,
        serverCursor: changes.length,
        hasMore: false,
      ),
    );
    var regressionGateCalls = 0;
    final engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: ChangeTracker(db),
      repo: LocalRepository(db),
      personalRuleRegressionGate: (_) async {
        regressionGateCalls++;
        return LocalRegressionVerdict.insufficient;
      },
    );

    expect(await engine.replayAllChanges(), 3);
    expect(regressionGateCalls, 1,
        reason: '同一同步页必须批量合并个人修订，不能因分类/备注到达重复跑 500 样本回归');
    expect(
      (await SqlitePersonalRuleRevisionStore(db).loadActiveRuleSet()).templates,
      isEmpty,
    );
    expect(
      await SqlitePersonalCategoryRuleStore(db).loadActiveRules(),
      hasLength(1),
    );
    expect(
      await SqlitePersonalNotePreferenceStore(db).matchingSuffix('天津海河测试餐厅甲'),
      '工作日咖啡',
    );
    final conflicts = await PersonalRuleSyncRepository(db).listConflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.kind, PersonalRuleSyncKind.extraction);
  });
}

const _template = BillingRuleTemplate(
  id: 'sync-amount',
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
