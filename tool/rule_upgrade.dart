import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/dev/rule_upgrade/rule_upgrade.dart';
import 'package:path/path.dart' as p;

const _defaultGoldenPath = 'tool/image_billing_golden.json';
const _defaultActualPath = 'build/image_billing_eval/latest_actual.json';
const _defaultCaseDir = 'tool/rule_eval/upgrade_cases';
const _defaultCandidateDir = 'tool/rule_eval/ai_suggestions';
const _defaultBaseRulePath = 'assets/rules/billing_rules.toml';
const _defaultRegressionSamplesDir = 'tool/rule_eval/samples';
const _defaultRegressionExpectedDir = 'tool/rule_eval/expected';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }

  final command = args.first;
  final options = _Options.parse(args.skip(1).toList());
  switch (command) {
    case 'prepare':
    case 'prepare-expected':
      _prepareExpected(options);
      break;
    case 'verify':
      await _verifyReviewedCase(options);
      break;
    case 'generate-candidate':
      _generateCandidate(options);
      break;
    case 'verify-candidate':
      await _verifyCandidate(options);
      break;
    default:
      _fail('Unknown command: $command');
  }
}

Future<void> _verifyReviewedCase(_Options options) async {
  final casePath = options.requiredValue('--case');
  final outputDir = options.value('--output-dir') ?? _defaultCandidateDir;
  final candidatePath = options.value('--candidate');
  final caseFile = File(casePath);
  if (!caseFile.existsSync()) {
    _fail('Case file not found: $casePath');
  }

  final upgradeCase = _readUpgradeCase(caseFile);
  final allowNeedsReview = options.flag('--allow-needs-review');
  if (upgradeCase.status == 'needs_review' && !allowNeedsReview) {
    _fail(
      'Case still needs review: set status to reviewed after confirming expected, '
      'or pass --allow-needs-review for a draft.',
    );
  }

  final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
  final candidateFile = File(
    candidatePath ?? p.join(outputDir, '${upgradeCase.caseId}.candidate.toml'),
  );
  candidateFile.parent.createSync(recursive: true);
  candidateFile.writeAsStringSync(toml);
  stdout.writeln('Candidate TOML written: ${candidateFile.path}');

  await _verifyCandidate(
    options.withDefaults({
      '--candidate': candidateFile.path,
      '--report': options.value('--report') ??
          p.join('build', 'rule_upgrade', '${upgradeCase.caseId}.verify.json'),
    }),
  );
}

Future<void> _verifyCandidate(_Options options) async {
  final casePath = options.requiredValue('--case');
  final candidatePath = options.requiredValue('--candidate');
  final basePath = options.value('--base') ?? _defaultBaseRulePath;
  final standalone = options.flag('--standalone');
  final regressionSamplesDir =
      options.value('--regression-samples') ?? _defaultRegressionSamplesDir;
  final regressionExpectedDir =
      options.value('--regression-expected') ?? _defaultRegressionExpectedDir;
  final skipRegression = options.flag('--skip-regression');
  final reportPath = options.value('--report');

  final caseFile = File(casePath);
  if (!caseFile.existsSync()) {
    _fail('Case file not found: $casePath');
  }
  final candidateFile = File(candidatePath);
  if (!candidateFile.existsSync()) {
    _fail('Candidate TOML not found: $candidatePath');
  }

  final upgradeCase = _readUpgradeCase(caseFile);
  final verification = await RuleUpgradeCandidateVerifier.verify(
    upgradeCase: upgradeCase,
    candidateToml: candidateFile.readAsStringSync(),
    baseToml: standalone ? null : _readRequired(basePath, 'Base TOML'),
    regressionSamples: standalone || skipRegression
        ? const []
        : _loadRegressionSamples(
            sampleDirPath: regressionSamplesDir,
            expectedDirPath: regressionExpectedDir,
          ),
  );
  final report = const JsonEncoder.withIndent('  ').convert({
    'case': casePath,
    'candidate': candidatePath,
    if (!standalone) 'base': basePath,
    if (!standalone && !skipRegression)
      'regression_samples': regressionSamplesDir,
    if (!standalone && !skipRegression)
      'regression_expected': regressionExpectedDir,
    ...verification.toJson(),
  });

  if (reportPath != null) {
    final reportFile = File(reportPath);
    reportFile.parent.createSync(recursive: true);
    reportFile.writeAsStringSync(report);
    stdout.writeln('Verification report written: ${reportFile.path}');
  } else {
    stdout.writeln(report);
  }

  if (!verification.passed) {
    exitCode = 1;
  }
}

