import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import '../../../data/db.dart';
import '../regression_sample_store.dart';
import 'billing_rule_engine.dart';
import 'billing_rule_extractors.dart';
import 'billing_rule_models.dart';
import 'billing_rule_runtime_evaluator.dart';
import 'personal_rule_sync_repository.dart';
import 'personal_rule_sync_service.dart';

/// 真实同步下载路径使用本机加密回归样本裁决远端提取修订。
class PersonalRuleSyncRegressionGate {
  final BillingRuleEngine engine;
  final PersonalRuleRevisionStore revisionStore;
  final PersonalRuleRegressionSampleSource regressionSamples;
  final Future<BillingRuleSet> Function() loadPublicRules;

  const PersonalRuleSyncRegressionGate({
    required this.engine,
    required this.revisionStore,
    required this.regressionSamples,
    required this.loadPublicRules,
  });

  Future<LocalRegressionVerdict> call(PersonalRuleRevision revision) async {
    final rawTemplate = revision.payload['template'];
    if (rawTemplate is! Map) return LocalRegressionVerdict.rejected;
    final candidate =
        BillingRuleTemplate.fromJson(Map<String, dynamic>.from(rawTemplate));
    final batch = await regressionSamples.readBatch();
    if (batch.unreadableSampleIds.isNotEmpty || batch.samples.isEmpty) {
      return LocalRegressionVerdict.insufficient;
    }
    final active = await revisionStore.loadActiveRuleSet();
    final public = await loadPublicRules();
    final snapshot = BillingRuleSet.activeSnapshot(
      publicRules: BillingRuleSet(
        schemaVersion: public.schemaVersion,
        rulesVersion: public.rulesVersion,
        paymentChannels: public.paymentChannels,
        templates: public.templates
            .where((template) => template.id != candidate.id)
            .toList(growable: false),
      ),
      personalRules: BillingRuleSet(
        schemaVersion: public.schemaVersion,
        rulesVersion: 'sync-candidate',
        paymentChannels: const [],
        templates: [
          ...active.templates.where((template) => template.id != candidate.id),
          candidate,
        ],
      ),
    );
    var impacted = 0;
    for (final sample in batch.samples) {
      final source = sample.sensitiveEvidence['source_package'] as String?;
      final appName = sample.sensitiveEvidence['source_app_name'] as String?;
      if (!_canMatch(candidate.match, sample.normalizedOcr, source, appName)) {
        continue;
      }
      impacted++;
      final actual = await engine.evaluate(
        ruleSet: snapshot,
        ocrText: sample.normalizedOcr,
        sourcePackage: source,
        sourceAppName: appName,
      );
      // 回归结论必须来自候选本身。更具体的旧规则或同 ID 旧版本不能
      // 替一个坏候选“通过”门禁；候选未被选中时保持暂停，等待用户处理。
      if (actual.matchedTemplateId != candidate.id ||
          !_preservesExpected(actual, sample.expectedFields)) {
        return LocalRegressionVerdict.rejected;
      }
    }
    return impacted == 0
        ? LocalRegressionVerdict.insufficient
        : LocalRegressionVerdict.passed;
  }
}

/// 个人候选规则经过生命周期门禁后的稳定结果。
enum PersonalRuleLifecycleStatus {
  enabled,
  pendingValidation,
  regressionRejected,
  conflict,
}

/// 一次由用户确认、且等待尝试合成为个人规则的字段校正。
class PersonalRuleCorrection {
  final String field;
  final Object confirmedValue;
  final String normalizedOcr;
  final String? sourcePackage;
  final String? sourceAppName;

  /// 创建字段校正输入；[confirmedValue] 仍会先与 OCR 证据核对。
  const PersonalRuleCorrection({
    required this.field,
    required this.confirmedValue,
    required this.normalizedOcr,
    this.sourcePackage,
    this.sourceAppName,
  });
}

/// 一次个人规则生命周期处理的外部可观察结果。
class PersonalRuleLifecycleResult {
  final PersonalRuleLifecycleStatus status;
  final bool currentBillOnly;
  final BillingRuleTemplate? candidate;
  final int? revision;
  final List<String> impactSampleIds;
  final List<String> excludedSampleIds;

