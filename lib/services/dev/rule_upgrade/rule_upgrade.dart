import 'dart:convert';

import 'package:toml/toml.dart';

import '../../billing/rules/billing_rule_engine_impl.dart';
import '../../billing/rules/billing_rule_models.dart';
import '../image_billing_eval_assertions.dart';

class RuleUpgradeCase {
  static const schema = 'beecount.rule_upgrade.expected.v1';

  final String status;
  final String caseId;
  final String imagePath;
  final String sourceApp;
  final String? ocrText;
  final String? ocrEngine;
  final Map<String, dynamic> expected;
  final Map<String, dynamic>? currentRuleResult;
  final Map<String, dynamic>? currentRuleTrace;
  final Map<String, dynamic>? aiSuggestion;
  final Map<String, dynamic>? finalSuggestion;

  const RuleUpgradeCase({
    required this.status,
    required this.caseId,
    required this.imagePath,
    required this.sourceApp,
    required this.ocrText,
    this.ocrEngine,
    required this.expected,
    this.currentRuleResult,
    this.currentRuleTrace,
    this.aiSuggestion,
    this.finalSuggestion,
  });

  factory RuleUpgradeCase.fromJson(Map<String, dynamic> json) {
    final schemaValue = json['schema']?.toString();
    if (schemaValue != null && schemaValue != schema) {
      throw FormatException('Unsupported rule upgrade schema: $schemaValue');
    }
    return RuleUpgradeCase(
      status: _stringValue(json['status']) ?? 'needs_review',
      caseId: _requiredString(json, 'case_id'),
      imagePath: _requiredString(json, 'image'),
      sourceApp: _requiredString(json, 'source_app'),
      ocrText: _stringValue(json['ocr_text']),
      ocrEngine: _stringValue(json['ocr_engine']),
      expected: _mapValue(json['expected']) ?? <String, dynamic>{},
      currentRuleResult: _mapValue(json['current_rule_result']),
      currentRuleTrace: _mapValue(json['current_rule_trace']),
      aiSuggestion: _mapValue(json['ai_suggestion']),
      finalSuggestion: _mapValue(json['final_suggestion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema': schema,
      'status': status,
      'case_id': caseId,
      'image': imagePath,
      'source_app': sourceApp,
      'ocr_text': ocrText,
      'ocr_engine': ocrEngine,
      'expected': expected,
      if (currentRuleResult != null) 'current_rule_result': currentRuleResult,
      if (currentRuleTrace != null) 'current_rule_trace': currentRuleTrace,
      if (aiSuggestion != null) 'ai_suggestion': aiSuggestion,
      if (finalSuggestion != null) 'final_suggestion': finalSuggestion,
    };
  }
}

class RuleUpgradeExpectedPreparer {
  static RuleUpgradeCase prepare({
    required String caseId,
    required String imagePath,
    required String sourceApp,
    String? goldenJsonText,
    String? actualJsonText,
  }) {
    final goldenCase = _findGoldenCase(
      caseId: caseId,
      imagePath: imagePath,
      goldenJsonText: goldenJsonText,
    );
    final actualEnvelope = _findActualEnvelope(
      caseId: caseId,
      imagePath: imagePath,
      goldenCase: goldenCase,
      actualJsonText: actualJsonText,
    );
    final finalSuggestion = _mapValue(actualEnvelope?['final']);
    final aiSuggestion = _mapValue(actualEnvelope?['ai']);
    final ocrTrace = _traceData(actualEnvelope, 'ocr');
    final expected = _completeExpectedFields({
      if (goldenCase != null) ...goldenCase.expected,
      if (goldenCase == null && finalSuggestion != null) ...finalSuggestion,
      if (goldenCase == null && finalSuggestion == null && aiSuggestion != null)
        ...aiSuggestion,
    });

    return RuleUpgradeCase(
      status: 'needs_review',
      caseId: caseId,
      imagePath: imagePath,
      sourceApp: sourceApp,
      ocrText: _stringValue(actualEnvelope?['ocrText'] ??
          actualEnvelope?['ocr_text'] ??
          actualEnvelope?['rawText'] ??
          ocrTrace?['rawText']),
      ocrEngine: _stringValue(ocrTrace?['engine'] ??
          actualEnvelope?['ocrEngine'] ??
          actualEnvelope?['ocr_engine'] ??
          finalSuggestion?['ocr_engine']),
      expected: expected,
      currentRuleResult: _mapValue(actualEnvelope?['rule']),
      currentRuleTrace: _traceData(actualEnvelope, 'billing_rule'),
      aiSuggestion: aiSuggestion,
      finalSuggestion: finalSuggestion,
    );
  }

  static ImageBillingGoldenCase? _findGoldenCase({
    required String caseId,
    required String imagePath,
    required String? goldenJsonText,
  }) {
    if (goldenJsonText == null || goldenJsonText.trim().isEmpty) {
      return null;
    }
    final cases = parseImageBillingGoldenCases(goldenJsonText);
    final normalizedImage = _normalizePath(imagePath);
    for (final c in cases) {
      if (c.id == caseId || _normalizePath(c.image) == normalizedImage) {
        return c;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findActualEnvelope({
    required String caseId,
    required String imagePath,
    required ImageBillingGoldenCase? goldenCase,
    required String? actualJsonText,
  }) {
    if (actualJsonText == null || actualJsonText.trim().isEmpty) return null;
    final store = ImageBillingActualStore.fromJson(jsonDecode(actualJsonText));
    if (goldenCase != null) return store.findFor(goldenCase);

    final syntheticGolden = ImageBillingGoldenCase(
      id: caseId,
      image: imagePath,
      sourceApp: '',
      expected: const {},
      expectedAny: const {},
      forbidden: const {},
      evidence: const [],
    );
    return store.findFor(syntheticGolden);
  }
}

class RuleUpgradeCandidateGenerator {
  static String generate(RuleUpgradeCase upgradeCase) {
    final id = '${_identifier(upgradeCase.caseId)}_candidate_v1';
    final expected = upgradeCase.expected;
    final ocrText = upgradeCase.ocrText ?? '';
    final timeLabel = _firstExistingLabel(
      ocrText,
      const ['支付时间', '交易时间', '下单时间', '创建时间'],
    );
    final paymentMethodLabel = _firstExistingLabel(
      ocrText,
      const ['付款方式', '支付方式', '卡号'],
    );
    final merchantLabel = _firstExistingLabel(
      ocrText,
      const ['商户全称', '收款方全称', '商户名称'],
    );
    final acquirerLabel = _firstExistingLabel(
      ocrText,
      const ['收单机构', '清算机构'],
    );

    final keywordsAll = <String>[
      if (timeLabel != null) timeLabel,
      if (paymentMethodLabel != null) paymentMethodLabel,
    ];
    final keywordsAny = _keywordEvidence(ocrText, upgradeCase.sourceApp);

    final buffer = StringBuffer()
      ..writeln('# Candidate generated by rule_upgrade.dart.')
      ..writeln('# Review before merging into assets/rules/billing_rules.toml.')
      ..writeln()
      ..writeln('schemaVersion = 1')
      ..writeln('rulePackageVersion = 1')
      ..writeln(
          'rulesVersion = ${_tomlString('candidate.${upgradeCase.caseId}')}')
      ..writeln('normalizationVersion = 1')
      ..writeln('compatibleNormalizationVersions = [1]')
      ..writeln()
      ..writeln('[[templates]]')
      ..writeln('id = ${_tomlString(id)}')
      ..writeln('enabled = true')
      ..writeln('priority = 110')
      ..writeln('baseConfidence = 0.88')
      ..writeln()
      ..writeln('[templates.match]')
      ..writeln(
          'appNameKeywords = ${_tomlStringList([upgradeCase.sourceApp])}');

    if (keywordsAll.isNotEmpty) {
      buffer.writeln('keywordsAll = ${_tomlStringList(keywordsAll)}');
    }
    if (keywordsAny.isNotEmpty) {
      buffer.writeln('keywordsAny = ${_tomlStringList(keywordsAny)}');
    }

    _writeConstantExtractor(
      buffer,
      field: 'paymentChannel',
      value: _expectedString(expected, 'payment_channel'),
      confidence: 0.95,
    );
    _writeRegexExtractor(
      buffer,
      field: 'amount',
      pattern:
          r'^\s*((?:[-−+]?\s*[¥￥]?\s*|[¥￥]\s*[-−+]?\s*)\d{1,6}\.\d{1,2})\s*(?:元)?\s*$',
      parser: 'signedAmount',
      confidence: 0.9,
    );
    final expectedTime = _expectedString(expected, 'time');
    if (expectedTime != null && ocrText.contains('年')) {
      _writeRegexExtractor(
        buffer,
        field: 'time',
        pattern: r'(\d{4}年\s*\d{1,2}\s*月\s*\d{1,2}\s*日\s+\d{1,2}:\d{2}:\d{2})',
        parser: 'zhDatetime',
        confidence: 0.9,
      );
    } else if (expectedTime != null) {
      _writeRegexExtractor(
        buffer,
        field: 'time',
        pattern: r'(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})',
        parser: 'isoDatetime',
        confidence: 0.9,
      );
    } else if (timeLabel != null) {
      _writeLabelNextLineExtractor(
        buffer,
        field: 'time',
        label: timeLabel,
        parser: _timeParserForLabelValue(ocrText, timeLabel),
        confidence: 0.88,
      );
    }
    if (paymentMethodLabel != null) {
      _writeRegexExtractor(
        buffer,
        field: 'paymentMethod',
        pattern: _paymentMethodPattern(),
        parser: 'paymentMethod',
        confidence: 0.84,
      );
    }
    if (merchantLabel != null) {
      _writeLabelNextLineExtractor(
        buffer,
        field: 'merchantFullName',
        label: merchantLabel,
        confidence: 0.8,
      );
    }
    final acquirer = _expectedString(expected, 'acquirer');
    if (acquirer != null) {
      _writeRegexExtractor(
        buffer,
        field: 'acquirer',
        pattern:
            r'([^\n]{2,40}(?:支付[科料]技有限公司|支付服务股份有限公司|支付服务有限公司|付费通支付服务有限公司|网络技术有限公司))',
        parser: 'institutionName',
        confidence: 0.82,
      );
    } else if (acquirerLabel != null) {
      _writeLabelNextLineExtractor(
        buffer,
        field: 'acquirer',
        label: acquirerLabel,
        confidence: 0.78,
      );
    }
    _writeRemainingDetailsExtractor(
      buffer,
      excludeLabels: [
        if (timeLabel != null) timeLabel,
        if (paymentMethodLabel != null) paymentMethodLabel,
        if (acquirerLabel != null) acquirerLabel,
        '当前状态',
        '交易状态',
        '交易单号',
        '商户单号',
        '订单号',
        '商家订单号',
        '商品单号',
      ],
    );

    return buffer.toString();
  }
}

class RuleUpgradeVerificationResult {
  final Map<String, dynamic> actual;
  final Map<String, Object?>? paymentMethodReport;
  final List<String> failures;
  final List<String> candidateTemplateIds;
  final String mode;
  final RuleUpgradeRegressionResult? regression;

  const RuleUpgradeVerificationResult({
    required this.actual,
    this.paymentMethodReport,
    required this.failures,
    this.candidateTemplateIds = const [],
    this.mode = 'standalone',
    this.regression,
  });

  bool get passed => failures.isEmpty;

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'mode': mode,
        'candidate_template_ids': candidateTemplateIds,
        'actual': actual,
        if (paymentMethodReport != null) 'paymentMethod': paymentMethodReport,
        'failures': failures,
        if (regression != null) 'regression': regression!.toJson(),
      };
}

class RuleUpgradeRegressionSample {
  final String id;
  final String ocrText;
  final String? sourcePackage;
  final String? sourceAppName;
  final Map<String, Object?> expected;

  const RuleUpgradeRegressionSample({
    required this.id,
    required this.ocrText,
    this.sourcePackage,
    this.sourceAppName,
    this.expected = const {},
  });
}

class RuleUpgradeRegressionResult {
  final List<Map<String, dynamic>> samples;

  const RuleUpgradeRegressionResult({
    required this.samples,
  });

  bool get passed => samples.every((sample) => sample['passed'] == true);

  int get failedCount =>
      samples.where((sample) => sample['passed'] != true).length;

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'failed_count': failedCount,
        'samples': samples,
      };
}

class RuleUpgradeCandidateVerifier {
  static Future<RuleUpgradeVerificationResult> verify({
    required RuleUpgradeCase upgradeCase,
    required String candidateToml,
    String? baseToml,
    bool requireCandidateMatch = true,
    List<RuleUpgradeRegressionSample> regressionSamples = const [],
  }) async {
    final ocrText = upgradeCase.ocrText?.trim();
    if (ocrText == null || ocrText.isEmpty) {
      return const RuleUpgradeVerificationResult(
        actual: {},
        failures: ['ocr_text is required'],
      );
    }

    final candidateRuleSet = _parseRuleSet(candidateToml);
    final candidateTemplateIds =
        candidateRuleSet.templates.map((template) => template.id).toSet();
    final ruleSet = baseToml == null
        ? candidateRuleSet
        : _mergeRuleSets(
            baseRuleSet: _parseRuleSet(baseToml),
            candidateRuleSet: candidateRuleSet,
          );
    final candidateFields = _candidateFields(candidateRuleSet);
    final ruleResult = await BillingRuleEngineImpl().evaluate(
      ruleSet: ruleSet,
      ocrText: ocrText,
      sourceAppName: upgradeCase.sourceApp,
    );
    final actual = ruleResult.toJson();
    final failures = _compareExpected(
      upgradeCase.expected,
      actual,
      candidateFields: candidateFields,
    );
    if (baseToml != null &&
        requireCandidateMatch &&
        !candidateTemplateIds.contains(ruleResult.matchedTemplateId)) {
      failures.add(
        'candidate_template: expected one of '
        '${candidateTemplateIds.join(", ")}, actual '
        '${ruleResult.matchedTemplateId ?? "null"}',
      );
    }
    final regression = baseToml == null || regressionSamples.isEmpty
        ? null
        : await _verifyRegression(
            ruleSet: ruleSet,
            samples: regressionSamples,
          );
    if (regression != null && !regression.passed) {
      failures.add(
        'regression: ${regression.failedCount} existing sample(s) failed',
      );
    }
    return RuleUpgradeVerificationResult(
      actual: actual,
      paymentMethodReport: _paymentMethodReport(
        ruleResult,
        upgradeCase.expected['payment_method'],
      ),
      failures: failures,
      candidateTemplateIds: candidateTemplateIds.toList(growable: false),
      mode: baseToml == null ? 'standalone' : 'merged',
      regression: regression,
    );
  }
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

Future<RuleUpgradeRegressionResult> _verifyRegression({
  required BillingRuleSet ruleSet,
  required List<RuleUpgradeRegressionSample> samples,
}) async {
  final results = <Map<String, dynamic>>[];
  for (final sample in samples) {
    final result = await BillingRuleEngineImpl().evaluate(
      ruleSet: ruleSet,
      ocrText: sample.ocrText,
      sourcePackage: sample.sourcePackage,
      sourceAppName: sample.sourceAppName,
    );
    final actual = result.toJson();
    final failures = _compareRegressionExpected(sample.expected, actual);
    results.add({
      'id': sample.id,
      'passed': failures.isEmpty,
      'expected': sample.expected,
      'actual': actual,
      'failures': failures,
    });
  }
  return RuleUpgradeRegressionResult(samples: results);
}

List<String> _compareRegressionExpected(
  Map<String, Object?> expected,
  Map<String, dynamic> actual,
) {
  final failures = <String>[];
  for (final entry in expected.entries) {
    final actualKey = _actualRegressionKey(entry.key);
    final actualValue = actual[actualKey];
    if (!_looselyEqualValue(actualKey, actualValue, entry.value)) {
      failures
          .add('${entry.key}: expected ${entry.value}, actual $actualValue');
    }
  }
  return failures;
}

String _actualRegressionKey(String key) {
  return switch (key) {
    'matchedTemplateId' => 'matched_template_id',
    'paymentChannel' => 'payment_channel',
    'paymentMethod' => 'payment_method',
    'merchantFullName' => 'merchant_full_name',
    _ => _snakeCase(key),
  };
}

BillingRuleSet _mergeRuleSets({
  required BillingRuleSet baseRuleSet,
  required BillingRuleSet candidateRuleSet,
}) {
  final candidateIds =
      candidateRuleSet.templates.map((template) => template.id).toSet();
  final baseTemplates = baseRuleSet.templates
      .where((template) => !candidateIds.contains(template.id))
      .toList(growable: false);
  return BillingRuleSet(
    schemaVersion: baseRuleSet.schemaVersion,
    rulesVersion:
        '${baseRuleSet.rulesVersion}+candidate.${candidateRuleSet.rulesVersion}',
    paymentChannels: baseRuleSet.paymentChannels,
    templates: [
      ...baseTemplates,
      ...candidateRuleSet.templates,
    ],
  );
}

BillingRuleSet _parseRuleSet(String toml) {
  final map = TomlDocument.parse(toml).toMap();
  return BillingRuleSet(
    schemaVersion: _requiredInt(map, 'schemaVersion'),
    rulesVersion: _requiredString(map, 'rulesVersion'),
    paymentChannels: const [],
    templates: _parseTemplates(map['templates']),
  );
}

List<BillingRuleTemplate> _parseTemplates(Object? value) {
  if (value is! List) {
    throw const FormatException('templates must be an array');
  }
  return value.map((item) {
    final map = _asMap(item, 'templates item');
    final id = _requiredString(map, 'id');
    return BillingRuleTemplate(
      id: id,
      enabled: _optionalBool(map['enabled'], true, 'enabled'),
      priority: _optionalInt(map['priority'], 0, 'priority'),
      baseConfidence:
          _optionalDouble(map['baseConfidence'], 0.8, 'baseConfidence'),
      origin: BillingRuleOrigin.values.byName(
        _optionalString(map['origin'], 'origin') ?? 'public',
      ),
      revision: _optionalInt(map['revision'], 1, 'revision'),
      extractorSelection: BillingExtractorSelection.values.byName(
        _optionalString(map['extractorSelection'], 'extractorSelection') ??
            'firstSuccessful',
      ),
      match: _parseMatch(map['match']),
      extractors: _parseExtractors(id, map['extract']),
    );
  }).toList(growable: false);
}

BillingRuleTemplateMatch _parseMatch(Object? value) {
  if (value == null) return const BillingRuleTemplateMatch();
  final map = _asMap(value, 'templates.match');
  return BillingRuleTemplateMatch(
    sourcePackages: _stringList(map['sourcePackages']),
    requiredSource:
        _optionalBool(map['requiredSource'], false, 'requiredSource'),
    appNameKeywords: _stringList(map['appNameKeywords']),
    keywordsAll: _stringList(map['keywordsAll']),
    keywordsAny: _stringList(map['keywordsAny']),
  );
}

List<BillingFieldExtractorRule> _parseExtractors(
  String templateId,
  Object? value,
) {
  if (value is! List) {
    throw const FormatException('templates.extract must be an array');
  }
  return value.map((item) {
    final map = _asMap(item, 'templates.extract item');
    return BillingFieldExtractorRule(
      id: _optionalString(map['id'], 'id'),
      field: _requiredString(map, 'field'),
      type: _requiredString(map, 'type'),
      value: _optionalString(map['value'], 'value'),
      label: _optionalString(map['label'], 'label'),
      parser: _optionalString(map['parser'], 'parser'),
      pattern: _optionalString(map['pattern'], 'pattern'),
      confidence: _optionalDouble(map['confidence'], 0.8, 'confidence'),
      options: _optionsMap(map['options']),
    ).withResolvedId(templateId);
  }).toList(growable: false);
}

void _writeRemainingDetailsExtractor(
  StringBuffer buffer, {
  required List<String> excludeLabels,
}) {
  buffer
    ..writeln()
    ..writeln('[[templates.extract]]')
    ..writeln('field = "details.remaining_text"')
    ..writeln('type = "remainingLines"')
    ..writeln('parser = "raw"')
    ..writeln('confidence = 0.7')
    ..writeln('[templates.extract.options]')
    ..writeln(
      'excludeLabels = ${_tomlStringList(excludeLabels.toSet().toList())}',
    );
}

List<String> _compareExpected(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual, {
  Set<String>? candidateFields,
}) {
  final failures = <String>[];
  for (final entry in expected.entries) {
    if (entry.value == null) continue;
    if (!_verifiableExpectedFields.contains(entry.key)) continue;
    if (candidateFields != null && !candidateFields.contains(entry.key)) {
      continue;
    }
    final actualValue = actual[entry.key];
    if (!_looselyEqualValue(entry.key, actualValue, entry.value)) {
      failures.add(
        '${entry.key}: expected ${entry.value}, actual $actualValue',
      );
    }
  }
  if (actual['matched_template_id'] == null) {
    failures
        .add('matched_template_id: expected a matched template, actual null');
  }
  return failures;
}

Set<String> _candidateFields(BillingRuleSet ruleSet) {
  return {
    for (final template in ruleSet.templates)
      for (final extractor in template.extractors)
        _resultFieldName(extractor.field),
  };
}

String _resultFieldName(String extractorField) {
  final root = extractorField.split('.').first;
  return switch (root) {
    'paymentChannel' => 'payment_channel',
    'paymentMethod' => 'payment_method',
    'merchantFullName' => 'merchant_full_name',
    _ => _snakeCase(root),
  };
}

const _verifiableExpectedFields = {
  'amount',
  'time',
  'note',
  'payment_channel',
  'payment_method',
  'counterparty',
  'merchant_full_name',
  'acquirer',
  'details',
};

bool _looselyEqualValue(String field, Object? actual, Object? expected) {
  if (field == 'amount') {
    final a = _asDouble(actual);
    final e = _asDouble(expected);
    return a != null && e != null && (a - e).abs() <= 0.005;
  }
  if (field == 'time') {
    final a = _asDateTime(actual);
    final e = _asDateTime(expected);
    if (a != null && e != null) {
      return a.difference(e).inSeconds.abs() <= 1;
    }
  }
  if (field == 'details') {
    return _detailsMatch(actual, expected);
  }
  return _normalizeText(actual) == _normalizeText(expected);
}

Map<String, dynamic> _completeExpectedFields(Map<String, dynamic> source) {
  return {
    for (final field in _completeExpectedFieldOrder) field: source[field],
  };
}

const _completeExpectedFieldOrder = [
  'amount',
  'type',
  'time',
  'note',
  'category',
  'account',
  'payment_channel',
  'payment_method',
  'counterparty',
  'merchant_full_name',
  'acquirer',
  'details',
];

bool _detailsMatch(Object? actual, Object? expected) {
  if (expected == null) return true;
  if (actual == null) return false;
  return _normalizeText(actual is String ? actual : jsonEncode(actual))
      .isNotEmpty;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

String _normalizeText(Object? value) {
  return value?.toString().trim().replaceAll(RegExp(r'\s+'), '') ?? '';
}

Map<String, dynamic>? _traceData(
  Map<String, dynamic>? actualEnvelope,
  String stage,
) {
  final traces = actualEnvelope?['traces'];
  if (traces is! List) return null;
  for (final trace in traces) {
    if (trace is! Map) continue;
    if (trace['stage']?.toString() != stage) continue;
    return _mapValue(trace['data']);
  }
  return null;
}

String? _expectedString(Map<String, dynamic> expected, String key) {
  final value = expected[key];
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _firstExistingLabel(String text, List<String> labels) {
  for (final label in labels) {
    if (text.contains(label)) return label;
  }
  return null;
}

String _paymentMethodPattern() {
  return r'([^\n]{2,40}(?:银行|信用卡|储蓄卡|借记卡|月付|零钱|余额|花呗|白条|云闪付|支付宝|微信支付)[^\n]{0,30}(?:\(\d{3,6}\)|\[\d{3,6}\])?)';
}

List<String> _keywordEvidence(String ocrText, String sourceApp) {
  final candidates = <String>[
    sourceApp,
    '账单详情',
    '支付成功',
    '交易成功',
    '当前状态',
    '银联交易详情',
    '订单详情',
    '交易单号',
    '商户单号',
  ];
  final result = <String>[];
  for (final item in candidates) {
    if (item.trim().isNotEmpty && ocrText.contains(item)) {
      result.add(item);
    }
  }
  return result.toSet().toList(growable: false);
}

String _timeParserForLabelValue(String ocrText, String label) {
  final lines =
      ocrText.split(RegExp(r'\r\n|\n|\r')).map((e) => e.trim()).toList();
  for (var i = 0; i < lines.length - 1; i++) {
    if (lines[i].contains(label)) {
      return lines[i + 1].contains('-') ? 'isoDatetime' : 'zhDatetime';
    }
  }
  return 'isoDatetime';
}

void _writeConstantExtractor(
  StringBuffer buffer, {
  required String field,
  required String? value,
  String? parser,
  required double confidence,
}) {
  if (value == null) return;
  buffer
    ..writeln()
    ..writeln('[[templates.extract]]')
    ..writeln('field = ${_tomlString(field)}')
    ..writeln('type = "constant"')
    ..writeln('value = ${_tomlString(value)}');
  if (parser != null) {
    buffer.writeln('parser = ${_tomlString(parser)}');
  }
  buffer.writeln('confidence = $confidence');
}

void _writeRegexExtractor(
  StringBuffer buffer, {
  required String field,
  required String pattern,
  required String parser,
  required double confidence,
}) {
  buffer
    ..writeln()
    ..writeln('[[templates.extract]]')
    ..writeln('field = ${_tomlString(field)}')
    ..writeln('type = "regex"')
    ..writeln('pattern = ${_tomlString(pattern)}')
    ..writeln('parser = ${_tomlString(parser)}')
    ..writeln('confidence = $confidence');
}

void _writeLabelNextLineExtractor(
  StringBuffer buffer, {
  required String field,
  required String label,
  String? parser,
  required double confidence,
}) {
  buffer
    ..writeln()
    ..writeln('[[templates.extract]]')
    ..writeln('field = ${_tomlString(field)}')
    ..writeln('type = "labelNextLine"')
    ..writeln('label = ${_tomlString(label)}');
  if (parser != null) {
    buffer.writeln('parser = ${_tomlString(parser)}');
  }
  buffer.writeln('confidence = $confidence');
}

String _identifier(String value) {
  final result = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return result.isEmpty ? 'rule_upgrade' : result;
}

String _snakeCase(String value) {
  return value.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}

String _tomlString(String value) => jsonEncode(value);

String _tomlStringList(List<String> values) {
  return '[${values.map(_tomlString).join(', ')}]';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _stringValue(json[key]);
  if (value == null) throw FormatException('$key is required');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

int _optionalInt(Object? value, int fallback, String key) {
  if (value == null) return fallback;
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

double _optionalDouble(Object? value, double fallback, String key) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  throw FormatException('$key must be a number');
}

bool _optionalBool(Object? value, bool fallback, String key) {
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

String? _optionalString(Object? value, String key) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

Map<String, dynamic> _asMap(Object? value, String name) {
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('$name must be a map');
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Expected a string array');
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, dynamic> _optionsMap(Object? value) {
  if (value == null) return const {};
  if (value is Map) return Map.unmodifiable(value.cast<String, dynamic>());
  throw const FormatException('options must be a map');
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _normalizePath(String value) => value.replaceAll('\\', '/');