void _prepareExpected(_Options options) {
  final imagePath = options.requiredValue('--image');
  final sourceApp = options.requiredValue('--source-app');
  final caseId = options.value('--case-id') ?? _caseIdFromImage(imagePath);
  final goldenPath = options.value('--golden') ?? _defaultGoldenPath;
  final actualPath = options.value('--actual') ?? _defaultActualPath;
  final outputDir = options.value('--output-dir') ?? _defaultCaseDir;

  final upgradeCase = RuleUpgradeExpectedPreparer.prepare(
    caseId: caseId,
    imagePath: imagePath,
    sourceApp: sourceApp,
    goldenJsonText: _readOptional(goldenPath),
    actualJsonText: _readOptional(actualPath),
  );
  final outputFile = File(p.join(outputDir, '$caseId.expected.json'));
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(upgradeCase.toJson()),
  );

  stdout.writeln('Expected review case written: ${outputFile.path}');
  if (upgradeCase.ocrEngine == null) {
    stdout.writeln(
      'Warning: OCR engine is missing in actual JSON. Re-run image billing '
      'eval export with the latest Android build before judging RapidOCR/ML Kit.',
    );
  }
  stdout.writeln('Review `expected`, then change `status` from needs_review.');
}

void _generateCandidate(_Options options) {
  final casePath = options.requiredValue('--case');
  final outputDir = options.value('--output-dir') ?? _defaultCandidateDir;
  final allowNeedsReview = options.flag('--allow-needs-review');
  final caseFile = File(casePath);
  if (!caseFile.existsSync()) {
    _fail('Case file not found: $casePath');
  }

  final upgradeCase = _readUpgradeCase(caseFile);
  if (upgradeCase.status == 'needs_review' && !allowNeedsReview) {
    _fail(
      'Case still needs review: set status to reviewed after confirming expected, '
      'or pass --allow-needs-review for a draft.',
    );
  }

  final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
  final outputFile = File(
    p.join(outputDir, '${upgradeCase.caseId}.candidate.toml'),
  );
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(toml);
  stdout.writeln('Candidate TOML written: ${outputFile.path}');
}

RuleUpgradeCase _readUpgradeCase(File caseFile) {
  return RuleUpgradeCase.fromJson(
    Map<String, dynamic>.from(jsonDecode(caseFile.readAsStringSync()) as Map),
  );
}

