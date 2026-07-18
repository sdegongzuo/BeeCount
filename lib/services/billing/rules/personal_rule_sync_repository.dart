import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/db.dart';
import 'billing_rule_models.dart';
import 'personal_rule_sync_service.dart';

class PersonalRuleSyncConflict {
  final String matchKey;
  final PersonalRuleSyncKind kind;
  final String scopeKey;
  final String conditionKey;
  final List<PersonalRuleRevision> revisions;
  final Map<String, String> categoryNamesBySyncId;

  const PersonalRuleSyncConflict({
    required this.matchKey,
    required this.kind,
    required this.scopeKey,
    required this.conditionKey,
    required this.revisions,
    this.categoryNamesBySyncId = const {},
  });
}

/// 个人规则同步的 SQLite 权威存储。同步修订与设备本地 OCR 样本分表保存。
class PersonalRuleSyncRepository {
  static final Expando<StreamController<void>> _changeControllers =
      Expando<StreamController<void>>('personal-rule-sync-changes');

  final BeeDatabase db;
  final PersonalRuleRegressionGate? conflictResolutionRegressionGate;

  const PersonalRuleSyncRepository(
    this.db, {
    this.conflictResolutionRegressionGate,
  });

  StreamController<void> get _changeController =>
      _changeControllers[db] ??= StreamController<void>.broadcast(sync: true);

