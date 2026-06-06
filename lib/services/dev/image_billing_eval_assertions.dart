import 'dart:convert';
import 'dart:io';

ImageBillingEvalResult evaluateImageBilling({
  required String goldenJsonText,
  ImageBillingActualStore? actualStore,
  bool checkImageExists = true,
}) {
  final cases = parseImageBillingGoldenCases(goldenJsonText);
  final store = actualStore ?? ImageBillingActualStore.empty();
  final rows = cases
      .map(
        (c) => _evaluate(
          c,
          store.findFor(c),
          checkImageExists: checkImageExists,
        ),
      )
      .toList();

  return ImageBillingEvalResult(rows: rows);
}

ImageBillingEvalSummary evaluateImageBillingPayload({
  required String goldenJsonText,
  required String actualJsonText,
  bool requireActual = true,
}) {
  final actualStore = ImageBillingActualStore.fromJson(
    jsonDecode(actualJsonText),
  );
  final result = evaluateImageBilling(
    goldenJsonText: goldenJsonText,
    actualStore: actualStore,
    checkImageExists: false,
  );
  return result.summary(requireActual: requireActual, requireImages: false);
}

List<ImageBillingGoldenCase> parseImageBillingGoldenCases(
  String goldenJsonText,
) {
  final goldenJson = jsonDecode(goldenJsonText);
  if (goldenJson is! Map) {
    throw const FormatException('Golden JSON root must be an object');
  }

  final cases = goldenJson['cases'];
  if (cases is! List) return const [];

  return cases
      .map(
        (item) => ImageBillingGoldenCase.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
      )
      .toList();
}

class ImageBillingEvalResult {
  final List<ImageBillingEvalRow> rows;

  const ImageBillingEvalResult({required this.rows});

  ImageBillingEvalSummary summary({
    required bool requireActual,
    required bool requireImages,
  }) {
    return ImageBillingEvalSummary.fromRows(
      rows,
      requireActual: requireActual,
      requireImages: requireImages,
    );
  }
}

class ImageBillingEvalSummary {
  final int total;
  final int withActual;
  final int failed;
  final List<String> failureDescriptions;

  const ImageBillingEvalSummary({
    required this.total,
    required this.withActual,
    required this.failed,
    required this.failureDescriptions,
  });

  bool get passed => failed == 0;

  factory ImageBillingEvalSummary.fromRows(
    List<ImageBillingEvalRow> rows, {
    required bool requireActual,
    required bool requireImages,
  }) {
    final failures = <String>[];

    for (final row in rows) {
      final c = row.goldenCase;
      if (requireImages && !row.imageExists) {
        failures.add('${c.id}: image missing (${c.image})');
      }
      if (requireActual && row.finalActual == null) {
        failures.add('${c.id}: actual result missing');
      }
      for (final check in row.checks.where((check) => check.isFailure)) {
        failures.add(
          '${c.id}: ${check.field} expected ${check.displayExpected}, '
          'actual ${check.actual}',
        );
      }
    }

    return ImageBillingEvalSummary(
      total: rows.length,
      withActual: rows.where((row) => row.finalActual != null).length,
      failed: failures.length,
      failureDescriptions: failures,
    );
  }
}

class ImageBillingActualStore {
  final Map<String, Map<String, dynamic>> byId;
  final Map<String, Map<String, dynamic>> byImageBasename;

  ImageBillingActualStore.empty()
      : byId = <String, Map<String, dynamic>>{},
        byImageBasename = <String, Map<String, dynamic>>{};

  ImageBillingActualStore({
    required this.byId,
    required this.byImageBasename,
  });

  factory ImageBillingActualStore.fromJson(dynamic json) {
    final store = ImageBillingActualStore.empty();
    store.mergeJson(json);
    return store;
  }