  /// 创建生命周期结果。
  const PersonalRuleLifecycleResult({
    required this.status,
    this.currentBillOnly = false,
    this.candidate,
    this.revision,
    this.impactSampleIds = const [],
    this.excludedSampleIds = const [],
  });
}

/// 为生命周期门禁提供一批本机解密回归样本。
abstract class PersonalRuleRegressionSampleSource {
  /// 每次门禁只读取并解封一批样本。
  Future<RegressionSampleBatch> readBatch();
}

/// 将 Android 加密样本存储适配为生命周期门禁的数据源。
class PlatformPersonalRuleRegressionSampleSource
    implements PersonalRuleRegressionSampleSource {
  final RegressionSampleStore store;

  /// 创建平台样本源。
  const PlatformPersonalRuleRegressionSampleSource(this.store);
  @override
  Future<RegressionSampleBatch> readBatch() => store.readBatch();
}

/// 不可变个人规则修订和活动版本指针的持久化边界。
abstract class PersonalRuleRevisionStore {
  /// 返回当前活动版本；尚无个人规则时返回 null。
  Future<int?> activeVersion();

  /// 读取当前活动个人规则快照。
  Future<BillingRuleSet> loadActiveRuleSet();

  /// 判断候选是否与同作用域活动规则不兼容。
  Future<bool> hasConflict(BillingRuleTemplate candidate);

  /// 仅在活动版本仍等于 [expectedActiveVersion] 时原子启用候选。
  Future<int> activate(
    BillingRuleTemplate candidate, {
    int? expectedActiveVersion,
  });
}

/// 活动版本在回归与指针切换之间发生变化。
class PersonalRuleActivationConflict implements Exception {
  /// 创建并发活动版本冲突。
  const PersonalRuleActivationConflict();
}

/// 编排受约束合成、回归门禁和原子启用的主要功能边界。
class PersonalRuleLifecycleService {
  final BillingRuleEngine engine;
  final PersonalRuleRevisionStore revisionStore;
  final PersonalRuleRegressionSampleSource regressionSamples;
  final BillingRuleSet publicRules;

  /// 创建个人规则生命周期服务。
  const PersonalRuleLifecycleService({
    required this.engine,
    required this.revisionStore,
    required this.regressionSamples,
    required this.publicRules,
  });

