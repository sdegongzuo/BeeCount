import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:toml/toml.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }

  final ruleFile =
      File(_option(args, '--rules') ?? 'assets/rules/billing_rules.toml');
  final sampleDirectory =
      Directory(_option(args, '--samples') ?? 'tool/rule_eval/samples');
  final expectedDirectory =
      Directory(_option(args, '--expected') ?? 'tool/rule_eval/expected');
  final format = _option(args, '--format') ?? 'markdown';

  final report = await evaluateBillingRules(
    sampleDirectory: sampleDirectory,
    expectedDirectory: expectedDirectory,
    ruleFile: ruleFile,
  );

  if (format == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.write(renderRuleEvalMarkdown(report));
  }

  if (report.failedSamples > 0 || report.falsePositiveCount > 0) {
    exitCode = 1;
  }
}

Future<RuleEvalReport> evaluateBillingRules({
  required Directory sampleDirectory,
  required Directory expectedDirectory,
  File? ruleFile,
  Map<String, Map<String, Object?>> expectedOverrides = const {},
}) async {
  final ruleSet = await _loadRuleSet(ruleFile);
  final sampleFiles = await _listJsonFiles(sampleDirectory);
  final samples = <RuleEvalSampleResult>[];

  var expectedFieldCount = 0;
  var matchedFieldCount = 0;
  var templateExpectedCount = 0;
  var templateHitCount = 0;
  var falsePositiveCount = 0;
  var totalElapsedMicros = 0;

  for (final file in sampleFiles) {
    final sample = RuleEvalSample.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    final expected = {
      ...sample.expected,
      ...await _loadExpected(expectedDirectory, sample.id),
      ...?expectedOverrides[sample.id],
    };

    final stopwatch = Stopwatch()..start();
    final result = await BillingRuleEngineImpl().evaluate(
      ruleSet: ruleSet,
      ocrText: sample.ocrText,
      sourcePackage: sample.sourcePackage,
    );
    stopwatch.stop();
    totalElapsedMicros += stopwatch.elapsedMicroseconds;

    final actual = _actualFields(result);
    final diffs = <RuleEvalFieldDiff>[];
    final expectedTemplate = expected['matchedTemplateId']?.toString();
    if (expectedTemplate != null && expectedTemplate.isNotEmpty) {
      templateExpectedCount++;
      if (result.matchedTemplateId == expectedTemplate) {
        templateHitCount++;
      } else {
        diffs.add(RuleEvalFieldDiff(
          field: 'matchedTemplateId',
          expected: expectedTemplate,
          actual: result.matchedTemplateId,
        ));
      }
    } else if (result.matchedTemplateId != null) {
      falsePositiveCount++;
      diffs.add(RuleEvalFieldDiff(
        field: 'matchedTemplateId',
        expected: null,
        actual: result.matchedTemplateId,
      ));
    }

    for (final entry in expected.entries) {
      if (entry.key == 'matchedTemplateId') continue;
      expectedFieldCount++;
      final expectedValue = _normalizeValue(entry.value);
      final actualValue = _normalizeValue(actual[entry.key]);
      if (_valuesEqual(expectedValue, actualValue)) {
        matchedFieldCount++;
      } else {
        diffs.add(RuleEvalFieldDiff(
          field: entry.key,
          expected: expectedValue,
          actual: actualValue,
        ));
      }
    }

    samples.add(RuleEvalSampleResult(
      id: sample.id,
      sourcePackage: sample.sourcePackage,
      matchedTemplateId: result.matchedTemplateId,
      elapsedMicros: stopwatch.elapsedMicroseconds,
      expected: expected,
      actual: actual,
      paymentMethodReport: _paymentMethodReport(
        result,
        expected['paymentMethod'],
      ),
      fieldDiffs: diffs,
    ));
  }

  return RuleEvalReport(
    ruleSource: ruleSet.source ?? ruleFile?.path ?? 'active',
    rulesVersion: ruleSet.rulesVersion,
    samples: samples,
    templateExpectedCount: templateExpectedCount,
    templateHitCount: templateHitCount,
    expectedFieldCount: expectedFieldCount,
    matchedFieldCount: matchedFieldCount,
    falsePositiveCount: falsePositiveCount,
    totalElapsedMicros: totalElapsedMicros,
  );
}