  void mergeJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Actual JSON root must be an object');
    }

    final root = Map<String, dynamic>.from(json);
    final cases = root['cases'];
    if (cases is List) {
      for (final item in cases) {
        final data = Map<String, dynamic>.from(item as Map);
        final id = data['id']?.toString();
        final image = data['image']?.toString();
        if (id != null && id.isNotEmpty) {
          byId[id] = data;
        }
        if (image != null && image.isNotEmpty) {
          byImageBasename[_basenameWithoutExtension(image)] = data;
          byImageBasename[_basename(image)] = data;
        }
      }
      return;
    }

    for (final entry in root.entries) {
      if (entry.value is Map) {
        byId[entry.key] = Map<String, dynamic>.from(entry.value as Map);
      }
    }
  }

  void mergeDirectory(Directory dir) {
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final json = jsonDecode(entity.readAsStringSync());
      if (json is! Map) {
        throw FormatException(
          'Actual JSON file root must be an object: ${entity.path}',
        );
      }
      final data = Map<String, dynamic>.from(json);
      final key = _basenameWithoutExtension(entity.path);
      byId.putIfAbsent(key, () => data);
      byImageBasename.putIfAbsent(key, () => data);
    }
  }

  Map<String, dynamic>? findFor(ImageBillingGoldenCase c) {
    return byId[c.id] ??
        byImageBasename[_basenameWithoutExtension(c.image)] ??
        byImageBasename[_basename(c.image)];
  }
}

class ImageBillingGoldenCase {
  final String id;
  final String image;
  final String sourceApp;
  final Map<String, dynamic> expected;
  final Map<String, List<dynamic>> expectedAny;
  final Map<String, List<dynamic>> forbidden;
  final List<String> evidence;

  const ImageBillingGoldenCase({
    required this.id,
    required this.image,
    required this.sourceApp,
    required this.expected,
    required this.expectedAny,
    required this.forbidden,
    required this.evidence,
  });