  void _notifyChanged() => _changeController.add(null);

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
        '''CREATE TABLE IF NOT EXISTS personal_rule_sync_local_versions (
      rule_id TEXT PRIMARY KEY,
      last_version INTEGER NOT NULL
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
    await db
        .customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_archives (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      public_rules_version TEXT NOT NULL,
      archived_at INTEGER NOT NULL
    )''');
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_public_archive_resolutions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      resolved_revision_id TEXT NOT NULL,
      public_rules_version TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(rule_id, resolved_revision_id, public_rules_version)
    )''');
  }

  Future<void> saveLocal(PersonalRuleRevision revision) async {
    await ensureSchema();
    if (revision.originDeviceId.isNotEmpty) {
      await _insertImmutable(revision, syncState: 'pending_upload');
      return;
    }
    await db.transaction(() async {
      final existing = await db.customSelect(
        'SELECT * FROM personal_rule_sync_revisions WHERE revision_id = ?',
        variables: [Variable.withString(revision.revisionId)],
      ).getSingleOrNull();
      if (existing != null) {
        final stored = _fromRow(existing.data);
        if (stored.ruleId != revision.ruleId ||
            stored.kind != revision.kind ||
            stored.scopeKey != revision.scopeKey ||
            stored.conditionKey != revision.conditionKey ||
            jsonEncode(stored.payload) != jsonEncode(revision.payload) ||
            jsonEncode(stored.resolvedRevisionIds) !=
                jsonEncode(revision.resolvedRevisionIds)) {
          throw StateError('revisionId ${revision.revisionId} 对应多个不可变内容');
        }
        return;
      }
      final deviceId = await localDeviceId();
      final version = await _allocateLocalOriginVersion(
        deviceId: deviceId,
        ruleId: revision.ruleId,
      );
      await _insertImmutable(
        PersonalRuleRevision(
          revisionId: revision.revisionId,
          ruleId: revision.ruleId,
          originDeviceId: deviceId,
          originVersion: version,
          kind: revision.kind,
          scopeKey: revision.scopeKey,
          conditionKey: revision.conditionKey,
          payload: revision.payload,
          resolvedRevisionIds: revision.resolvedRevisionIds,
        ),
        syncState: 'pending_upload',
      );
    });
  }

  Future<int> _allocateLocalOriginVersion({
    required String deviceId,
    required String ruleId,
  }) async {
    final allocated = await db.customSelect(
      'SELECT last_version FROM personal_rule_sync_local_versions WHERE rule_id = ?',
      variables: [Variable.withString(ruleId)],
    ).getSingleOrNull();
    final historical = await db.customSelect(
      '''SELECT MAX(origin_version) AS max_version
         FROM personal_rule_sync_revisions
         WHERE origin_device_id = ? AND rule_id = ?''',
      variables: [Variable.withString(deviceId), Variable.withString(ruleId)],
    ).getSingle();
    final lastAllocated = allocated?.read<int>('last_version') ?? 0;
    final lastHistorical = historical.readNullable<int>('max_version') ?? 0;
    final next =
        (lastAllocated > lastHistorical ? lastAllocated : lastHistorical) + 1;
    await db.customStatement(
      '''INSERT INTO personal_rule_sync_local_versions(rule_id, last_version)
         VALUES (?, ?)
         ON CONFLICT(rule_id) DO UPDATE SET last_version = excluded.last_version''',
      [ruleId, next],
    );
    return next;
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
    final rows = await db.customSelect(
      """SELECT r.* FROM personal_rule_sync_revisions r
             WHERE r.sync_state = 'pending_upload'
               AND NOT EXISTS (
                 SELECT 1 FROM personal_rule_public_archive_resolutions a
                 WHERE a.resolved_revision_id = r.revision_id
               )
             ORDER BY r.revision_id""",
    ).get();
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

  /// 返回当前会暂停自动行为的同步冲突，供手机端审核页面展示。
  Future<List<PersonalRuleSyncConflict>> listConflicts() async {
    await ensureSchema();
    final pauseRows = await db
        .customSelect(
          'SELECT match_key FROM personal_rule_sync_pauses ORDER BY match_key',
        )
        .get();
    if (pauseRows.isEmpty) return const [];
    final paused =
        pauseRows.map((row) => row.read<String>('match_key')).toSet();
    final rows = await db.customSelect(
      '''SELECT r.* FROM personal_rule_sync_revisions r
             JOIN personal_rule_sync_state s ON s.revision_id = r.revision_id
             WHERE s.state IN ('conflict', 'pendingValidation', 'regressionRejected')
             ORDER BY r.revision_id''',
    ).get();
    final grouped = <String, List<PersonalRuleRevision>>{};
    for (final row in rows) {
      final revision = _fromRow(row.data);
      if (paused.contains(revision.matchKey)) {
        grouped.putIfAbsent(revision.matchKey, () => []).add(revision);
      }
    }
    final result = <PersonalRuleSyncConflict>[];
    for (final entry in grouped.entries) {
      final categoryNames = <String, String>{};
      if (entry.value.first.kind == PersonalRuleSyncKind.category) {
        for (final revision in entry.value) {
          final syncId = revision.payload['category_sync_id'];
          if (syncId is! String || categoryNames.containsKey(syncId)) continue;
          final category = await (db.select(db.categories)
                ..where((item) => item.syncId.equals(syncId)))
              .getSingleOrNull();
          if (category != null) categoryNames[syncId] = category.name;
        }
      }
      result.add(PersonalRuleSyncConflict(
        matchKey: entry.key,
        kind: entry.value.first.kind,
        scopeKey: entry.value.first.scopeKey,
        conditionKey: entry.value.first.conditionKey,
        revisions: List.unmodifiable(entry.value),
        categoryNamesBySyncId: Map.unmodifiable(categoryNames),
      ));
    }
    return List.unmodifiable(result);
  }

  /// 监听同步合并或本机裁决造成的冲突列表变化。
  ///
  /// 控制器按数据库实例共享，因此同步引擎和设置页即使使用不同 Repository
  /// 实例，仍能在同一个 App 进程内立即刷新。
  Stream<List<PersonalRuleSyncConflict>> watchConflicts() {
    late final StreamController<List<PersonalRuleSyncConflict>> controller;
    late final StreamSubscription<void> changes;
    var queue = Future<void>.value();

    void scheduleRead() {
      queue = queue.then((_) async {
        final conflicts = await listConflicts();
        if (controller.hasListener) controller.add(conflicts);
      }).catchError((Object error, StackTrace stackTrace) {
        if (controller.hasListener) controller.addError(error, stackTrace);
      });
    }

    controller = StreamController<List<PersonalRuleSyncConflict>>(
      onListen: () {
        changes = _changeController.stream.listen((_) => scheduleRead());
        scheduleRead();
      },
      onCancel: () => changes.cancel(),
    );
    return controller.stream;
  }

  /// 加载当前暂停范围中的提取模板，仅用于判断本次 OCR 是否必须待确认。
  Future<BillingRuleSet> loadPausedExtractionRuleSet() async {
    await ensureSchema();
    final paused = (await db
            .customSelect('SELECT match_key FROM personal_rule_sync_pauses')
            .get())
        .map((row) => row.read<String>('match_key'))
        .toSet();
    if (paused.isEmpty) {
      return const BillingRuleSet(
        schemaVersion: 1,
        rulesVersion: 'sync-paused-empty',
        paymentChannels: [],
        templates: [],
      );
    }
    final rows = await db.customSelect(
      '''SELECT r.* FROM personal_rule_sync_revisions r
             JOIN personal_rule_sync_state s ON s.revision_id = r.revision_id
             WHERE r.kind = 'extraction'
               AND s.state IN ('conflict', 'pendingValidation', 'regressionRejected')''',
    ).get();
    final templates = <BillingRuleTemplate>[];
    for (final row in rows) {
      final revision = _fromRow(row.data);
      if (!paused.contains(revision.matchKey)) continue;
      final raw = revision.payload['template'];
      if (raw is! Map) continue;
      templates.add(BillingRuleTemplate.fromJson(
        Map<String, dynamic>.from(raw),
      ));
    }
    return BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: 'sync-paused',
      paymentChannels: const [],
      templates: List.unmodifiable(templates),
    );
  }

  Future<bool> isCategoryMatchPaused({
    required int ledgerId,
    required String matchText,
  }) async {
    final normalized = matchText.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final ledger = await (db.select(db.ledgers)
          ..where((item) => item.id.equals(ledgerId)))
        .getSingleOrNull();
    final ledgerSyncId = ledger?.syncId?.trim();
    final scopes = <String>{'global', 'local-ledger:$ledgerId'};
    if (ledgerSyncId != null && ledgerSyncId.isNotEmpty) {
      scopes.add('ledger:$ledgerSyncId');
    }
    for (final conflict in await listConflicts()) {
      if (conflict.kind != PersonalRuleSyncKind.category ||
          !scopes.contains(conflict.scopeKey)) {
        continue;
      }
      final raw = conflict.revisions.first.payload['match_text'] as String? ??
          conflict.conditionKey;
      final condition =
          raw.startsWith('merchant:') ? raw.substring('merchant:'.length) : raw;
      if (condition.trim().isNotEmpty &&
          normalized.contains(condition.trim().toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Future<int> countCategoryReferences(String categorySyncId) async {
    await ensureSchema();
    return (await db.customSelect(
      '''SELECT COUNT(*) AS count FROM (
           SELECT scope_key, match_text AS condition_key
             FROM personal_category_rules
            WHERE category_sync_id = ?
           UNION
           SELECT referenced.scope_key, referenced.condition_key
             FROM personal_rule_sync_revisions referenced
            WHERE referenced.kind = 'category'
              AND json_extract(referenced.payload_json, '\$.category_sync_id') = ?
              AND NOT EXISTS (
                SELECT 1
                  FROM personal_rule_sync_revisions resolver,
                       json_each(resolver.resolved_revision_ids_json) resolved
                 WHERE resolved.value = referenced.revision_id
              )
         )''',
      variables: [
        Variable.withString(categorySyncId),
        Variable.withString(categorySyncId),
      ],
    ).getSingle())
        .read<int>('count');
  }

  /// 用新的不可变解决修订迁移分类引用，历史修订保持原文不变。
  Future<void> migrateCategoryReferences({
    required String fromCategorySyncId,
    required String toCategorySyncId,
  }) async {
    await ensureSchema();
    final rows = await db.customSelect(
      '''SELECT referenced.*
             FROM personal_rule_sync_revisions referenced
             WHERE referenced.kind = 'category'
               AND json_extract(referenced.payload_json, '\$.category_sync_id') = ?
               AND NOT EXISTS (
                 SELECT 1
                 FROM personal_rule_sync_revisions resolver,
                      json_each(resolver.resolved_revision_ids_json) resolved
                 WHERE resolved.value = referenced.revision_id
               )
             ORDER BY referenced.revision_id''',
      variables: [Variable.withString(fromCategorySyncId)],
    ).get();
    final groups = <String, List<PersonalRuleRevision>>{};
    for (final row in rows) {
      final revision = _fromRow(row.data);
      groups.putIfAbsent(revision.matchKey, () => []).add(revision);
    }
    var sequence = 0;
    for (final group in groups.values) {
      final chosen = group.last;
      await saveLocal(PersonalRuleRevision(
        revisionId: const Uuid().v4(),
        ruleId: chosen.ruleId,
        originDeviceId: '',
        originVersion: DateTime.now().microsecondsSinceEpoch + sequence++,
        kind: PersonalRuleSyncKind.category,
        scopeKey: chosen.scopeKey,
        conditionKey: chosen.conditionKey,
        payload: {
          ...chosen.payload,
          'category_sync_id': toCategorySyncId,
        },
        resolvedRevisionIds:
            group.map((revision) => revision.revisionId).toList(),
      ));
    }
  }

  /// 用户选择一个候选后生成新的本地不可变解决修订并立即重新物化。
  ///
  /// 新修订保持 `pending_upload`，所以上传到其他设备后会用同一组
  /// `resolvedRevisionIds` 收敛旧冲突。
  Future<PersonalRuleSyncResult> resolveConflict({
    required String matchKey,
    required String chosenRevisionId,
    PersonalRuleRegressionGate? regressionGate,
  }) async {
    final conflicts = await listConflicts();
    PersonalRuleSyncConflict? conflict;
    for (final candidate in conflicts) {
      if (candidate.matchKey == matchKey) {
        conflict = candidate;
        break;
      }
    }
    if (conflict == null) throw StateError('personal_rule_conflict_not_found');
    PersonalRuleRevision? chosen;
    for (final revision in conflict.revisions) {
      if (revision.revisionId == chosenRevisionId) {
        chosen = revision;
        break;
      }
    }
    if (chosen == null) {
      throw StateError('personal_rule_conflict_choice_not_found');
    }
    final selectedConflict = conflict;
    final selectedRevision = chosen;
    final deviceId = await localDeviceId();
    if (selectedRevision.kind == PersonalRuleSyncKind.extraction &&
        selectedRevision.originDeviceId != deviceId) {
      final gate = regressionGate ?? conflictResolutionRegressionGate;
      if (gate == null) {
        throw StateError('personal_rule_extraction_regression_required');
      }
      final verdict = await gate(selectedRevision);
      if (verdict != LocalRegressionVerdict.passed) {
        throw StateError('personal_rule_extraction_regression_not_passed');
      }
    }
    final resolutionId = const Uuid().v4();
    return db.transaction(() async {
      await saveLocal(PersonalRuleRevision(
        revisionId: resolutionId,
        ruleId: selectedRevision.ruleId,
        originDeviceId: '',
        originVersion: DateTime.now().microsecondsSinceEpoch,
        kind: selectedRevision.kind,
        scopeKey: selectedRevision.scopeKey,
        conditionKey: selectedRevision.conditionKey,
        payload: selectedRevision.payload,
        resolvedRevisionIds:
            selectedConflict.revisions.map((item) => item.revisionId).toList(),
      ));
      final stored = (await pendingUpload())
          .singleWhere((revision) => revision.revisionId == resolutionId);
      return mergeRemote(
        [stored],
        localDeviceId: deviceId,
      );
    });
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
    final result = await db.transaction(() async {
      for (final revision in incoming) {
        await _insertImmutable(revision, syncState: 'synced');
      }
      final rows = await db
          .customSelect(
            'SELECT * FROM personal_rule_sync_revisions ORDER BY revision_id',
          )
          .get();
      final all = rows.map((row) => _fromRow(row.data)).toList();
      final archivedRows = await db
          .customSelect(
            'SELECT DISTINCT resolved_revision_id FROM personal_rule_public_archive_resolutions',
          )
          .get();
      final archivedRevisionIds = archivedRows
          .map((row) => row.read<String>('resolved_revision_id'))
          .toSet();
      final eligible = all
          .where(
              (revision) => !archivedRevisionIds.contains(revision.revisionId))
          .toList(growable: false);
      final merged = await PersonalRuleSyncService(
        localDeviceId: localDeviceId,
        regressionGate: regressionGate,
      ).merge(eligible);
      final result = PersonalRuleSyncResult(
        revisions: List.unmodifiable(all),
        states: Map.unmodifiable({
          ...merged.states,
          for (final revision in all)
            if (revision.kind == PersonalRuleSyncKind.extraction &&
                archivedRevisionIds.contains(revision.revisionId))
              revision.revisionId: PersonalRuleRevisionState.archivedEquivalent,
        }),
        pausedMatchKeys: merged.pausedMatchKeys,
      );
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
    _notifyChanged();
    return result;
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
