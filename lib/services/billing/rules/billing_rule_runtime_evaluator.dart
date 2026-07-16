import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../regression_sample_store.dart';
import 'billing_rule_engine.dart';
import 'billing_rule_models.dart';

/// 一条随安装包发布、由人工确认字段真值的公共规则黄金样本。
class BillingRuleGoldenSample {
  final String id;
  final String normalizedOcr;
  final String? sourcePackage;
  final String? sourceAppName;
  final Map<String, Object?> expectedFields;

  /// 创建固定黄金样本。
  const BillingRuleGoldenSample({
    required this.id,
    required this.normalizedOcr,
    required this.expectedFields,
    this.sourcePackage,
    this.sourceAppName,
  });
}

/// 公共规则黄金样本的只读来源。
abstract class BillingRuleGoldenCorpusSource {
  /// 读取本安装包内固定的人工真值样本。
  Future<List<BillingRuleGoldenSample>> load();
}

/// 从 `tool/rule_eval` 的随包资源读取与 CLI 相同的黄金真值。
class BundledBillingRuleGoldenCorpus implements BillingRuleGoldenCorpusSource {
  static const _samplePrefix = 'tool/rule_eval/samples/';
  static const _expectedPrefix = 'tool/rule_eval/expected/';
  final AssetBundle assetBundle;

  /// 创建随包黄金样本源；生产默认使用 [rootBundle]。
  BundledBillingRuleGoldenCorpus({AssetBundle? assetBundle})
      : assetBundle = assetBundle ?? rootBundle;

  @override
  Future<List<BillingRuleGoldenSample>> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
    final paths = manifest
        .listAssets()
        .where(
            (path) => path.startsWith(_samplePrefix) && path.endsWith('.json'))
        .toList()
      ..sort();
    final samples = <BillingRuleGoldenSample>[];
    for (final path in paths) {
      final raw = jsonDecode(await assetBundle.loadString(path));
      if (raw is! Map) throw FormatException('黄金样本格式无效：$path');
      final json = Map<String, Object?>.from(raw);
      final id = json['id']?.toString();
      final ocr = json['ocrText']?.toString();
      if (id == null || id.isEmpty || ocr == null || ocr.isEmpty) {
        throw FormatException('黄金样本缺少 id/ocrText：$path');
      }
      final expectedPath = '$_expectedPrefix$id.expected.json';
      final embedded = _stringMap(json['expected']);
      final expectedRaw =
          jsonDecode(await assetBundle.loadString(expectedPath));
      if (expectedRaw is! Map) {
        throw FormatException('黄金真值格式无效：$expectedPath');
      }
      samples.add(BillingRuleGoldenSample(
        id: id,
        normalizedOcr: ocr,
        sourcePackage: json['sourcePackage']?.toString(),
        sourceAppName: json['sourceAppName']?.toString(),
        expectedFields: {
          ...embedded,
          ...Map<String, Object?>.from(expectedRaw),
        },
      ));
    }
    if (samples.isEmpty) throw const FormatException('安装包内没有黄金样本');
    return samples;
  }
}

/// 公共候选与某条活动个人规则发生不等价覆盖时的可持久化解释。
class BillingRulePersonalConflict {
  final String personalRuleId;
  final String explanation;

  /// 创建个人规则保留解释。
  const BillingRulePersonalConflict({
    required this.personalRuleId,
    required this.explanation,
  });
}

/// 本机个人样本回归的稳定裁决。
class BillingRulePersonalRegressionResult {
  final bool isPassed;
  final List<String> equivalentPersonalRuleIds;
  final List<BillingRulePersonalConflict> conflicts;
  final String? explanation;
  final int? expectedPersonalRulesVersion;
  final String? _legacyConflictExplanation;

  /// 所有样本通过；等价规则可在公共规则激活时归档。
  const BillingRulePersonalRegressionResult.passed({
    this.equivalentPersonalRuleIds = const [],
    this.conflicts = const [],
    this.expectedPersonalRulesVersion,
    String? conflictExplanation,
  })  : isPassed = true,
        explanation = null,
        _legacyConflictExplanation = conflictExplanation;

