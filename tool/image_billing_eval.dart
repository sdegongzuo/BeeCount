import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beecount/services/dev/image_billing_eval_assertions.dart';

const _defaultGoldenPath = 'tool/image_billing_golden.json';

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options.help) {
    _printHelp();
    return;
  }

  final goldenFile = File(options.goldenPath);
  if (!goldenFile.existsSync()) {
    _fail('Golden file not found: ${options.goldenPath}');
  }

  final goldenText = goldenFile.readAsStringSync();
  final cases = parseImageBillingGoldenCases(goldenText);
  if (cases.isEmpty) {
    _fail('No cases found in ${options.goldenPath}');
  }

  final actualStore = _loadActualStore(
    actualPath: options.actualPath,
    actualDir: options.actualDir,
  );
  final result = evaluateImageBilling(
    goldenJsonText: goldenText,
    actualStore: actualStore,
  );
  final rows = result.rows;

  final report = options.format == _ReportFormat.json
      ? _renderJsonReport(rows)
      : _renderMarkdownReport(
          rows,
          goldenPath: options.goldenPath,
          actualPath: options.actualPath,
          actualDir: options.actualDir,
        );

  if (options.reportPath != null) {
    final reportFile = File(options.reportPath!);
    reportFile.parent.createSync(recursive: true);
    reportFile.writeAsStringSync(report);
    stdout.writeln('Report written: ${reportFile.path}');
  } else {
    stdout.write(report);
  }

  if (options.strict && rows.any((row) => row.hasFailure)) {
    exitCode = 1;
  }
}

ImageBillingActualStore _loadActualStore({
  required String? actualPath,
  required String? actualDir,
}) {
  final store = ImageBillingActualStore.empty();

  if (actualPath != null) {
    final file = File(actualPath);
    if (!file.existsSync()) {
      _fail('Actual file not found: $actualPath');
    }
    store.mergeJson(jsonDecode(file.readAsStringSync()));
  }

  if (actualDir != null) {
    final dir = Directory(actualDir);
    if (!dir.existsSync()) {
      _fail('Actual directory not found: $actualDir');
    }
    store.mergeDirectory(dir);
  }

  return store;
}

