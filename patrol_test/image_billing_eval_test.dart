import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

import 'package:beecount/services/dev/image_billing_eval_assertions.dart'
    as eval;
import 'package:beecount/services/dev/image_billing_eval_runner.dart';
import 'package:beecount/services/ai/ai_provider_config.dart';
import 'package:beecount/services/ai/ai_provider_manager.dart';

const _goldenAssetPath = 'tool/image_billing_golden.json';
const _strictGolden =
    bool.fromEnvironment('IMAGE_BILLING_EVAL_STRICT', defaultValue: false);

void main() {
  patrolTest('image billing golden samples run on Android', ($) async {
    await $.pumpWidget(const SizedBox.shrink());
    await _expectVisionProviderConfigured();

    final goldenText = await rootBundle.loadString(_goldenAssetPath);
    final goldenJson = jsonDecode(goldenText) as Map<String, dynamic>;
    final cases = ((goldenJson['cases'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final tempRoot = await getTemporaryDirectory();
    final runRoot = Directory(
      p.join(tempRoot.path, 'image_billing_eval_patrol_$stamp'),
    );
    final inputDir = Directory(p.join(runRoot.path, 'input'));
    final outputDir = Directory(p.join(runRoot.path, 'output'));
    await inputDir.create(recursive: true);
    await outputDir.create(recursive: true);

    for (final c in cases) {
      final imageAssetPath = c['image'] as String;
      final bytes = await rootBundle.load(imageAssetPath);
      final target = File(p.join(inputDir.path, p.basename(imageAssetPath)));
      await target.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    final result = await ImageBillingEvalRunner.run(
      inputDirPath: inputDir.path,
      outputDirPath: outputDir.path,
    );

    expect(result.total, cases.length);
    expect(result.failed, 0, reason: 'Runner output: ${result.outputPath}');

    final actualFile = File(p.join(outputDir.path, 'latest_actual.json'));
    expect(await actualFile.exists(), isTrue);

    final actualText = await actualFile.readAsString();
    final summary = eval.evaluateImageBillingPayload(
      goldenJsonText: goldenText,
      actualJsonText: actualText,
    );

    final diagnostic = [
      'Image billing eval output: ${result.outputPath}',
      'Cases: ${summary.total}',
      'With actual: ${summary.withActual}',
      'Golden failures: ${summary.failed}',
      if (summary.failureDescriptions.isNotEmpty)
        ...summary.failureDescriptions.map((item) => '- $item'),
    ].join('\n');
    // ignore: avoid_print
    print(diagnostic);

    expect(summary.withActual, summary.total, reason: diagnostic);
    if (_strictGolden) {
      expect(summary.failureDescriptions, isEmpty, reason: diagnostic);
    }
  });
}

Future<void> _expectVisionProviderConfigured() async {
  final provider = await AIProviderManager.getProviderForCapability(
    AICapabilityType.vision,
  );

  expect(
    provider,
    isNotNull,
    reason: '图片记账评测需要先在 App 中配置图片理解服务商。',
  );
  expect(
    provider!.isValid,
    isTrue,
    reason: '图片记账评测需要先在 App 中配置图片理解服务商 API Key。',
  );
  expect(
    provider.supportsVision,
    isTrue,
    reason: '图片记账评测需要先在 App 中配置图片理解模型。',
  );
}