  /// 至少一个样本无法安全保持，候选不得激活。
  const BillingRulePersonalRegressionResult.rejected({
    required this.explanation,
  })  : isPassed = false,
        equivalentPersonalRuleIds = const [],
        conflicts = const [],
        expectedPersonalRulesVersion = null,
        _legacyConflictExplanation = null;

  /// 可展示并持久化的个人规则冲突摘要。
  String? get conflictExplanation =>
      _legacyConflictExplanation ??
      (conflicts.isEmpty
          ? null
          : conflicts.map((item) => item.explanation).join('；'));
}

/// 可由调用方主动取消的运行时回归信号。
class BillingRuleEvaluationCancellation {
  bool _isCancelled = false;

  /// 是否已经取消。
  bool get isCancelled => _isCancelled;

  /// 幂等取消尚未完成的评测。
  void cancel() => _isCancelled = true;
}

/// 候选公共规则的生产黄金评测与本机个人样本回归实现。
class BillingRuleRuntimeEvaluator {
  final BillingRuleEngine engine;
  final BillingRuleGoldenCorpusSource goldenCorpus;
  final RegressionSamplePageSource regressionSamples;
  final Future<BillingRuleSet> Function() loadActivePublicRules;
  final Future<BillingRuleSet> Function() loadBuiltInRules;
  final Future<BillingRuleSet> Function() loadActivePersonalRules;
  final int batchSize;
  final Duration timeout;
  final void Function(int count)? afterSampleForTesting;

  /// 创建运行时评测器。测试替换边界只位于资源、加密存储和规则仓库。
  const BillingRuleRuntimeEvaluator({
    required this.engine,
    required this.goldenCorpus,
    required this.regressionSamples,
    required this.loadActivePublicRules,
    required this.loadBuiltInRules,
    required this.loadActivePersonalRules,
    this.batchSize = 50,
    this.timeout = const Duration(seconds: 5),
    this.afterSampleForTesting,
  }) : assert(batchSize > 0);

  /// 候选必须通过全部人工真值，并不得降低活动/内置规则关键字段。
  Future<bool> evaluateGolden(BillingRuleSet candidate) =>
      _evaluateGolden(candidate).timeout(timeout, onTimeout: () => false);