String _renderMarkdownReport(
  List<ImageBillingEvalRow> rows, {
  required String goldenPath,
  String? actualPath,
  String? actualDir,
}) {
  final buffer = StringBuffer();
  final passed = rows.where((row) => !row.hasFailure).length;
  final withActual = rows.where((row) => row.finalActual != null).length;
  final evaluated = rows.where((row) => row.finalActual != null).length;
  final evaluatedPassed =
      rows.where((row) => row.finalActual != null && !row.hasFailure).length;

  buffer.writeln('# Image Billing Eval');
  buffer.writeln();
  buffer.writeln('- Golden: `$goldenPath`');
  buffer.writeln('- Actual: `${actualPath ?? actualDir ?? 'not provided'}`');
  buffer.writeln('- Cases: ${rows.length}');
  buffer.writeln('- With actual result: $withActual');
  buffer.writeln('- Passed: $evaluatedPassed/$evaluated evaluated');
  if (evaluated == 0) {
    buffer.writeln('- Status: pending actual OCR/AI exports');
  } else {
    buffer.writeln('- Overall cases without failure: $passed/${rows.length}');
  }
  buffer.writeln();

  buffer.writeln(
    '| Case | Image | Actual | Amount | Type | Time | Note | Category | Counterparty | Payment | Pay Channel | Merchant | Acquirer | Details |',
  );
  buffer.writeln(
      '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');

  for (final row in rows) {
    final c = row.goldenCase;
    final actual = row.finalActual;
    final cells = [
      c.id,
      row.imageExists ? _basename(c.image) : 'missing image',
      actual == null ? 'pending' : (row.hasFailure ? 'fail' : 'pass'),
      _cell(row.checkFor('amount')),
      _cell(row.checkFor('type')),
      _cell(row.checkFor('time')),
      _cell(row.checkFor('note')),
      _cell(row.checkFor('category')),
      _cell(row.checkFor('counterparty')),
      _cell(row.checkFor('payment_method')),
      _cell(row.checkFor('payment_channel')),
      _cell(row.checkFor('merchant_full_name')),
      _cell(row.checkFor('acquirer')),
      _cell(row.checkFor('details')),
    ].map(_mdCell).join(' | ');
    buffer.writeln('| $cells |');
  }

  buffer.writeln();
  buffer.writeln('## Actual Fields');
  buffer.writeln();
  buffer.writeln(
    '| Case | Image | Actual | Amount | Type | Time | Note | Category | Counterparty | Payment | Pay Channel | Merchant | Acquirer | Details |',
  );
  buffer.writeln(
      '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');

  for (final row in rows) {
    final c = row.goldenCase;
    final actual = row.finalActual;
    final cells = [
      c.id,
      row.imageExists ? _basename(c.image) : 'missing image',
      actual == null ? 'pending' : (row.hasFailure ? 'fail' : 'pass'),
      _actualExpectedCell(row, 'amount'),
      _actualExpectedCell(row, 'type'),
      _actualExpectedCell(row, 'time'),
      _actualExpectedCell(row, 'note'),
      _actualExpectedCell(row, 'category'),
      _actualExpectedCell(row, 'counterparty'),
      _actualExpectedCell(row, 'payment_method'),
      _actualExpectedCell(row, 'payment_channel'),
      _actualExpectedCell(row, 'merchant_full_name'),
      _actualExpectedCell(row, 'acquirer'),
      _actualExpectedCell(row, 'details'),
    ].map(_mdCell).join(' | ');
    buffer.writeln('| $cells |');
  }

  buffer.writeln();
  buffer.writeln('## Details');
  buffer.writeln();

  for (final row in rows) {
    final c = row.goldenCase;
    buffer.writeln('### ${c.id}');
    buffer.writeln();
    buffer
        .writeln('- Image: `${c.image}` ${row.imageExists ? '' : '(missing)'}');
    buffer.writeln('- Source app: `${c.sourceApp}`');

    final ocrText = _readOcrText(row.actualEnvelope);
    if (ocrText != null && ocrText.trim().isNotEmpty) {
      buffer.writeln('- OCR text: `${_truncate(ocrText, 140)}`');
    }

    final rule = _mapAt(row.actualEnvelope, 'rule');
    final ai = _mapAt(row.actualEnvelope, 'ai');
    final finalActual = row.finalActual;
    if (rule != null) {
      buffer.writeln('- Rule: `${_compactJson(rule)}`');
    }
    if (ai != null) {
      buffer.writeln('- AI: `${_compactJson(ai)}`');
    }
    final actualPrompt = row.actualEnvelope?['prompt']?.toString();
    if (actualPrompt != null && actualPrompt.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<details>');
      buffer.writeln('<summary>Actual prompt</summary>');
      buffer.writeln();
      buffer.writeln('```text');
      buffer.writeln(actualPrompt);
      buffer.writeln('```');
      buffer.writeln();
      buffer.writeln('</details>');
    }
    if (finalActual != null) {
      buffer.writeln('- Final: `${_compactJson(finalActual)}`');
    } else {
      buffer.writeln('- Final: actual result not provided');
      buffer.writeln('- Expected: `${_compactJson(row.goldenCase.expected)}`');
    }

    final failures = row.checks.where((check) => check.isFailure).toList();
    if (failures.isNotEmpty) {
      buffer.writeln('- Failures:');
      for (final failure in failures) {
        buffer.writeln(
          '  - `${failure.field}` expected `${failure.displayExpected}`, '
          'actual `${failure.actual}`',
        );
      }
    }

    if (c.evidence.isNotEmpty) {
      buffer.writeln('- Evidence: ${c.evidence.map((e) => '`$e`').join(', ')}');
    }

    buffer.writeln();
  }

  return buffer.toString();
}