String renderRuleEvalMarkdown(RuleEvalReport report) {
  final buffer = StringBuffer()
    ..writeln('# Billing Rule Evaluation')
    ..writeln()
    ..writeln('- Rule source: ${report.ruleSource}')
    ..writeln('- Rules version: ${report.rulesVersion}')
    ..writeln(
        '- Samples: ${report.passedSamples}/${report.totalSamples} passed')
    ..writeln(
      '- Template hit rate: ${report.templateHitCount}/${report.templateExpectedCount}',
    )
    ..writeln(
      '- Field accuracy: ${report.matchedFieldCount}/${report.expectedFieldCount}',
    )
    ..writeln('- False positives: ${report.falsePositiveCount}')
    ..writeln(
      '- Extraction time: ${report.totalElapsedMilliseconds.toStringAsFixed(2)}ms total',
    )
    ..writeln()
    ..writeln('| Sample | Status | Template | Time |')
    ..writeln('| --- | --- | --- | ---: |');

  for (final sample in report.samples) {
    buffer.writeln(
      '| ${sample.id} | ${sample.passed ? 'PASS' : 'FAIL'} | '
      '${sample.matchedTemplateId ?? '-'} | '
      '${sample.elapsedMilliseconds.toStringAsFixed(2)}ms |',
    );
  }

  final failed = report.samples.where((sample) => !sample.passed).toList();
  if (failed.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Field Diffs');
    for (final sample in failed) {
      for (final diff in sample.fieldDiffs) {
        buffer.writeln(
          '- sample=${sample.id} field=${diff.field} '
          'expected=${_display(diff.expected)} actual=${_display(diff.actual)}',
        );
      }
    }
  }

  return buffer.toString();
}

class RuleEvalReport {
  final String ruleSource;
  final String rulesVersion;
  final List<RuleEvalSampleResult> samples;
  final int templateExpectedCount;
  final int templateHitCount;
  final int expectedFieldCount;
  final int matchedFieldCount;
  final int falsePositiveCount;
  final int totalElapsedMicros;

  const RuleEvalReport({
    required this.ruleSource,
    required this.rulesVersion,
    required this.samples,
    required this.templateExpectedCount,
    required this.templateHitCount,
    required this.expectedFieldCount,
    required this.matchedFieldCount,
    required this.falsePositiveCount,
    required this.totalElapsedMicros,
  });

  int get totalSamples => samples.length;

  int get passedSamples => samples.where((sample) => sample.passed).length;

  int get failedSamples => totalSamples - passedSamples;

  double get templateHitRate =>
      templateExpectedCount == 0 ? 1 : templateHitCount / templateExpectedCount;

  double get fieldAccuracy =>
      expectedFieldCount == 0 ? 1 : matchedFieldCount / expectedFieldCount;

  double get totalElapsedMilliseconds => totalElapsedMicros / 1000;

  Map<String, dynamic> toJson() => {
        'rule_source': ruleSource,
        'rules_version': rulesVersion,
        'total_samples': totalSamples,
        'passed_samples': passedSamples,
        'failed_samples': failedSamples,
        'template_hit_rate': templateHitRate,
        'template_hit_count': templateHitCount,
        'template_expected_count': templateExpectedCount,
        'field_accuracy': fieldAccuracy,
        'matched_field_count': matchedFieldCount,
        'expected_field_count': expectedFieldCount,
        'false_positive_count': falsePositiveCount,
        'total_elapsed_ms': totalElapsedMilliseconds,
        'samples': samples.map((sample) => sample.toJson()).toList(),
      };
}

class RuleEvalSampleResult {
  final String id;
  final String? sourcePackage;
  final String? matchedTemplateId;
  final int elapsedMicros;
  final Map<String, Object?> expected;
  final Map<String, Object?> actual;
  final Map<String, Object?>? paymentMethodReport;
  final List<RuleEvalFieldDiff> fieldDiffs;

  const RuleEvalSampleResult({
    required this.id,
    required this.sourcePackage,
    required this.matchedTemplateId,
    required this.elapsedMicros,
    required this.expected,
    required this.actual,
    this.paymentMethodReport,
    required this.fieldDiffs,
  });

  bool get passed => fieldDiffs.isEmpty;

