import '../../data/db.dart';
import 'deterministic_bill_enrichment.dart';
import 'rules/personal_rule_sync_repository.dart';
import 'rules/personal_rule_sync_service.dart';
import 'package:uuid/uuid.dart';

abstract class PersonalCategoryRuleStore {
  Future<void> remember({
    required String matchText,
    required String categorySyncId,
    required int? ledgerId,
  });

  Future<List<PersonalCategoryRule>> loadActiveRules();

  Future<bool> isMatchPaused({
    required int ledgerId,
    required String matchText,
  }) async =>
      false;
}

/// 个人分类规则的 SQLite 权威存储。
///
/// 分类引用使用 syncId；ledger_id 为空表示用户明确选择了全局作用域。
class SqlitePersonalCategoryRuleStore implements PersonalCategoryRuleStore {
  final BeeDatabase db;

  const SqlitePersonalCategoryRuleStore(this.db);

  Future<void> _ensureSchema() => db.customStatement('''
    CREATE TABLE IF NOT EXISTS personal_category_rules (
      match_text TEXT NOT NULL,
      category_sync_id TEXT NOT NULL,
      ledger_id INTEGER,
      scope_key TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (match_text, scope_key)
    )
  ''');

  @override
  Future<void> remember({
    required String matchText,
    required String categorySyncId,
    required int? ledgerId,
  }) async {
    final normalized = matchText.trim();
    if (normalized.isEmpty) throw ArgumentError.value(matchText, 'matchText');
    if (categorySyncId.trim().isEmpty) {
      throw ArgumentError.value(categorySyncId, 'categorySyncId');
    }
    await _ensureSchema();
    String? ledgerSyncId;
    if (ledgerId != null) {
      final ledger = await (db.select(db.ledgers)
            ..where((item) => item.id.equals(ledgerId)))
          .getSingleOrNull();
      ledgerSyncId = ledger?.syncId;
      if (ledgerSyncId?.isEmpty == true) ledgerSyncId = null;
    }
    final scopeKey = ledgerId == null
        ? 'global'
        : ledgerSyncId == null
            ? 'local-ledger:$ledgerId'
            : 'ledger:$ledgerSyncId';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.customStatement(
        '''INSERT OR REPLACE INTO personal_category_rules
         (match_text, category_sync_id, ledger_id, scope_key, updated_at)
         VALUES (?, ?, ?, ?, ?)''',
        [normalized, categorySyncId, ledgerId, scopeKey, now],
      );
      if (ledgerId == null || ledgerSyncId != null) {
        await PersonalRuleSyncRepository(db).saveLocal(PersonalRuleRevision(
          revisionId: const Uuid().v4(),
          ruleId: 'category:$scopeKey:$normalized',
          originDeviceId: '',
          originVersion: now,
          kind: PersonalRuleSyncKind.category,
          scopeKey: scopeKey,
          conditionKey: normalized,
          payload: {
            'match_text': normalized,
            'category_sync_id': categorySyncId,
            if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
          },
        ));
      }
    });
  }

  @override
  Future<List<PersonalCategoryRule>> loadActiveRules() async {
    await _ensureSchema();
    final rows = await db.customSelect(
      '''SELECT match_text, category_sync_id, ledger_id
         FROM personal_category_rules ORDER BY updated_at DESC''',
      readsFrom: const {},
    ).get();
    return rows
        .map((row) => PersonalCategoryRule(
              matchText: row.read<String>('match_text'),
              categorySyncId: row.read<String>('category_sync_id'),
              ledgerId: row.readNullable<int>('ledger_id'),
            ))
        .toList(growable: false);
  }

  @override
  Future<bool> isMatchPaused({
    required int ledgerId,
    required String matchText,
  }) =>
      PersonalRuleSyncRepository(db).isCategoryMatchPaused(
        ledgerId: ledgerId,
        matchText: matchText,
      );
}
