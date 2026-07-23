import 'dart:convert';

enum PersonalRuleSyncKind { extraction, category, notePreference }

enum PersonalRuleRevisionState {
  active,
  pendingValidation,
  regressionRejected,
  conflict,
  archivedEquivalent,
  superseded,
  resolved,
}

enum LocalRegressionVerdict { passed, rejected, insufficient }

typedef PersonalRuleRegressionGate = Future<LocalRegressionVerdict> Function(
    PersonalRuleRevision revision);

/// 可跨设备传输的不可变个人规则修订；设备本地 OCR 证据不属于该对象。
class PersonalRuleRevision {
  static const _localEvidenceKeys = {
    'ocr',
    'ocr_text',
    'normalized_ocr',
    'regression_samples',
    'sensitive_evidence',
  };

  final String revisionId;
  final String ruleId;
  final String originDeviceId;
  final int originVersion;
  final int createdNormalizationVersion;
  final PersonalRuleSyncKind kind;
  final String scopeKey;
  final String conditionKey;
  final Map<String, Object?> payload;
  final List<String> resolvedRevisionIds;

  factory PersonalRuleRevision({
    required String revisionId,
    required String ruleId,
    required String originDeviceId,
    required int originVersion,
    int createdNormalizationVersion = 1,
    required PersonalRuleSyncKind kind,
    required String scopeKey,
    required String conditionKey,
    required Map<String, Object?> payload,
    List<String> resolvedRevisionIds = const [],
  }) {
    if (originVersion <= 0) {
      throw ArgumentError.value(originVersion, 'originVersion');
    }
    _validatePayload(payload);
    return PersonalRuleRevision._(
      revisionId: revisionId,
      ruleId: ruleId,
      originDeviceId: originDeviceId,
      originVersion: originVersion,
      createdNormalizationVersion: createdNormalizationVersion,
      kind: kind,
      scopeKey: scopeKey,
      conditionKey: conditionKey,
      payload: _freezeMap(payload),
      resolvedRevisionIds: List.unmodifiable(resolvedRevisionIds),
    );
  }

  const PersonalRuleRevision._({
    required this.revisionId,
    required this.ruleId,
    required this.originDeviceId,
    required this.originVersion,
    required this.createdNormalizationVersion,
    required this.kind,
    required this.scopeKey,
    required this.conditionKey,
    required this.payload,
    required this.resolvedRevisionIds,
  });

  factory PersonalRuleRevision.validated({
    required String revisionId,
    required String ruleId,
    required String originDeviceId,
    required int originVersion,
    int createdNormalizationVersion = 1,
    required PersonalRuleSyncKind kind,
    required String scopeKey,
    required String conditionKey,
    required Map<String, Object?> payload,
    List<String> resolvedRevisionIds = const [],
  }) {
    return PersonalRuleRevision(
      revisionId: revisionId,
      ruleId: ruleId,
      originDeviceId: originDeviceId,
      originVersion: originVersion,
      createdNormalizationVersion: createdNormalizationVersion,
      kind: kind,
      scopeKey: scopeKey,
      conditionKey: conditionKey,
      payload: payload,
      resolvedRevisionIds: resolvedRevisionIds,
    );
  }