  /// 尝试将 [correction] 变为活动个人规则。
  Future<PersonalRuleLifecycleResult> applyCorrection(
      PersonalRuleCorrection correction) async {
    final candidate = _synthesize(correction);
    if (candidate == null) {
      return const PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.pendingValidation,
        currentBillOnly: true,
      );
    }
    if (await revisionStore.hasConflict(candidate)) {
      return PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.conflict,
        currentBillOnly: true,
        candidate: candidate,
      );
    }
    final expectedActiveVersion = await revisionStore.activeVersion();
    final activePersonalRules = await revisionStore.loadActiveRuleSet();

    final corrected = await engine.evaluate(
      ruleSet: _snapshot(activePersonalRules, candidate),
      ocrText: correction.normalizedOcr,
      sourcePackage: correction.sourcePackage,
      sourceAppName: correction.sourceAppName,
    );
    if (!_same(
        _field(corrected, correction.field), correction.confirmedValue)) {
      return PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.pendingValidation,
        currentBillOnly: true,
        candidate: candidate,
      );
    }

    final regressionWatch = Stopwatch()..start();
    final batch = await regressionSamples.readBatch();
    if (batch.unreadableSampleIds.isNotEmpty) {
      return PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.pendingValidation,
        currentBillOnly: true,
        candidate: candidate,
      );
    }
    final impacted = <String>[];
    final excluded = <String>[];
    for (final sample in batch.samples) {
      final source = sample.sensitiveEvidence['source_package'] as String?;
      final sourceAppName =
          sample.sensitiveEvidence['source_app_name'] as String?;
      if (!_canMatch(
          candidate.match, sample.normalizedOcr, source, sourceAppName)) {
        excluded.add(sample.id);
      } else {
        impacted.add(sample.id);
      }
    }
    for (final sample
        in batch.samples.where((item) => impacted.contains(item.id))) {
      final source = sample.sensitiveEvidence['source_package'] as String?;
      final sourceAppName =
          sample.sensitiveEvidence['source_app_name'] as String?;
      final actual = await engine.evaluate(
        ruleSet: _snapshot(activePersonalRules, candidate),
        ocrText: sample.normalizedOcr,
        sourcePackage: source,
        sourceAppName: sourceAppName,
      );
      if (!_preservesExpected(actual, sample.expectedFields)) {
        return PersonalRuleLifecycleResult(
          status: PersonalRuleLifecycleStatus.regressionRejected,
          currentBillOnly: true,
          candidate: candidate,
          impactSampleIds: impacted,
          excludedSampleIds: excluded,
        );
      }
    }
    regressionWatch.stop();
    if (regressionWatch.elapsedMilliseconds > 1000) {
      return PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.pendingValidation,
        currentBillOnly: true,
        candidate: candidate,
        impactSampleIds: impacted,
        excludedSampleIds: excluded,
      );
    }

    int revision;
    try {
      revision = await revisionStore.activate(
        candidate,
        expectedActiveVersion: expectedActiveVersion,
      );
    } on PersonalRuleActivationConflict {
      return PersonalRuleLifecycleResult(
        status: PersonalRuleLifecycleStatus.conflict,
        currentBillOnly: true,
        candidate: candidate,
        impactSampleIds: impacted,
        excludedSampleIds: excluded,
      );
    }
    return PersonalRuleLifecycleResult(
      status: PersonalRuleLifecycleStatus.enabled,
      candidate: candidate,
      revision: revision,
      impactSampleIds: impacted,
      excludedSampleIds: excluded,
    );
  }

  BillingRuleSet _snapshot(
          BillingRuleSet activePersonalRules, BillingRuleTemplate candidate) =>
      BillingRuleSet.activeSnapshot(
        publicRules: publicRules,
        personalRules: BillingRuleSet(
          schemaVersion: publicRules.schemaVersion,
          rulesVersion: 'candidate',
          paymentChannels: const [],
          templates: [...activePersonalRules.templates, candidate],
        ),
      );
}

BillingRuleTemplate? _synthesize(PersonalRuleCorrection correction) {
  final valueText = _valueText(correction.confirmedValue);
  final lines = correction.normalizedOcr
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .toList();
  final valueLine = lines.indexWhere((line) => line.contains(valueText));
  if (valueLine < 0) return null;

  String? type;
  String? label;
  String? pattern;
  if (valueLine > 0 &&
      _safeLabel(lines[valueLine - 1], lines) &&
      _labelFitsField(lines[valueLine - 1], correction.field)) {
    type = BillingRuleExtractorTypes.labelNextLine;
    label = lines[valueLine - 1];
  } else {
    final prefix = lines[valueLine].split(valueText).first.trim();
    if (_safeLabel(prefix, lines) && RegExp(r'[:：]').hasMatch(prefix)) {
      type = BillingRuleExtractorTypes.labelSameLine;
      label = prefix.replaceAll(RegExp(r'[:：\s]+$'), '');
    } else if (correction.confirmedValue is num) {
      final stablePrefix = prefix.replaceAll(RegExp(r'[¥￥\s]+$'), '').trim();
      if (!_safeLabel(stablePrefix, lines)) return null;
      type = BillingRuleExtractorTypes.regex;
      label = stablePrefix;
      pattern = '${RegExp.escape(stablePrefix)}\\s*(?:¥|￥)?\\s*'
          r'([0-9]+(?:\.[0-9]{1,2})?)';
    } else {
      return null;
    }
  }
  final keyword = label;
  final scope = [
    correction.sourcePackage ?? '',
    correction.sourceAppName ?? '',
    keyword,
    correction.field
  ].join('|');
  return BillingRuleTemplate(
    id: 'personal-${_stableHash(scope)}',
    origin: BillingRuleOrigin.personal,
    match: BillingRuleTemplateMatch(
      sourcePackages: correction.sourcePackage == null
          ? const []
          : [correction.sourcePackage!],
      requiredSource: correction.sourcePackage != null,
      appNameKeywords: correction.sourceAppName == null
          ? const []
          : [correction.sourceAppName!],
      keywordsAll: [keyword],
    ),
    extractors: [
      BillingFieldExtractorRule(
        id: 'personal-${_stableHash('$scope|extractor')}',
        field: correction.field,
        type: type,
        label: label,
        pattern: pattern,
        parser: correction.field == 'amount' ? 'amount' : null,
        confidence: 0.95,
      ),
    ],
  );
}