  factory ImageBillingGoldenCase.fromJson(Map<String, dynamic> json) {
    final forbiddenRaw = (json['forbidden'] as Map?) ?? const {};
    final expectedAnyRaw = (json['expected_any'] as Map?) ?? const {};
    return ImageBillingGoldenCase(
      id: json['id'] as String,
      image: json['image'] as String,
      sourceApp: json['source_app'] as String? ?? '',
      expected: Map<String, dynamic>.from(json['expected'] as Map),
      expectedAny: expectedAnyRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value : [value],
        ),
      ),
      forbidden: forbiddenRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value : [value],
        ),
      ),
      evidence: ((json['evidence'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ImageBillingEvalRow {
  final ImageBillingGoldenCase goldenCase;
  final bool imageExists;
  final Map<String, dynamic>? actualEnvelope;
  final Map<String, dynamic>? finalActual;
  final List<ImageBillingFieldCheck> checks;

  const ImageBillingEvalRow({
    required this.goldenCase,
    required this.imageExists,
    required this.actualEnvelope,
    required this.finalActual,
    required this.checks,
  });

  bool get hasFailure => !imageExists || checks.any((check) => check.isFailure);

  ImageBillingFieldCheck? checkFor(String field) {
    for (final check in checks) {
      if (check.field == field &&
          check.status == ImageBillingCheckStatus.fail) {
        return check;
      }
    }
    for (final check in checks) {
      if (check.field == field) return check;
    }
    return null;
  }
}

class ImageBillingFieldCheck {
  final String field;
  final dynamic expected;
  final List<dynamic> allowedValues;
  final dynamic actual;
  final ImageBillingCheckStatus status;

  const ImageBillingFieldCheck({
    required this.field,
    required this.expected,
    required this.allowedValues,
    required this.actual,
    required this.status,
  });

  bool get isFailure => status == ImageBillingCheckStatus.fail;

  Object? get displayExpected {
    return allowedValues.length <= 1 ? expected : allowedValues;
  }
}

enum ImageBillingCheckStatus { pass, warn, fail }

ImageBillingEvalRow _evaluate(
  ImageBillingGoldenCase c,
  Map<String, dynamic>? actualEnvelope, {
  bool checkImageExists = true,
}) {
  final imageExists = !checkImageExists || File(c.image).existsSync();
  final actual = _extractFinalActual(actualEnvelope);
  final degradeAiFields = _shouldDegradeAiFieldChecks(actualEnvelope, actual);
  final checks = <ImageBillingFieldCheck>[];

  if (actual != null) {
    for (final entry in c.expected.entries) {
      checks.add(
        _degradeAiCheckIfNeeded(
          _compareField(
            entry.key,
            entry.value,
            c.expectedAny[entry.key] ?? const [],
            actual[entry.key],
          ),
          degradeAiFields,
        ),
      );
    }

    for (final entry in c.forbidden.entries) {
      final actualValue = actual[entry.key];
      if (actualValue == null) continue;

      for (final forbiddenValue in entry.value) {
        if (_looselyEqual(entry.key, actualValue, forbiddenValue)) {
          checks.add(
            _degradeAiCheckIfNeeded(
              ImageBillingFieldCheck(
                field: entry.key,
                expected: 'not $forbiddenValue',
                allowedValues: ['not $forbiddenValue'],
                actual: actualValue,
                status: ImageBillingCheckStatus.fail,
              ),
              degradeAiFields,
            ),
          );
        }
      }
    }
  }

  return ImageBillingEvalRow(
    goldenCase: c,
    imageExists: imageExists,
    actualEnvelope: actualEnvelope,
    finalActual: actual,
    checks: checks,
  );
}

bool _shouldDegradeAiFieldChecks(
  Map<String, dynamic>? actualEnvelope,
  Map<String, dynamic>? actual,
) {
  if (actualEnvelope == null || actual == null) return false;
  if (actual['aiEnhanced'] != false) return false;

  final rule = actualEnvelope['rule'];
  if (rule is! Map) return false;
  final detected = rule['detected_payment_channel'];
  if (detected is! Map) return false;
  final channel = detected['channel']?.toString().trim();
  return channel != null && channel.isNotEmpty;
}

ImageBillingFieldCheck _degradeAiCheckIfNeeded(
  ImageBillingFieldCheck check,
  bool degradeAiFields,
) {
  if (!degradeAiFields ||
      check.status != ImageBillingCheckStatus.fail ||
      !_aiDependentFields.contains(check.field)) {
    return check;
  }
  return ImageBillingFieldCheck(
    field: check.field,
    expected: check.expected,
    allowedValues: check.allowedValues,
    actual: check.actual,
    status: ImageBillingCheckStatus.warn,
  );
}

const _aiDependentFields = {
  'type',
  'note',
  'category',
  'payment_method',
  'counterparty',
  'payment_channel',
  'merchant_full_name',
  'acquirer',
  'details',
};

Map<String, dynamic>? _extractFinalActual(Map<String, dynamic>? envelope) {
  if (envelope == null) return null;

  final finalResult = envelope['final'] ?? envelope['finalResult'];
  if (finalResult is Map) {
    return Map<String, dynamic>.from(finalResult);
  }

  final mergedResult = envelope['merged'] ?? envelope['result'];
  if (mergedResult is Map) {
    return Map<String, dynamic>.from(mergedResult);
  }

  final hasInlineFields = envelope.containsKey('amount') ||
      envelope.containsKey('time') ||
      envelope.containsKey('note') ||
      envelope.containsKey('counterparty');
  if (hasInlineFields) {
    return envelope;
  }

  return null;
}

ImageBillingFieldCheck _compareField(
  String field,
  dynamic expected,
  List<dynamic> alternatives,
  dynamic actual,
) {
  final allowedValues = <dynamic>[expected, ...alternatives];

  if (field == 'details') {
    return _compareDetailsField(field, expected, alternatives, actual);
  }

  if (expected is Map) {
    return _compareMapField(field, expected, alternatives, actual);
  }

  if (actual == null) {
    final pass = allowedValues.any((value) => value == null);
    return ImageBillingFieldCheck(
      field: field,
      expected: expected,
      allowedValues: allowedValues,
      actual: null,
      status:
          pass ? ImageBillingCheckStatus.pass : ImageBillingCheckStatus.fail,
    );
  }

  if (expected == null && alternatives.isEmpty) {
    return ImageBillingFieldCheck(
      field: field,
      expected: null,
      allowedValues: allowedValues,
      actual: actual,
      status: ImageBillingCheckStatus.warn,
    );
  }

  final pass = allowedValues.any((value) {
    return value != null && _looselyEqual(field, actual, value);
  });

  return ImageBillingFieldCheck(
    field: field,
    expected: expected,
    allowedValues: allowedValues,
    actual: actual,
    status: pass ? ImageBillingCheckStatus.pass : ImageBillingCheckStatus.fail,
  );
}

ImageBillingFieldCheck _compareDetailsField(
  String field,
  dynamic expected,
  List<dynamic> alternatives,
  dynamic actual,
) {
  final allowedValues = <dynamic>[expected, ...alternatives];
  final expectedTokens = _detailsTokens(expected);

  if (expectedTokens.isEmpty) {
    return ImageBillingFieldCheck(
      field: field,
      expected: expected,
      allowedValues: allowedValues,
      actual: actual,
      status: actual == null
          ? ImageBillingCheckStatus.pass
          : ImageBillingCheckStatus.warn,
    );
  }

  if (actual == null) {
    return ImageBillingFieldCheck(
      field: field,
      expected: expected,
      allowedValues: allowedValues,
      actual: null,
      status: ImageBillingCheckStatus.fail,
    );
  }

  final actualText = _normalizeText(_detailsText(actual));
  final pass = expectedTokens.every((token) {
    return actualText.contains(_normalizeText(token));
  });

  return ImageBillingFieldCheck(
    field: field,
    expected: expected,
    allowedValues: allowedValues,
    actual: actual,
    status: pass ? ImageBillingCheckStatus.pass : ImageBillingCheckStatus.fail,
  );
}

List<String> _detailsTokens(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is Map) {
    return value.values
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = value.toString().trim();
  return text.isEmpty ? const [] : [text];
}

String _detailsText(dynamic value) {
  if (value is String) return value;
  return jsonEncode(value);
}

ImageBillingFieldCheck _compareMapField(
  String field,
  Map<dynamic, dynamic> expected,
  List<dynamic> alternatives,
  dynamic actual,
) {
  final allowedValues = <dynamic>[expected, ...alternatives];

  if (actual is! Map) {
    return ImageBillingFieldCheck(
      field: field,
      expected: expected,
      allowedValues: allowedValues,
      actual: actual,
      status: ImageBillingCheckStatus.fail,
    );
  }

  final actualMap = Map<String, dynamic>.from(actual);
  final pass = allowedValues.whereType<Map>().any((allowed) {
    final expectedMap = allowed.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return expectedMap.entries.every((entry) {
      return _looselyEqual(
          '$field.${entry.key}', actualMap[entry.key], entry.value);
    });
  });

  return ImageBillingFieldCheck(
    field: field,
    expected: expected,
    allowedValues: allowedValues,
    actual: actual,
    status: pass ? ImageBillingCheckStatus.pass : ImageBillingCheckStatus.fail,
  );
}

bool _looselyEqual(String field, dynamic actual, dynamic expected) {
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

  final actualText = _normalizeFieldText(field, actual);
  final expectedText = _normalizeFieldText(field, expected);
  return actualText == expectedText;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final normalized = value.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }
  return null;
}

String _normalizeFieldText(String field, dynamic value) {
  final text = _normalizeText(value);

  if (field == 'category') {
    return _categoryAliases[text] ?? text;
  }

  if (field == 'payment_method' ||
      field == 'merchant_full_name' ||
      field == 'counterparty') {
    return text.replaceAll('[', '(').replaceAll(']', ')');
  }

  return text;
}

String _normalizeText(dynamic value) {
  return value
      .toString()
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('【', '[')
      .replaceAll('】', ']')
      .replaceAll('［', '[')
      .replaceAll('］', ']');
}

const _categoryAliases = {
  '医疗': '医疗',
  '医疗保健': '医疗',
};

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

String _basenameWithoutExtension(String path) {
  final name = _basename(path);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
