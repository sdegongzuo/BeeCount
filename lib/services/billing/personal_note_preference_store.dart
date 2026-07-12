import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import 'rules/personal_rule_sync_repository.dart';
import 'rules/personal_rule_sync_service.dart';

class PersonalNotePreference {
  final String scopeKey;
  final String conditionKey;
  final Map<String, Object?> payload;

  const PersonalNotePreference(this.scopeKey, this.conditionKey, this.payload);
}

/// 用户明确选择“对类似账单记住”时保存的确定性备注追加偏好。
class SqlitePersonalNotePreferenceStore {
  final BeeDatabase db;

  const SqlitePersonalNotePreferenceStore(this.db);

  Future<void> remember({
    required String matchText,
    required String supplementalNote,
  }) async {
    final condition = matchText.trim();
    final suffix = supplementalNote.trim();
    if (condition.isEmpty || suffix.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final revision = PersonalRuleRevision(
      revisionId: const Uuid().v4(),
      ruleId: 'note:merchant:$condition',
      originDeviceId: '',
      originVersion: now,
      kind: PersonalRuleSyncKind.notePreference,
      scopeKey: 'merchant',
      conditionKey: condition,
      payload: {'suffix': suffix},
    );
    await db.transaction(() async {
      await db.customStatement(
          '''CREATE TABLE IF NOT EXISTS personal_note_preferences (
        scope_key TEXT NOT NULL, condition_key TEXT NOT NULL, payload_json TEXT NOT NULL,
        revision_id TEXT NOT NULL, PRIMARY KEY(scope_key, condition_key))''');
      await db.customStatement(
        '''INSERT OR REPLACE INTO personal_note_preferences
           (scope_key, condition_key, payload_json, revision_id) VALUES (?, ?, ?, ?)''',
        [
          revision.scopeKey,
          condition,
          jsonEncode(revision.payload),
          revision.revisionId
        ],
      );
      await PersonalRuleSyncRepository(db).saveLocal(revision);
    });
  }

  Future<List<PersonalNotePreference>> loadActive() async {
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_note_preferences (
      scope_key TEXT NOT NULL, condition_key TEXT NOT NULL, payload_json TEXT NOT NULL,
      revision_id TEXT NOT NULL, PRIMARY KEY(scope_key, condition_key))''');
    final rows = await db
        .customSelect(
          'SELECT scope_key, condition_key, payload_json FROM personal_note_preferences',
        )
        .get();
    return rows
        .map((row) => PersonalNotePreference(
              row.read<String>('scope_key'),
              row.read<String>('condition_key'),
              Map<String, Object?>.from(
                  jsonDecode(row.read<String>('payload_json')) as Map),
            ))
        .toList(growable: false);
  }

  Future<String?> matchingSuffix(String? merchant) async {
    final text = merchant?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    final matches = (await loadActive())
        .where((preference) =>
            preference.scopeKey == 'merchant' &&
            text.contains(preference.conditionKey.toLowerCase()))
        .toList()
      ..sort((a, b) => b.conditionKey.length.compareTo(a.conditionKey.length));
    return matches.isEmpty ? null : matches.first.payload['suffix'] as String?;
  }
}