bool _safeLabel(String text, List<String> lines) =>
    text.isNotEmpty &&
    text.length <= 24 &&
    !RegExp(r'\d').hasMatch(text) &&
    lines.where((line) => line.contains(text)).length == 1;

bool _labelFitsField(String label, String field) {
  switch (field) {
    case 'amount':
      return RegExp(r'金额|实付|付款|合计|总计').hasMatch(label);
    case 'time':
      return RegExp(r'时间|日期').hasMatch(label);
    default:
      return true;
  }
}

String _valueText(Object value) =>
    value is double ? value.toStringAsFixed(2) : value.toString();

bool _canMatch(BillingRuleTemplateMatch match, String ocr, String? source,
    String? sourceAppName) {
  if (match.requiredSource && !match.sourcePackages.contains(source)) {
    return false;
  }
  if (match.appNameKeywords.isNotEmpty &&
      (sourceAppName == null ||
          !match.appNameKeywords.any(sourceAppName.contains))) {
    return false;
  }
  if (match.keywordsAll.any((keyword) => !ocr.contains(keyword))) {
    return false;
  }
  if (match.keywordsAny.isNotEmpty &&
      !match.keywordsAny.any((keyword) => ocr.contains(keyword))) {
    return false;
  }
  return true;
}

bool _preservesExpected(
    BillingRuleResult result, Map<Object?, Object?> expected) {
  for (final entry in expected.entries) {
    if (!_same(_field(result, entry.key.toString()), entry.value)) {
      return false;
    }
  }
  return true;
}

Object? _field(BillingRuleResult result, String field) {
  switch (field) {
    case 'amount':
      return result.amount;
    case 'note':
      return result.note;
    case 'time':
      return result.time;
    case 'paymentChannel':
      return result.paymentChannel;
    case 'paymentMethod':
      return result.paymentMethod;
    case 'counterparty':
      return result.counterparty;
    case 'merchantFullName':
      return result.merchantFullName;
    case 'acquirer':
      return result.acquirer;
    default:
      return result.fields[field]?.value;
  }
}

bool _same(Object? actual, Object? expected) {
  if (actual is num && expected is num) {
    return (actual - expected).abs() < 0.000001;
  }
  if (actual is DateTime && expected is String) {
    return actual.toIso8601String() == expected;
  }
  return actual == expected;
}

String _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// 以 SQLite 不可变修订和单一活动指针保存个人规则快照。
class SqlitePersonalRuleRevisionStore implements PersonalRuleRevisionStore {
  final BeeDatabase db;
  bool failBeforePointerSwitch = false;

  /// 创建 SQLite 个人规则修订存储。
  SqlitePersonalRuleRevisionStore(this.db);