  double get elapsedMilliseconds => elapsedMicros / 1000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_package': sourcePackage,
        'matched_template_id': matchedTemplateId,
        'elapsed_ms': elapsedMilliseconds,
        'passed': passed,
        'expected': expected,
        'actual': actual,
        if (paymentMethodReport != null) 'paymentMethod': paymentMethodReport,
        'field_diffs': fieldDiffs.map((diff) => diff.toJson()).toList(),
      };
}

Map<String, Object?>? _paymentMethodReport(
  BillingRuleResult result,
  Object? expected,
) {
  final field = result.fields['paymentMethod'];
  if (field == null && result.paymentMethod == null && expected == null) {
    return null;
  }
  return {
    'raw': _redactPaymentMethodValue(field?.rawValue),
    'normalized': result.paymentMethod,
    'expected': expected,
    'evidence': field?.evidence
            .map((item) => {
                  ...item.toJson(),
                  'text': _redactPaymentMethodText(item.text),
                })
            .toList(growable: false) ??
        const [],
  };
}

Object? _redactPaymentMethodValue(Object? value) =>
    value is String ? _redactPaymentMethodText(value) : value;

String _redactPaymentMethodText(String value) => value.replaceAllMapped(
      RegExp(r'\d{7,}'),
      (match) => '${'*' * (match.group(0)!.length - 4)}'
          '${match.group(0)!.substring(match.group(0)!.length - 4)}',
    );

class RuleEvalFieldDiff {
  final String field;
  final Object? expected;
  final Object? actual;

  const RuleEvalFieldDiff({
    required this.field,
    required this.expected,
    required this.actual,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'expected': expected,
        'actual': actual,
      };
}

class RuleEvalSample {
  final String id;
  final String? sourcePackage;
  final String ocrText;
  final Map<String, Object?> expected;

  const RuleEvalSample({
    required this.id,
    required this.ocrText,
    this.sourcePackage,
    this.expected = const {},
  });