String _renderJsonReport(List<ImageBillingEvalRow> rows) {
  final data = {
    'cases': rows
        .map(
          (row) => {
            'id': row.goldenCase.id,
            'image': row.goldenCase.image,
            'image_exists': row.imageExists,
            'has_actual': row.finalActual != null,
            'status': row.finalActual == null
                ? 'pending'
                : (row.hasFailure ? 'fail' : 'pass'),
            'passed': row.finalActual == null ? null : !row.hasFailure,
            'checks': row.checks
                .map(
                  (check) => {
                    'field': check.field,
                    'expected': check.expected,
                    'expected_any': check.allowedValues,
                    'actual': check.actual,
                    'status': check.status.name,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

String? _readOcrText(Map<String, dynamic>? envelope) {
  final value =
      envelope?['ocrText'] ?? envelope?['ocr_text'] ?? envelope?['rawText'];
  return value?.toString();
}

Map<String, dynamic>? _mapAt(Map<String, dynamic>? source, String key) {
  final value = source?[key];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

String _compactJson(Map<String, dynamic> value) {
  return jsonEncode(value);
}

String _cell(ImageBillingFieldCheck? check) {
  if (check == null) return '-';
  return switch (check.status) {
    ImageBillingCheckStatus.pass => 'ok',
    ImageBillingCheckStatus.warn => 'warn',
    ImageBillingCheckStatus.fail => 'fail',
  };
}

String _actualExpectedCell(ImageBillingEvalRow row, String field) {
  final actual = _valueText(row.finalActual?[field]);
  final expected = _expectedText(row.goldenCase, field);
  return '$actual || $expected';
}

String _expectedText(ImageBillingGoldenCase goldenCase, String field) {
  final expected = goldenCase.expected[field];
  final alternatives = goldenCase.expectedAny[field] ?? const [];
  final values = [expected, ...alternatives].map(_valueText).toList();
  return values.join(' / ');
}

String _valueText(dynamic value) {
  if (value == null) return '-';
  if (value is Map || value is List) return jsonEncode(value);
  final text = value.toString().trim();
  return text.isEmpty ? '-' : text;
}

String _mdCell(String value) {
  return value.replaceAll('|', r'\|');
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

String _truncate(String value, int maxLength) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxLength) return text;
  return '${text.substring(0, max(0, maxLength - 3))}...';
}

void _printHelp() {
  stdout.writeln('''
Evaluate image billing extraction results against golden samples.

Patrol is the primary entry point for Android OCR + AI evaluation. This tool is
only a thin local report wrapper for already-exported actual JSON.

Usage:
  dart run tool/image_billing_eval.dart [options]

Options:
  --golden <path>       Golden file. Default: $_defaultGoldenPath
  --actual <path>       Actual result JSON file.
  --actual-dir <path>   Directory containing one JSON file per case id or image basename.
  --report <path>       Write report to file. Default: stdout
  --format <markdown|json>
  --strict              Exit with code 1 when any provided actual result mismatches.
  --help

Actual JSON can be either:
  {"cases":[{"id":"wechat_pinduoduo_single","ocrText":"...","rule":{},"ai":{},"final":{}}]}

or a map keyed by case id:
  {"wechat_pinduoduo_single":{"ocrText":"...","final":{"amount":-19.5}}}

If no actual result is provided, the tool validates sample image paths and prints the golden checklist.
''');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}

class _Options {
  final String goldenPath;
  final String? actualPath;
  final String? actualDir;
  final String? reportPath;
  final _ReportFormat format;
  final bool strict;
  final bool help;

  const _Options({
    required this.goldenPath,
    required this.actualPath,
    required this.actualDir,
    required this.reportPath,
    required this.format,
    required this.strict,
    required this.help,
  });

  factory _Options.parse(List<String> args) {
    var goldenPath = _defaultGoldenPath;
    String? actualPath;
    String? actualDir;
    String? reportPath;
    var format = _ReportFormat.markdown;
    var strict = false;
    var help = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--golden':
          goldenPath = _readOptionValue(args, ++i, arg);
        case '--actual':
          actualPath = _readOptionValue(args, ++i, arg);
        case '--actual-dir':
          actualDir = _readOptionValue(args, ++i, arg);
        case '--report':
          reportPath = _readOptionValue(args, ++i, arg);
        case '--format':
          final value = _readOptionValue(args, ++i, arg);
          format =
              value == 'json' ? _ReportFormat.json : _ReportFormat.markdown;
        case '--strict':
          strict = true;
        case '--help':
        case '-h':
          help = true;
        default:
          _fail('Unknown option: $arg');
      }
    }

    return _Options(
      goldenPath: goldenPath,
      actualPath: actualPath,
      actualDir: actualDir,
      reportPath: reportPath,
      format: format,
      strict: strict,
      help: help,
    );
  }

  static String _readOptionValue(List<String> args, int index, String option) {
    if (index >= args.length) {
      _fail('Missing value for $option');
    }
    return args[index];
  }
}

enum _ReportFormat { markdown, json }