  Future<bool> _evaluateGolden(BillingRuleSet candidate) async {
    try {
      final samples = await goldenCorpus.load();
      final active = await loadActivePublicRules();
      final builtIn = await loadBuiltInRules();
      final watch = Stopwatch()..start();
      for (final sample in samples) {
        if (watch.elapsed > timeout) return false;
        final results = await Future.wait([
          _evaluate(candidate, sample.normalizedOcr, sample.sourcePackage,
              sample.sourceAppName),
          _evaluate(active, sample.normalizedOcr, sample.sourcePackage,
              sample.sourceAppName),
          _evaluate(builtIn, sample.normalizedOcr, sample.sourcePackage,
              sample.sourceAppName),
        ]);
        if (!_passesGolden(
          candidate: results[0],
          active: results[1],
          builtIn: results[2],
          expected: sample.expectedFields,
        )) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 分页解密个人成功样本；损坏、超时、取消或字段回退均安全拒绝。
  Future<BillingRulePersonalRegressionResult> evaluatePersonal(
    BillingRuleSet candidate, {
    BillingRuleEvaluationCancellation? cancellation,
  }) {
    final timeoutCancellation = BillingRuleEvaluationCancellation();
    return _evaluatePersonal(
      candidate,
      cancellation: cancellation,
      timeoutCancellation: timeoutCancellation,
    ).timeout(
      timeout,
      onTimeout: () {
        timeoutCancellation.cancel();
        return const BillingRulePersonalRegressionResult.rejected(
          explanation: '个人规则回归超时，候选未激活。',
        );
      },
    );
  }

  Future<BillingRulePersonalRegressionResult> _evaluatePersonal(
    BillingRuleSet candidate, {
    required BillingRuleEvaluationCancellation timeoutCancellation,
    BillingRuleEvaluationCancellation? cancellation,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final activePublic = await loadActivePublicRules();
      final personal = await loadActivePersonalRules();
      final baseline = BillingRuleSet.activeSnapshot(
        publicRules: activePublic,
        personalRules: personal,
      );
      final proposed = BillingRuleSet.activeSnapshot(
        publicRules: candidate,
        personalRules: personal,
      );
      final equivalentSeen = <String>{};
      final notEquivalent = <String>{};
      final conflicting = <String, BillingRulePersonalConflict>{};
      String? cursor;
      var processed = 0;
      do {
        if (_cancelled(cancellation, timeoutCancellation)) {
          return const BillingRulePersonalRegressionResult.rejected(
            explanation: '个人规则回归已取消，候选未激活。',
          );
        }
        if (watch.elapsed > timeout) {
          return const BillingRulePersonalRegressionResult.rejected(
            explanation: '个人规则回归超时，候选未激活。',
          );
        }
        final page = await regressionSamples.readPage(
          limit: batchSize,
          cursor: cursor,
        );
        if (page.unreadableSampleIds.isNotEmpty) {
          return BillingRulePersonalRegressionResult.rejected(
            explanation: '存在无法解密的回归样本：${page.unreadableSampleIds.join(', ')}',
          );
        }
        for (final sample in page.samples) {
          if (_cancelled(cancellation, timeoutCancellation)) {
            return const BillingRulePersonalRegressionResult.rejected(
              explanation: '个人规则回归已取消，候选未激活。',
            );
          }
          if (watch.elapsed > timeout) {
            return const BillingRulePersonalRegressionResult.rejected(
              explanation: '个人规则回归超时，候选未激活。',
            );
          }
          final source = _sampleSource(sample.sensitiveEvidence);
          final oldResult = await _evaluate(
              baseline, sample.normalizedOcr, source.$1, source.$2);
          final proposedResult = await _evaluate(
              proposed, sample.normalizedOcr, source.$1, source.$2);
          if (!_preservesPersonalBehavior(
            proposedResult,
            oldResult,
            sample.expectedFields,
          )) {
            return BillingRulePersonalRegressionResult.rejected(
              explanation: '样本 ${sample.id} 的既有账单字段发生变化。',
            );
          }
          final publicOnly = await _evaluate(
              candidate, sample.normalizedOcr, source.$1, source.$2);
          for (final rule in personal.templates) {
            final personalOnly = BillingRuleSet(
              schemaVersion: personal.schemaVersion,
              rulesVersion: personal.rulesVersion,
              paymentChannels: personal.paymentChannels,
              templates: [rule],
            );
            final currentRuleSnapshot = BillingRuleSet.activeSnapshot(
              publicRules: activePublic,
              personalRules: personalOnly,
            );
            final personalResult = await _evaluate(currentRuleSnapshot,
                sample.normalizedOcr, source.$1, source.$2);
            if (personalResult.matchedTemplateId != rule.id ||
                rule.extractors.isEmpty) {
              continue;
            }
            if (publicOnly.matchedTemplateId == null) {
              notEquivalent.add(rule.id);
              continue;
            }
            if (_sameRuleControlledBehavior(rule, publicOnly, personalResult)) {
              equivalentSeen.add(rule.id);
            } else {
              notEquivalent.add(rule.id);
              conflicting[rule.id] = BillingRulePersonalConflict(
                personalRuleId: rule.id,
                explanation:
                    '公共规则 ${candidate.rulesVersion} 与个人规则 ${rule.id} 结果不同；已保留个人规则的安全结果。',
              );
            }
          }
          processed++;
          afterSampleForTesting?.call(processed);
        }
        cursor = page.nextCursor;
      } while (cursor != null);
      equivalentSeen.removeAll(notEquivalent);
      final equivalent = equivalentSeen.toList()..sort();
      final conflicts = conflicting.values.toList()
        ..sort((left, right) =>
            left.personalRuleId.compareTo(right.personalRuleId));
      return BillingRulePersonalRegressionResult.passed(
        equivalentPersonalRuleIds: equivalent,
        conflicts: conflicts,
        expectedPersonalRulesVersion: _personalVersion(personal.rulesVersion),
      );
    } catch (error) {
      return BillingRulePersonalRegressionResult.rejected(
        explanation: '个人规则回归读取或评测失败：${error.runtimeType}',
      );
    }
  }

  Future<BillingRuleResult> _evaluate(BillingRuleSet rules, String ocr,
          String? sourcePackage, String? sourceAppName) =>
      engine.evaluate(
        ruleSet: rules,
        ocrText: ocr,
        sourcePackage: sourcePackage,
        sourceAppName: sourceAppName,
      );
}

bool _cancelled(BillingRuleEvaluationCancellation? caller,
        BillingRuleEvaluationCancellation timeout) =>
    (caller?.isCancelled ?? false) || timeout.isCancelled;

int? _personalVersion(String rulesVersion) {
  final match = RegExp(r'^personal-(\d+)$').firstMatch(rulesVersion);
  if (match == null) return null;
  final value = int.parse(match.group(1)!);
  return value == 0 ? null : value;
}

bool _passesGolden({
  required BillingRuleResult candidate,
  required BillingRuleResult active,
  required BillingRuleResult builtIn,
  required Map<String, Object?> expected,
}) {
  final expectedTemplate = expected['matchedTemplateId'];
  if (expectedTemplate == null) {
    if (candidate.matchedTemplateId != null) return false;
  } else if (candidate.matchedTemplateId != expectedTemplate.toString()) {
    return false;
  }
  for (final entry in expected.entries) {
    if (entry.key == 'matchedTemplateId') continue;
    final actual = _field(candidate, entry.key);
    if (!_same(actual, entry.value)) return false;
  }
  for (final field in const ['amount', 'time']) {
    final expectedValue = expected[field];
    final protected =
        expectedValue ?? _field(active, field) ?? _field(builtIn, field);
    if (protected != null && !_same(_field(candidate, field), protected)) {
      return false;
    }
  }
  return true;
}

bool _preservesPersonalBehavior(BillingRuleResult proposed,
    BillingRuleResult baseline, Map<Object?, Object?> expected) {
  for (final entry in expected.entries) {
    final field = entry.key.toString();
    if (const {'type', 'accountId', 'toAccountId', 'categoryId'}
        .contains(field)) {
      continue;
    }
    if (field == 'note' || field == 'detailsText') {
      if (!_same(_field(proposed, field), _field(baseline, field))) {
        return false;
      }
      continue;
    }
    if (!_same(_field(proposed, field), entry.value)) {
      return false;
    }
  }
  if (expected.containsKey('categoryId')) {
    for (final field in const [
      'note',
      'counterparty',
      'merchantFullName',
      'paymentChannel'
    ]) {
      if (!_same(_field(proposed, field), _field(baseline, field))) {
        return false;
      }
    }
  }
  return true;
}

bool _sameRuleControlledBehavior(BillingRuleTemplate rule,
    BillingRuleResult candidate, BillingRuleResult currentPersonal) {
  final fields = rule.extractors.map((extractor) => extractor.field).toSet();
  for (final field in fields) {
    if (!_same(_field(candidate, field), _field(currentPersonal, field))) {
      return false;
    }
  }
  return true;
}

Object? _field(BillingRuleResult result, String field) {
  switch (field) {
    case 'amount':
      return result.amount;
    case 'time':
    case 'happenedAt':
      return result.time;
    case 'note':
      return result.note;
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
    case 'detailsText':
      return result.details?['remaining_text'];
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

(String?, String?) _sampleSource(Map<Object?, Object?> evidence) {
  final nested = evidence['source'];
  final source = nested is Map ? nested : evidence;
  String? value(String snake, String camel) =>
      source[snake]?.toString() ?? source[camel]?.toString();
  return (
    value('source_package', 'sourceAppPackage'),
    value('source_app_name', 'sourceAppName'),
  );
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