  /// 幂等创建个人规则修订与活动状态表。
  Future<void> ensureSchema() async {
    await db
        .customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_revisions (
      version INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_state (
      singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
      active_version INTEGER REFERENCES personal_rule_revisions(version)
    )''');
    await db
        .customStatement('''CREATE TABLE IF NOT EXISTS personal_rule_archives (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      public_rules_version TEXT NOT NULL,
      archived_at INTEGER NOT NULL
    )''');
    await db.customStatement(
        '''CREATE TABLE IF NOT EXISTS personal_rule_public_decisions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rule_id TEXT NOT NULL,
      public_rules_version TEXT NOT NULL,
      decision TEXT NOT NULL,
      explanation TEXT NOT NULL,
      created_at INTEGER NOT NULL
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
    await db.customStatement(
        'INSERT OR IGNORE INTO personal_rule_state(singleton, active_version) VALUES (1, NULL)');
  }

  @override
  Future<int?> activeVersion() async {
    await ensureSchema();
    final row = await db
        .customSelect(
            'SELECT active_version FROM personal_rule_state WHERE singleton = 1')
        .getSingle();
    return row.data['active_version'] as int?;
  }

  @override
  Future<int> activate(
    BillingRuleTemplate candidate, {
    int? expectedActiveVersion,
  }) async {
    await ensureSchema();
    final current = await loadActiveRuleSet();
    final snapshotJson = jsonEncode([
      ...current.templates.map((rule) => rule.toJson()),
      candidate.toJson(),
    ]);
    return db.transaction(() async {
      final actualVersion = (await db
              .customSelect(
                  'SELECT active_version FROM personal_rule_state WHERE singleton = 1')
              .getSingle())
          .data['active_version'] as int?;
      if (actualVersion != expectedActiveVersion) {
        throw const PersonalRuleActivationConflict();
      }
      await db.customStatement(
          'INSERT INTO personal_rule_revisions(rule_json, created_at) VALUES (?, ?)',
          [snapshotJson, DateTime.now().millisecondsSinceEpoch]);
      final version = (await db
              .customSelect('SELECT last_insert_rowid() AS id')
              .getSingle())
          .read<int>('id');
      if (failBeforePointerSwitch) {
        throw StateError('injected pointer switch failure');
      }
      await db.customStatement(
          'UPDATE personal_rule_state SET active_version = ? WHERE singleton = 1',
          [version]);
      final matchJson = candidate.match.toJson();
      await PersonalRuleSyncRepository(db).saveLocal(PersonalRuleRevision(
        revisionId: const Uuid().v4(),
        ruleId: candidate.id,
        originDeviceId: '',
        originVersion: version,
        kind: PersonalRuleSyncKind.extraction,
        scopeKey: jsonEncode(matchJson['source_packages'] ?? const []),
        conditionKey: jsonEncode(matchJson),
        payload: {'template': candidate.toJson()},
      ));
      return version;
    });
  }

  @override
  Future<bool> hasConflict(BillingRuleTemplate candidate) async {
    final active = await loadActiveRuleSet();
    for (final rule in active.templates) {
      if (jsonEncode(rule.match.toJson()) !=
          jsonEncode(candidate.match.toJson())) {
        continue;
      }
      final oldFields = rule.extractors.map((e) => e.field).toSet();
      if (candidate.extractors.any((e) => oldFields.contains(e.field)) &&
          jsonEncode(rule.toJson()) != jsonEncode(candidate.toJson())) {
        return true;
      }
    }
    return false;
  }

  /// 将已被指定公共版本等价覆盖的个人规则移出活动快照并记录原因。
  Future<int> archiveEquivalentRules(
    List<String> ruleIds, {
    required String publicRulesVersion,
    required int? expectedActiveVersion,
  }) async {
    await ensureSchema();
    final ids = ruleIds.toSet();
    return db.transaction(() async {
      final actualVersion = (await db
              .customSelect(
                  'SELECT active_version FROM personal_rule_state WHERE singleton = 1')
              .getSingle())
          .data['active_version'] as int?;
      if (actualVersion != expectedActiveVersion) {
        throw const PersonalRuleActivationConflict();
      }
      final current = await loadActiveRuleSet();
      final archived = current.templates.where((rule) => ids.contains(rule.id));
      final retained =
          current.templates.where((rule) => !ids.contains(rule.id));
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final rule in archived) {
        await db.customStatement(
          'INSERT INTO personal_rule_archives(rule_id, public_rules_version, archived_at) VALUES (?, ?, ?)',
          [rule.id, publicRulesVersion, now],
        );
      }
      await _recordSyncArchiveResolutions(
        ids,
        publicRulesVersion: publicRulesVersion,
        createdAt: now,
      );
      await db.customStatement(
        'INSERT INTO personal_rule_revisions(rule_json, created_at) VALUES (?, ?)',
        [jsonEncode(retained.map((rule) => rule.toJson()).toList()), now],
      );
      final version = (await db
              .customSelect('SELECT last_insert_rowid() AS id')
              .getSingle())
          .read<int>('id');
      await db.customStatement(
        'UPDATE personal_rule_state SET active_version = ? WHERE singleton = 1',
        [version],
      );
      return version;
    });
  }

