import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/db.dart';
import 'personal_rule_sync_service.dart';

/// 个人规则同步的 SQLite 权威存储。同步修订与设备本地 OCR 样本分表保存。
class PersonalRuleSyncRepository {
  final BeeDatabase db;

  const PersonalRuleSyncRepository(this.db);

  Future<void> ensureSchema() async {
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_sync_revisions (
      revision_id TEXT PRIMARY KEY,
      rule_id TEXT NOT NULL,
      origin_device_id TEXT,
      origin_version INTEGER NOT NULL,
      kind TEXT NOT NULL,
      scope_key TEXT NOT NULL,
      condition_key TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      resolved_revision_ids_json TEXT NOT NULL DEFAULT '[]',
      sync_state TEXT NOT NULL,
      uploaded_at INTEGER
    )''');
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_sync_metadata (
      singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
      local_device_id TEXT NOT NULL
    )''');
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_sync_state (
      revision_id TEXT PRIMARY KEY,
      state TEXT NOT NULL
    )''');
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_sync_pauses (
      match_key TEXT PRIMARY KEY
    )''');
  }

  Future<void> saveLocal(PersonalRuleRevision revision) async {
    await ensureSchema();
    final immutableRevision = revision.originDeviceId.isEmpty
        ? PersonalRuleRevision(
            revisionId: revision.revisionId,
            ruleId: revision.ruleId,
            originDeviceId: await localDeviceId(),
            originVersion: revision.originVersion,
            kind: revision.kind,
            scopeKey: revision.scopeKey,
            conditionKey: revision.conditionKey,
            payload: revision.payload,
            resolvedRevisionIds: revision.resolvedRevisionIds,
          )
        : revision;
    await _insertImmutable(immutableRevision, syncState: 'pending_upload');
  }

  /// 此安装的稳定来源标识；在修订首次落库前生成，之后绝不改写。
  Future<String> localDeviceId() async {
    await ensureSchema();
    final existing = await db
        .customSelect(
            'SELECT local_device_id FROM personal_rule_sync_metadata WHERE singleton = 1')
        .getSingleOrNull();
    if (existing != null) return existing.read<String>('local_device_id');
    final generated = const Uuid().v4();
    await db.customStatement(
      'INSERT OR IGNORE INTO personal_rule_sync_metadata(singleton, local_device_id) VALUES (1, ?)',
      [generated],
    );
    return (await db
            .customSelect(
                'SELECT local_device_id FROM personal_rule_sync_metadata WHERE singleton = 1')
            .getSingle())
        .read<String>('local_device_id');
  }

  Future<List<PersonalRuleRevision>> pendingUpload() async {
    await ensureSchema();
    final rows = await db
        .customSelect(
          "SELECT * FROM personal_rule_sync_revisions WHERE sync_state = 'pending_upload' ORDER BY revision_id",
        )
        .get();
    final result = <PersonalRuleRevision>[];
    for (final row in rows) {
      var revision = _fromRow(row.data);
      if (revision.originDeviceId.isEmpty) {
        throw StateError('修订 ${revision.revisionId} 缺少不可变 origin_device_id');
      }
      result.add(revision);
    }
    return result;
  }

  Future<void> markUploaded(Iterable<String> revisionIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final id in revisionIds) {
        await db.customStatement(
          "UPDATE personal_rule_sync_revisions SET sync_state = 'synced', uploaded_at = ? WHERE revision_id = ?",
          [now, id],
        );
      }
    });
  }

  Future<PersonalRuleSyncResult> mergeRemote(
    Iterable<PersonalRuleRevision> incoming, {
    required String localDeviceId,
    PersonalRuleRegressionGate? regressionGate,
  }) async {
    await ensureSchema();
    return db.transaction(() async {
      for (final revision in incoming) {
        await _insertImmutable(revision, syncState: 'synced');
      }
      final rows = await db
          .customSelect(
            'SELECT * FROM personal_rule_sync_revisions ORDER BY revision_id',
          )
          .get();
      final all = rows.map((row) => _fromRow(row.data)).toList();
      final result = await PersonalRuleSyncService(
        localDeviceId: localDeviceId,
        regressionGate: regressionGate,
      ).merge(all);
      await db.customStatement('DELETE FROM personal_rule_sync_state');
      await db.customStatement('DELETE FROM personal_rule_sync_pauses');
      for (final entry in result.states.entries) {
        await db.customStatement(
          'INSERT INTO personal_rule_sync_state(revision_id, state) VALUES (?, ?)',
          [entry.key, entry.value.name],
        );
      }
      for (final key in result.pausedMatchKeys) {
        await db.customStatement(
          'INSERT INTO personal_rule_sync_pauses(match_key) VALUES (?)',
          [key],
        );
      }
      await _materializeActivePreferences(result);
      await _materializeActiveExtractionRules(result);
      return result;
    });
  }

  Future<void> _materializeActiveExtractionRules(
      PersonalRuleSyncResult result) async {
    if (!result.revisions
        .any((revision) => revision.kind == PersonalRuleSyncKind.extraction)) {
      return;
    }
    final templates = result.revisions
        .where((revision) =>
            revision.kind == PersonalRuleSyncKind.extraction &&
            result.stateFor(revision.revisionId) ==
                PersonalRuleRevisionState.active)
        .map((revision) => revision.payload['template'])
        .whereType<Map>()
        .map((value) => Map<String, Object?>.from(value))
        .toList(growable: false);
    await db
        .customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_revisions (
      version INTEGER PRIMARY KEY AUTOINCREMENT, rule_json TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_state (
      singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
      active_version INTEGER REFERENCES personal_rule_revisions(version))''');
    await db.customStatement(
      'INSERT INTO personal_rule_revisions(rule_json, created_at) VALUES (?, ?)',
      [jsonEncode(templates), DateTime.now().millisecondsSinceEpoch],
    );
    final version =
        (await db.customSelect('SELECT last_insert_rowid() AS id').getSingle())
            .read<int>('id');
    await db.customStatement(
      '''INSERT INTO personal_rule_state(singleton, active_version) VALUES (1, ?)
         ON CONFLICT(singleton) DO UPDATE SET active_version = excluded.active_version''',
      [version],
    );
  }

  Future<void> _materializeActivePreferences(
      PersonalRuleSyncResult result) async {
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_note_preferences (
      scope_key TEXT NOT NULL, condition_key TEXT NOT NULL, payload_json TEXT NOT NULL,
      revision_id TEXT NOT NULL, PRIMARY KEY(scope_key, condition_key)
    )''');
    await db
        .customStatement('''CREATE TABLE IF NOT EXISTS personal_category_rules (
      match_text TEXT NOT NULL, category_sync_id TEXT NOT NULL, ledger_id INTEGER,
      scope_key TEXT NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (match_text, scope_key))''');
    for (final revision in result.revisions.where(
        (revision) => result.pausedMatchKeys.contains(revision.matchKey))) {
      if (revision.kind == PersonalRuleSyncKind.category) {
        final matchText =
            revision.payload['match_text'] as String? ?? revision.conditionKey;
        await db.customStatement(
          'DELETE FROM personal_category_rules WHERE scope_key = ? AND match_text = ?',
          [revision.scopeKey, matchText],
        );
      } else if (revision.kind == PersonalRuleSyncKind.notePreference) {
        await db.customStatement(
          'DELETE FROM personal_note_preferences WHERE scope_key = ? AND condition_key = ?',
          [revision.scopeKey, revision.conditionKey],
        );
      }
    }
    for (final revision in result.revisions) {
      if (result.stateFor(revision.revisionId) !=
          PersonalRuleRevisionState.active) {
        continue;
      }
      if (revision.kind == PersonalRuleSyncKind.category) {
        final categoryId = revision.payload['category_sync_id'] as String;
        final matchText =
            revision.payload['match_text'] as String? ?? revision.conditionKey;
        final ledgerSyncId = revision.payload['ledger_sync_id'] as String?;
        int? ledgerId;
        if (ledgerSyncId != null) {
          final ledger = await (db.select(db.ledgers)
                ..where((item) => item.syncId.equals(ledgerSyncId)))
              .getSingleOrNull();
          if (ledger == null) continue;
          ledgerId = ledger.id;
        }
        await db.customStatement(
          '''INSERT OR REPLACE INTO personal_category_rules
             (match_text, category_sync_id, ledger_id, scope_key, updated_at)
             VALUES (?, ?, ?, ?, ?)''',
          [
            matchText,
            categoryId,
            ledgerId,
            revision.scopeKey,
            DateTime.now().millisecondsSinceEpoch
          ],
        );
      } else if (revision.kind == PersonalRuleSyncKind.notePreference) {
        await db.customStatement(
          '''INSERT OR REPLACE INTO personal_note_preferences
             (scope_key, condition_key, payload_json, revision_id) VALUES (?, ?, ?, ?)''',
          [
            revision.scopeKey,
            revision.conditionKey,
            jsonEncode(revision.payload),
            revision.revisionId
          ],
        );
      }
    }
  }

  Future<void> _insertImmutable(PersonalRuleRevision revision,
      {required String syncState}) async {
    final json = revision.toSyncJson();
    final existing = await db.customSelect(
      'SELECT * FROM personal_rule_sync_revisions WHERE revision_id = ?',
      variables: [Variable.withString(revision.revisionId)],
    ).getSingleOrNull();
    if (existing != null) {
      final old = _fromRow(existing.data);
      if (jsonEncode(old.toSyncJson()) != jsonEncode(json)) {
        throw StateError('revisionId ${revision.revisionId} 对应多个不可变内容');
      }
      return;
    }
    await db.customStatement(
      '''INSERT INTO personal_rule_sync_revisions
         (revision_id, rule_id, origin_device_id, origin_version, kind, scope_key,
          condition_key, payload_json, resolved_revision_ids_json, sync_state)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        revision.revisionId,
        revision.ruleId,
        revision.originDeviceId,
        revision.originVersion,
        json['kind'],
        revision.scopeKey,
        revision.conditionKey,
        jsonEncode(revision.payload),
        jsonEncode(revision.resolvedRevisionIds),
        syncState
      ],
    );
  }

  PersonalRuleRevision _fromRow(Map<String, Object?> row) =>
      PersonalRuleRevision.fromSyncJson({
        'revision_id': row['revision_id'],
        'rule_id': row['rule_id'],
        'origin_device_id': row['origin_device_id'] ?? '',
        'origin_version': row['origin_version'],
        'kind': row['kind'],
        'scope_key': row['scope_key'],
        'condition_key': row['condition_key'],
        'payload': jsonDecode(row['payload_json'] as String),
        'resolved_revision_ids':
            jsonDecode(row['resolved_revision_ids_json'] as String),
      });
}