  factory PersonalRuleRevision.fromSyncJson(Map<String, Object?> json) {
    final payload = json['payload'];
    if (payload is! Map) throw const FormatException('payload 必须是对象');
    final originDeviceId = json['origin_device_id'];
    if (originDeviceId is! String || originDeviceId.trim().isEmpty) {
      throw const FormatException('origin_device_id 必须是非空字符串');
    }
    final kind = switch (json['kind']) {
      'extraction' => PersonalRuleSyncKind.extraction,
      'category' => PersonalRuleSyncKind.category,
      'note_preference' => PersonalRuleSyncKind.notePreference,
      _ => throw FormatException('未知个人规则类型: ${json['kind']}'),
    };
    return PersonalRuleRevision.validated(
      revisionId: json['revision_id'] as String,
      ruleId: json['rule_id'] as String,
      originDeviceId: originDeviceId,
      originVersion: json['origin_version'] as int,
      createdNormalizationVersion:
          json['created_normalization_version'] as int? ?? 0,
      kind: kind,
      scopeKey: json['scope_key'] as String,
      conditionKey: json['condition_key'] as String,
      payload: payload.map((key, value) => MapEntry(key as String, value)),
      resolvedRevisionIds: (json['resolved_revision_ids'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
    );
  }

  String get matchKey => '${kind.name}|$scopeKey|$conditionKey';

  Map<String, Object?> toSyncJson() {
    _validatePayload(payload);
    return {
      'revision_id': revisionId,
      'rule_id': ruleId,
      'origin_device_id': originDeviceId,
      'origin_version': originVersion,
      'created_normalization_version': createdNormalizationVersion,
      'kind': _kindName(kind),
      'scope_key': scopeKey,
      'condition_key': conditionKey,
      'payload': payload,
      if (resolvedRevisionIds.isNotEmpty)
        'resolved_revision_ids': resolvedRevisionIds,
    };
  }

  static void _validatePayload(Map<String, Object?> payload) {
    void visit(Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();
          if (_localEvidenceKeys.contains(key) || key.contains('ocr')) {
            throw ArgumentError('同步修订不得包含设备本地 OCR 证据: $key');
          }
          visit(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          visit(item);
        }
      }
    }

    visit(payload);
  }
}

class PersonalRuleSyncResult {
  final List<PersonalRuleRevision> revisions;
  final Map<String, PersonalRuleRevisionState> states;
  final List<String> pausedMatchKeys;

  const PersonalRuleSyncResult({
    required this.revisions,
    required this.states,
    required this.pausedMatchKeys,
  });

  PersonalRuleRevisionState? stateFor(String revisionId) => states[revisionId];
  bool get requiresConfirmation => pausedMatchKeys.isNotEmpty;

  Map<String, Object?> toJson() => {
        'revisions': revisions.map((r) => r.toSyncJson()).toList(),
        'states': states.map((key, value) => MapEntry(key, value.name)),
        'paused_match_keys': pausedMatchKeys,
      };
}

/// 合并来自多设备的不可变修订，并将本机回归证据保留在回调边界内。
class PersonalRuleSyncService {
  final String localDeviceId;
  final int currentNormalizationVersion;
  final PersonalRuleRegressionGate? regressionGate;

  const PersonalRuleSyncService({
    required this.localDeviceId,
    this.currentNormalizationVersion = 1,
    this.regressionGate,
  });

  Future<PersonalRuleSyncResult> merge(
      Iterable<PersonalRuleRevision> incoming) async {
    final byId = <String, PersonalRuleRevision>{};
    for (final revision in incoming) {
      revision.toSyncJson();
      final existing = byId[revision.revisionId];
      if (existing != null &&
          jsonEncode(existing.toSyncJson()) !=
              jsonEncode(revision.toSyncJson())) {
        throw StateError('revisionId ${revision.revisionId} 对应多个不可变内容');
      }
      byId[revision.revisionId] = revision;
    }
    final revisions = byId.values.toList()
      ..sort((a, b) => a.revisionId.compareTo(b.revisionId));
    final states = <String, PersonalRuleRevisionState>{};
    final resolvedIds = revisions.expand((r) => r.resolvedRevisionIds).toSet();
    for (final id in resolvedIds) {
      if (byId.containsKey(id)) {
        states[id] = PersonalRuleRevisionState.resolved;
      }
    }

    final newestByOrigin = <(String, String), PersonalRuleRevision>{};
    for (final revision
        in revisions.where((r) => states[r.revisionId] == null)) {
      final key = (revision.originDeviceId, revision.ruleId);
      final current = newestByOrigin[key];
      if (current != null &&
          revision.originVersion == current.originVersion &&
          revision.revisionId != current.revisionId) {
        throw StateError('同一来源规则存在多个 version=${revision.originVersion} 修订');
      }
      if (current == null || revision.originVersion > current.originVersion) {
        newestByOrigin[key] = revision;
      }
    }
    for (final revision
        in revisions.where((r) => states[r.revisionId] == null)) {
      final newest = newestByOrigin[(revision.originDeviceId, revision.ruleId)];
      if (!identical(newest, revision)) {
        states[revision.revisionId] = PersonalRuleRevisionState.superseded;
      }
    }

    final groups =
        <(PersonalRuleSyncKind, String, String), List<PersonalRuleRevision>>{};
    for (final revision
        in revisions.where((r) => states[r.revisionId] == null)) {
      groups.putIfAbsent(
          (revision.kind, revision.scopeKey, revision.conditionKey),
          () => []).add(revision);
    }
    final paused = <String>[];
    for (final entry in groups.entries) {
      final group = entry.value;
      if (group.first.kind == PersonalRuleSyncKind.extraction) {
        await _resolveExtraction(group, states, paused);
      } else {
        _resolvePreference(group, states, paused);
      }
    }
    paused.sort();
    return PersonalRuleSyncResult(
      revisions: List.unmodifiable(revisions),
      states: Map.unmodifiable(states),
      pausedMatchKeys: List.unmodifiable(paused),
    );
  }