  /// 在同一 SQLite 事务中落实公共规则评测裁决。
  ///
  /// 活动个人版本必须仍等于评测时的版本；否则整个归档和冲突解释均不写入，
  /// 让外层公共规则更新恢复旧安全快照后重新评测。
  Future<int?> reconcilePublicRules(
    BillingRulePersonalRegressionResult result, {
    required String publicRulesVersion,
  }) async {
    await ensureSchema();
    if (!result.isPassed) {
      throw ArgumentError('不能落实未通过的个人规则回归裁决');
    }
    return db.transaction(() async {
      final actualVersion = (await db
              .customSelect(
                  'SELECT active_version FROM personal_rule_state WHERE singleton = 1')
              .getSingle())
          .data['active_version'] as int?;
      if (await _isPublicReconciliationApplied(
        result,
        publicRulesVersion: publicRulesVersion,
        actualVersion: actualVersion,
      )) {
        return actualVersion;
      }
      if (actualVersion != result.expectedPersonalRulesVersion) {
        throw const PersonalRuleActivationConflict();
      }
      final current = await loadActiveRuleSet();
      final activeIds = current.templates.map((rule) => rule.id).toSet();
      final equivalentIds = result.equivalentPersonalRuleIds.toSet();
      if (!activeIds.containsAll(equivalentIds)) {
        throw StateError('等价归档裁决引用了非活动个人规则');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      int? nextVersion = actualVersion;
      if (equivalentIds.isNotEmpty) {
        for (final id in equivalentIds) {
          await db.customStatement(
            'INSERT INTO personal_rule_archives(rule_id, public_rules_version, archived_at) VALUES (?, ?, ?)',
            [id, publicRulesVersion, now],
          );
        }
        await _recordSyncArchiveResolutions(
          equivalentIds,
          publicRulesVersion: publicRulesVersion,
          createdAt: now,
        );
        final retained = current.templates
            .where((rule) => !equivalentIds.contains(rule.id))
            .map((rule) => rule.toJson())
            .toList(growable: false);
        await db.customStatement(
          'INSERT INTO personal_rule_revisions(rule_json, created_at) VALUES (?, ?)',
          [jsonEncode(retained), now],
        );
        nextVersion = (await db
                .customSelect('SELECT last_insert_rowid() AS id')
                .getSingle())
            .read<int>('id');
        await db.customStatement(
          'UPDATE personal_rule_state SET active_version = ? WHERE singleton = 1',
          [nextVersion],
        );
      }
      for (final conflict in result.conflicts) {
        if (!activeIds.contains(conflict.personalRuleId) ||
            equivalentIds.contains(conflict.personalRuleId)) {
          throw StateError('冲突裁决引用了无效个人规则');
        }
        await db.customStatement(
          '''INSERT INTO personal_rule_public_decisions(
            rule_id, public_rules_version, decision, explanation, created_at
          ) VALUES (?, ?, ?, ?, ?)''',
          [
            conflict.personalRuleId,
            publicRulesVersion,
            'retained_conflict',
            conflict.explanation,
            now,
          ],
        );
      }
      return nextVersion;
    });
  }

  /// 判断指定公共版本的整组个人裁决是否已由先前事务完整提交。
  ///
  /// 该证明用于激活 journal 在“SQLite 已提交、journal 尚未推进”崩溃窗口中
  /// 幂等重放；只要任一归档、同步 resolution、冲突解释或活动快照不匹配，
  /// 就返回 false 并由 CAS 拒绝猜测完成。
  Future<bool> isPublicReconciliationApplied(
    BillingRulePersonalRegressionResult result, {
    required String publicRulesVersion,
  }) async {
    await ensureSchema();
    final actualVersion = await activeVersion();
    return _isPublicReconciliationApplied(
      result,
      publicRulesVersion: publicRulesVersion,
      actualVersion: actualVersion,
    );
  }

  Future<bool> _isPublicReconciliationApplied(
    BillingRulePersonalRegressionResult result, {
    required String publicRulesVersion,
    required int? actualVersion,
  }) async {
    final equivalentIds = result.equivalentPersonalRuleIds.toSet();
    final conflicts = result.conflicts;
    if (equivalentIds.isEmpty && conflicts.isEmpty) return true;

    final current = await loadActiveRuleSet();
    final activeIds = current.templates.map((rule) => rule.id).toSet();
    if (equivalentIds.any(activeIds.contains)) return false;
    if (equivalentIds.isNotEmpty &&
        actualVersion == result.expectedPersonalRulesVersion) {
      return false;
    }
    for (final id in equivalentIds) {
      final archive = await db.customSelect(
        '''SELECT 1 FROM personal_rule_archives
           WHERE rule_id = ? AND public_rules_version = ? LIMIT 1''',
        variables: [Variable(id), Variable(publicRulesVersion)],
      ).getSingleOrNull();
      final resolution = await db.customSelect(
        '''SELECT 1 FROM personal_rule_public_archive_resolutions
           WHERE rule_id = ? AND public_rules_version = ? LIMIT 1''',
        variables: [Variable(id), Variable(publicRulesVersion)],
      ).getSingleOrNull();
      if (archive == null || resolution == null) return false;
    }
    for (final conflict in conflicts) {
      if (!activeIds.contains(conflict.personalRuleId)) return false;
      final decision = await db.customSelect(
        '''SELECT 1 FROM personal_rule_public_decisions
           WHERE rule_id = ? AND public_rules_version = ?
             AND decision = 'retained_conflict' AND explanation = ? LIMIT 1''',
        variables: [
          Variable(conflict.personalRuleId),
          Variable(publicRulesVersion),
          Variable(conflict.explanation),
        ],
      ).getSingleOrNull();
      if (decision == null) return false;
    }
    return true;
  }

  Future<void> _recordSyncArchiveResolutions(
    Set<String> ruleIds, {
    required String publicRulesVersion,
    required int createdAt,
  }) async {
    if (ruleIds.isEmpty) return;
    final syncTable = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'personal_rule_sync_revisions'",
        )
        .getSingleOrNull();
    if (syncTable == null) return;
    for (final ruleId in ruleIds) {
      final revisions = await db.customSelect(
        'SELECT revision_id FROM personal_rule_sync_revisions WHERE rule_id = ?',
        variables: [Variable.withString(ruleId)],
      ).get();
      for (final revision in revisions) {
        await db.customStatement(
          '''INSERT OR IGNORE INTO personal_rule_public_archive_resolutions(
            rule_id, resolved_revision_id, public_rules_version, created_at
          ) VALUES (?, ?, ?, ?)''',
          [
            ruleId,
            revision.read<String>('revision_id'),
            publicRulesVersion,
            createdAt,
          ],
        );
      }
    }
  }

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async {
    await ensureSchema();
    final rows = await db.customSelect('''SELECT r.version, r.rule_json
      FROM personal_rule_state s JOIN personal_rule_revisions r
      ON r.version = s.active_version WHERE s.singleton = 1''').get();
    if (rows.isEmpty) {
      return const BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'personal-0',
          paymentChannels: [],
          templates: []);
    }
    final version = rows.single.read<int>('version');
    final decoded = jsonDecode(rows.single.read<String>('rule_json'));
    final rulesJson = decoded is List
        ? decoded.cast<Map<String, dynamic>>()
        : [decoded as Map<String, dynamic>];
    return BillingRuleSet(
        schemaVersion: 1,
        rulesVersion: 'personal-$version',
        paymentChannels: const [],
        templates: rulesJson.map(BillingRuleTemplate.fromJson).toList());
  }
}
