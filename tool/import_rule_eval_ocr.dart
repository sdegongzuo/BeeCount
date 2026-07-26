import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_rule_eval_ocr.dart <actual.json> [...]',
    );
    exitCode = 64;
    return;
  }

  final imported = <String>{};
  for (final actualPath in args) {
    final actualFile = File(actualPath);
    if (!actualFile.existsSync()) {
      throw StateError('Actual file not found: $actualPath');
    }
    final payload =
        jsonDecode(await actualFile.readAsString()) as Map<String, dynamic>;
    final generatedAt = payload['generatedAt']?.toString();
    for (final item in (payload['cases'] as List<dynamic>? ?? const [])) {
      final actualCase = item as Map<String, dynamic>;
      final id = actualCase['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('Actual case is missing id');
      }
      if (!imported.add(id)) {
        throw StateError('Duplicate actual case id: $id');
      }
      final finalResult =
          actualCase['final'] as Map<String, dynamic>? ?? const {};
      final ocrText =
          actualCase['ocrText']?.toString() ?? finalResult['rawText']?.toString();
      if (ocrText == null || ocrText.trim().isEmpty) {
        throw StateError('Actual case has no OCR text: $id');
      }

      final sampleFile = File('tool/rule_eval/samples/$id.json');
      if (!sampleFile.existsSync()) {
        throw StateError('Rule evaluation sample not found: ${sampleFile.path}');
      }
      final sample =
          jsonDecode(await sampleFile.readAsString()) as Map<String, dynamic>;
      sample['ocrText'] = ocrText;
      sample['ocrEngine'] = actualCase['ocrEngine']?.toString();
      sample['ocrCapturedAt'] = generatedAt;
      await sampleFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(sample)}\n',
      );
      stdout.writeln('Imported real OCR: $id');
    }
  }
}