String? _readOptional(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

String _readRequired(String path, String label) {
  final file = File(path);
  if (!file.existsSync()) {
    _fail('$label not found: $path');
  }
  return file.readAsStringSync();
}

List<RuleUpgradeRegressionSample> _loadRegressionSamples({
  required String sampleDirPath,
  required String expectedDirPath,
}) {
  final sampleDir = Directory(sampleDirPath);
  if (!sampleDir.existsSync()) {
    _fail('Regression sample directory not found: $sampleDirPath');
  }
  final files = sampleDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map((file) {
    final sample = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = _requiredJsonString(sample, 'id');
    final expected = <String, Object?>{
      ..._jsonObjectMap(sample['expected']),
      ..._readRegressionExpected(expectedDirPath, id),
    };
    return RuleUpgradeRegressionSample(
      id: id,
      sourcePackage: sample['sourcePackage']?.toString(),
      sourceAppName: sample['sourceAppName']?.toString(),
      ocrText: _requiredJsonString(sample, 'ocrText'),
      expected: expected,
    );
  }).toList(growable: false);
}

Map<String, Object?> _readRegressionExpected(
    String expectedDirPath, String id) {
  final file = File(p.join(expectedDirPath, '$id.expected.json'));
  if (!file.existsSync()) return const {};
  return _jsonObjectMap(jsonDecode(file.readAsStringSync()));
}

Map<String, Object?> _jsonObjectMap(Object? value) {
  if (value == null) return const {};
  if (value is! Map) _fail('Expected JSON object in regression data');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredJsonString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  _fail('Regression sample $key is required');
}

String _caseIdFromImage(String imagePath) {
  final name = p.basenameWithoutExtension(imagePath).trim();
  final ascii = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (ascii.isNotEmpty) return ascii;
  return 'rule_upgrade_${DateTime.now().millisecondsSinceEpoch}';
}

void _printHelp() {
  stdout.writeln('''
Prepare review data and candidate TOML for one-image billing rule upgrades.

Usage:
  dart run tool/rule_upgrade.dart prepare --image <path> --source-app <name> --case-id <id>
  dart run tool/rule_upgrade.dart verify --case <expected.json>
  dart run tool/rule_upgrade.dart prepare-expected --image <path> --source-app <name> --case-id <id>
  dart run tool/rule_upgrade.dart generate-candidate --case <expected.json>
  dart run tool/rule_upgrade.dart verify-candidate --case <expected.json> --candidate <candidate.toml>

prepare / prepare-expected options:
  --image <path>       Payment screenshot path.
  --source-app <name>  Simulated app name for rule matching.
  --case-id <id>       Stable case id. Defaults to image basename when possible.
  --golden <path>      Golden JSON. Default: $_defaultGoldenPath
  --actual <path>      Actual JSON. Default: $_defaultActualPath
  --output-dir <dir>   Output directory. Default: $_defaultCaseDir

generate-candidate options:
  --case <path>             Reviewed expected JSON.
  --output-dir <dir>        Output directory. Default: $_defaultCandidateDir
  --allow-needs-review      Allow draft candidate generation before review.

verify options:
  --case <path>             Reviewed expected JSON. Generates candidate and verifies it.
  --candidate <path>        Optional candidate TOML output path.
  --output-dir <dir>        Candidate output directory. Default: $_defaultCandidateDir
  --allow-needs-review      Allow draft candidate generation before review.
  --base <path>             Base TOML to merge with candidate. Default: $_defaultBaseRulePath
  --standalone              Verify candidate alone instead of merged with base rules.
  --regression-samples <dir> Existing sample JSON directory. Default: $_defaultRegressionSamplesDir
  --regression-expected <dir> Existing expected JSON directory. Default: $_defaultRegressionExpectedDir
  --skip-regression          Skip existing rule regression checks.
  --report <path>           Optional JSON report output path.

verify-candidate options:
  --case <path>             Reviewed expected JSON with ocr_text/source_app.
  --candidate <path>        Candidate TOML to evaluate.
  --base <path>             Base TOML to merge with candidate. Default: $_defaultBaseRulePath
  --standalone              Verify candidate alone instead of merged with base rules.
  --regression-samples <dir> Existing sample JSON directory. Default: $_defaultRegressionSamplesDir
  --regression-expected <dir> Existing expected JSON directory. Default: $_defaultRegressionExpectedDir
  --skip-regression          Skip existing rule regression checks.
  --report <path>           Optional JSON report output path.
''');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}

class _Options {
  final Map<String, String> _values;
  final Set<String> _flags;

  const _Options(this._values, this._flags);

  factory _Options.parse(List<String> args) {
    final values = <String, String>{};
    final flags = <String>{};
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (!arg.startsWith('--')) {
        _fail('Unexpected argument: $arg');
      }
      if (arg == '--allow-needs-review' ||
          arg == '--standalone' ||
          arg == '--skip-regression') {
        flags.add(arg);
        continue;
      }
      if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
        _fail('Missing value for $arg');
      }
      values[arg] = args[++i];
    }
    return _Options(values, flags);
  }

  String? value(String name) => _values[name];

  bool flag(String name) => _flags.contains(name);

  String requiredValue(String name) {
    final value = _values[name];
    if (value == null || value.trim().isEmpty) {
      _fail('Missing required option: $name');
    }
    return value;
  }

  _Options withDefaults(Map<String, String> defaults) {
    return _Options({
      ...defaults,
      ..._values,
    }, _flags);
  }
}