  factory RuleEvalSample.fromJson(Map<String, dynamic> json) {
    return RuleEvalSample(
      id: _requiredString(json, 'id'),
      sourcePackage: json['sourcePackage']?.toString(),
      ocrText: _requiredString(json, 'ocrText'),
      expected: _objectMap(json['expected']),
    );
  }
}

Future<BillingRuleSet> _loadRuleSet(File? ruleFile) async {
  final file = ruleFile ?? File('assets/rules/billing_rules.toml');
  if (!await file.exists()) {
    throw StateError('Rule file does not exist: ${file.path}');
  }
  return _parseRuleToml(await file.readAsString(), source: file.path);
}

BillingRuleSet _parseRuleToml(String content, {required String source}) {
  final map = TomlDocument.parse(content).toMap();
  return BillingRuleSet(
    schemaVersion: _requiredInt(map, 'schemaVersion'),
    rulesVersion: _requiredString(map, 'rulesVersion'),
    paymentChannels: _parsePaymentChannels(map['paymentChannels']),
    templates: _parseTemplates(map['templates']),
    source: source,
    loadedAt: DateTime.now(),
  );
}

List<BillingPaymentChannelRule> _parsePaymentChannels(Object? value) {
  final items = _optionalList(value);
  return items.map((item) {
    final map = _asMap(item);
    return BillingPaymentChannelRule(
      channel: _requiredString(map, 'channel'),
      packages: _stringList(map['packages']),
      appNameKeywords: _stringList(map['appNameKeywords']),
      confidence: _optionalDouble(map['confidence'], 0.9),
    );
  }).toList(growable: false);
}

List<BillingRuleTemplate> _parseTemplates(Object? value) {
  final items = _requiredList(value, 'templates');
  return items.map((item) {
    final map = _asMap(item);
    final id = _requiredString(map, 'id');
    return BillingRuleTemplate(
      id: id,
      enabled: _optionalBool(map['enabled'], true),
      priority: _optionalInt(map['priority'], 0),
      baseConfidence: _optionalDouble(map['baseConfidence'], 0.8),
      origin: BillingRuleOrigin.values.byName(
        _optionalString(map['origin']) ?? 'public',
      ),
      revision: _optionalInt(map['revision'], 1),
      extractorSelection: BillingExtractorSelection.values.byName(
        _optionalString(map['extractorSelection']) ?? 'firstSuccessful',
      ),
      match: _parseTemplateMatch(map['match']),
      extractors: _parseExtractors(id, map['extract']),
    );
  }).toList(growable: false);
}

BillingRuleTemplateMatch _parseTemplateMatch(Object? value) {
  if (value == null) return const BillingRuleTemplateMatch();
  final map = _asMap(value);
  return BillingRuleTemplateMatch(
    sourcePackages: _stringList(map['sourcePackages']),
    requiredSource: _optionalBool(map['requiredSource'], false),
    appNameKeywords: _stringList(map['appNameKeywords']),
    keywordsAll: _stringList(map['keywordsAll']),
    keywordsAny: _stringList(map['keywordsAny']),
  );
}

List<BillingFieldExtractorRule> _parseExtractors(
  String templateId,
  Object? value,
) {
  final items = _requiredList(value, 'templates.extract');
  return items.map((item) {
    final map = _asMap(item);
    return BillingFieldExtractorRule(
      id: _optionalString(map['id']),
      field: _requiredString(map, 'field'),
      type: _requiredString(map, 'type'),
      value: _optionalString(map['value']),
      label: _optionalString(map['label']),
      parser: _optionalString(map['parser']),
      pattern: _optionalString(map['pattern']),
      confidence: _optionalDouble(map['confidence'], 0.8),
      options: _optionsMap(map['options']),
    ).withResolvedId(templateId);
  }).toList(growable: false);
}

Future<List<File>> _listJsonFiles(Directory directory) async {
  if (!await directory.exists()) {
    throw StateError('Sample directory does not exist: ${directory.path}');
  }
  final files = await directory
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.json'))
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

Future<Map<String, Object?>> _loadExpected(
  Directory expectedDirectory,
  String sampleId,
) async {
  final file = File('${expectedDirectory.path}/$sampleId.expected.json');
  if (!await file.exists()) return const {};
  return _objectMap(jsonDecode(await file.readAsString()));
}

Map<String, Object?> _actualFields(BillingRuleResult result) {
  return {
    'matchedTemplateId': result.matchedTemplateId,
    'amount': result.amount,
    'discountAmount': result.discountAmount,
    'note': result.note,
    'time': result.time?.toIso8601String(),
    'paymentChannel': result.paymentChannel,
    'paymentMethod': result.paymentMethod,
    'counterparty': result.counterparty,
    'merchantFullName': result.merchantFullName,
    'acquirer': result.acquirer,
    if (result.details != null) ...result.details!,
  };
}

Object? _normalizeValue(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value is num) return value.toDouble();
  return value;
}

bool _valuesEqual(Object? expected, Object? actual) {
  if (expected is double && actual is double) {
    return (expected - actual).abs() < 0.0001;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (!_valuesEqual(expected[index], actual[index])) return false;
    }
    return true;
  }
  if (expected is Map && actual is Map) {
    if (expected.length != actual.length) return false;
    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key) ||
          !_valuesEqual(entry.value, actual[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return expected == actual;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value == null) return const {};
  if (value is! Map) throw const FormatException('Expected JSON object');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key is required');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key is required');
}

int _optionalInt(Object? value, int fallback) {
  if (value == null) return fallback;
  if (value is int) return value;
  throw const FormatException('Expected int');
}

double _optionalDouble(Object? value, double fallback) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  throw const FormatException('Expected number');
}

bool _optionalBool(Object? value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  throw const FormatException('Expected bool');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw const FormatException('Expected string');
}

List<Object?> _requiredList(Object? value, String key) {
  if (value is List) return value;
  throw FormatException('$key is required');
}

List<Object?> _optionalList(Object? value) {
  if (value == null) return const [];
  if (value is List) return value;
  throw const FormatException('Expected list');
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected table');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Expected string list');
  return value.map((item) {
    if (item is String) return item;
    throw const FormatException('Expected string list');
  }).toList(growable: false);
}

Map<String, dynamic> _optionsMap(Object? value) {
  if (value == null) return const {};
  return _asMap(value);
}

String _display(Object? value) {
  if (value is double && value == value.roundToDouble()) {
    return value.toStringAsFixed(1);
  }
  return value?.toString() ?? 'null';
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

const _usage = '''
Usage: dart run tool/rule_eval.dart [options]

Options:
  --rules <path>     TOML rule file to evaluate. Defaults to assets/rules/billing_rules.toml.
  --samples <dir>    Sample JSON directory. Defaults to tool/rule_eval/samples.
  --expected <dir>   Expected JSON directory. Defaults to tool/rule_eval/expected.
  --format <format>  markdown or json. Defaults to markdown.
''';