  Future<void> _resolveExtraction(
    List<PersonalRuleRevision> group,
    Map<String, PersonalRuleRevisionState> states,
    List<String> paused,
  ) async {
    final verdicts = <String, LocalRegressionVerdict>{};
    for (final revision in group) {
      verdicts[revision.revisionId] =
          revision.createdNormalizationVersion > currentNormalizationVersion
              ? LocalRegressionVerdict.insufficient
              : revision.originDeviceId == localDeviceId
                  ? LocalRegressionVerdict.passed
                  : regressionGate == null
                      ? LocalRegressionVerdict.insufficient
                      : await regressionGate!(revision);
    }
    final payloads = group.map((r) => _canonical(r.payload)).toSet();
    final passed = group
        .where((r) => verdicts[r.revisionId] == LocalRegressionVerdict.passed)
        .toList();
    final insufficient = group
        .where((r) =>
            verdicts[r.revisionId] == LocalRegressionVerdict.insufficient)
        .toList();

    if (payloads.length == 1 && passed.isNotEmpty) {
      states[passed.first.revisionId] = PersonalRuleRevisionState.active;
      for (final revision in group.where((r) => r != passed.first)) {
        states[revision.revisionId] =
            PersonalRuleRevisionState.archivedEquivalent;
      }
      return;
    }
    if (passed.length == 1 && insufficient.isEmpty) {
      states[passed.single.revisionId] = PersonalRuleRevisionState.active;
      for (final revision in group.where((r) => r != passed.single)) {
        states[revision.revisionId] =
            PersonalRuleRevisionState.regressionRejected;
      }
      return;
    }
    for (final revision in group) {
      final verdict = verdicts[revision.revisionId]!;
      states[revision.revisionId] =
          verdict == LocalRegressionVerdict.insufficient
              ? PersonalRuleRevisionState.pendingValidation
              : verdict == LocalRegressionVerdict.rejected
                  ? PersonalRuleRevisionState.regressionRejected
                  : PersonalRuleRevisionState.conflict;
    }
    paused.add(group.first.matchKey);
  }

  void _resolvePreference(
    List<PersonalRuleRevision> group,
    Map<String, PersonalRuleRevisionState> states,
    List<String> paused,
  ) {
    final targets = group.first.kind == PersonalRuleSyncKind.category
        ? group.map((r) => r.payload['category_sync_id']).toSet()
        : group.map((r) => _canonical(r.payload)).toSet();
    if (group.first.kind == PersonalRuleSyncKind.category &&
        targets.any((target) => target is! String || target.isEmpty)) {
      throw const FormatException('个人分类规则必须引用稳定 category_sync_id');
    }
    if (targets.length == 1) {
      states[group.first.revisionId] = PersonalRuleRevisionState.active;
      for (final revision in group.skip(1)) {
        states[revision.revisionId] =
            PersonalRuleRevisionState.archivedEquivalent;
      }
      return;
    }
    for (final revision in group) {
      states[revision.revisionId] = PersonalRuleRevisionState.conflict;
    }
    paused.add(group.first.matchKey);
  }
}

String _kindName(PersonalRuleSyncKind kind) => switch (kind) {
      PersonalRuleSyncKind.extraction => 'extraction',
      PersonalRuleSyncKind.category => 'category',
      PersonalRuleSyncKind.notePreference => 'note_preference',
    };

String _canonical(Map<String, Object?> value) {
  final keys = value.keys.toList()..sort();
  return jsonEncode({for (final key in keys) key: value[key]});
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) =>
    Map.unmodifiable(value.map((key, item) => MapEntry(key, _freeze(item))));

Object? _freeze(Object? value) {
  if (value is Map<String, Object?>) return _freezeMap(value);
  if (value is Map) {
    return Map.unmodifiable(
        value.map((key, item) => MapEntry(key, _freeze(item))));
  }
  if (value is Iterable) return List.unmodifiable(value.map(_freeze));
  return value;
}
