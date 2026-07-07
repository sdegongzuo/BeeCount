import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/dev/rule_upgrade/rule_upgrade.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleUpgradeExpectedPreparer', () {
    test('builds a review case from golden expectations and actual output', () {
      const goldenJson = '''
{
  "version": 1,
  "cases": [
    {
      "id": "wechat_sample",
      "image": "image/单条/微信-单条.jpg",
      "source_app": "微信",
      "expected": {
        "amount": -19.5,
        "time": "2026-05-31T14:27:40",
        "payment_channel": "微信支付",
        "payment_method": "平安银行信用卡(2299)",
        "counterparty": "拼多多"
      }
    }
  ]
}
''';
      const actualJson = '''
{
  "cases": [
    {
      "id": "wechat_sample",
      "image": "image/单条/微信-单条.jpg",
      "ocrText": "拼多多\\n¥-19.50\\n支付时间\\n2026年05月31日 14:27:40\\n支付方式\\n平安银行信用卡(2299)",
      "traces": [
        {
          "stage": "ocr",
          "data": {
            "engine": "rapidocr",
            "rawText": "拼多多\\n¥-19.50\\n支付时间\\n2026年05月31日 14:27:40\\n支付方式\\n平安银行信用卡(2299)"
          }
        }
      ],
      "rule": {"amount": -19.5},
      "ai": {"note": "拼多多"},
      "final": {"amount": -19.5, "payment_channel": "微信支付"}
    }
  ]
}
''';

      final result = RuleUpgradeExpectedPreparer.prepare(
        caseId: 'wechat_sample',
        imagePath: 'image/单条/微信-单条.jpg',
        sourceApp: '微信',
        goldenJsonText: goldenJson,
        actualJsonText: actualJson,
      );

      expect(result.status, 'needs_review');
      expect(result.expected.keys, [
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
      ]);
      expect(result.expected['payment_channel'], '微信支付');
      expect(result.expected['counterparty'], '拼多多');
      expect(result.expected['account'], isNull);
      expect(result.ocrEngine, 'rapidocr');
      expect(result.toJson()['ocr_engine'], 'rapidocr');
      expect(result.ocrText, contains('支付时间'));
      expect(result.currentRuleResult?['amount'], -19.5);
      expect(result.aiSuggestion?['note'], '拼多多');
    });

    test('uses top-level OCR engine when trace engine is unavailable', () {
      const actualJson = '''
{
  "cases": [
    {
      "id": "wechat_sample",
      "image": "image/单条/微信-单条.jpg",
      "ocrText": "拼多多\\n-19.50",
      "ocrEngine": "rapidocr",
      "final": {"amount": -19.5}
    }
  ]
}
''';

      final result = RuleUpgradeExpectedPreparer.prepare(
        caseId: 'wechat_sample',
        imagePath: 'image/单条/微信-单条.jpg',
        sourceApp: '微信',
        actualJsonText: actualJson,
      );

      expect(result.ocrEngine, 'rapidocr');
    });
  });

  group('RuleUpgradeCandidateGenerator', () {
    test('generates a valid candidate TOML matched by source app name',
        () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '支付方式',
          '平安银行信用卡(2299)',
          '交易单号',
          '9223292424251435949411772872',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
          'counterparty': '拼多多',
        },
      });

      final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
      final repository = TomlBillingRuleRepository(
        assetBundle: _StringAssetBundle({
          TomlBillingRuleRepository.defaultBuiltInAssetPath: toml,
        }),
      );
      final ruleSet = await repository.loadBuiltInRuleSet();
      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: ruleSet,
        sourceAppName: '微信',
        ocrText: upgradeCase.ocrText!,
      );

      expect(ruleSet.templates.single.id, 'wechat_sample_candidate_v1');
      expect(result.matchedTemplateId, 'wechat_sample_candidate_v1');
      expect(result.paymentChannel, '微信支付');
      expect(result.amount, -19.5);
      expect(result.time, DateTime(2026, 5, 31, 14, 27, 40));
      expect(result.paymentMethod, '平安银行信用卡(2299)');
    });

    test('does not hardcode sample-specific expected values', () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '收单机构',
          '财付通支付科技有限公司',
          '支付方式',
          '平安银行信用卡(2299)',
          '交易单号',
          '9223292424251435949411772872',
          '商户单号',
          'XP9250027811994856890233755142',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
          'counterparty': '拼多多',
          'note': '拼多多',
          'acquirer': '财付通支付科技有限公司',
          'details': [
            '9223292424251435949411772872',
            'XP9250027811994856890233755142',
          ],
        },
      });

      final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: toml,
      );

      expect(toml, isNot(contains('平安银行信用卡(2299)')));
      expect(toml, isNot(contains('9223292424251435949411772872')));
      expect(toml, isNot(contains('XP9250027811994856890233755142')));
      expect(toml, isNot(contains('field = "counterparty"')));
      expect(toml, isNot(contains('field = "note"')));
      expect(toml, contains('field = "details.remaining_text"'));
      expect(toml, isNot(contains('details.value_')));
      expect(verification.failures, isEmpty);
    });

    test('verifies a candidate TOML against reviewed expected data', () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '支付方式',
          '平安银行信用卡(2299)',
          '交易单号',
          '9223292424251435949411772872',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
          'counterparty': '拼多多',
        },
      });
      final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);

      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: toml,
      );

      expect(verification.passed, isTrue);
      expect(verification.failures, isEmpty);
      expect(verification.actual['matched_template_id'],
          'wechat_sample_candidate_v1');
      expect(verification.actual['payment_channel'], '微信支付');
    });

    test('detects when an existing template wins over the candidate', () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '支付方式',
          '平安银行信用卡(2299)',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
        },
      });
      final candidateToml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
      const baseToml = '''
schemaVersion = 1
rulesVersion = "base"

[[templates]]
id = "existing_wechat_template"
enabled = true
priority = 200
baseConfidence = 0.88

[templates.match]
appNameKeywords = ["微信"]
keywordsAll = ["支付时间", "支付方式"]

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"
confidence = 0.95

[[templates.extract]]
field = "amount"
type = "regex"
pattern = "^\\\\s*([¥￥]?\\\\s*[-−+]?\\\\d{1,6}\\\\.\\\\d{1,2})\\\\s*(?:元)?\\\\s*\$"
parser = "signedAmount"
confidence = 0.9
''';

      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: candidateToml,
        baseToml: baseToml,
      );

      expect(verification.passed, isFalse);
      expect(verification.actual['matched_template_id'],
          'existing_wechat_template');
      expect(verification.failures, contains(contains('candidate_template')));
    });

    test('candidate wins over same-family base templates by priority',
        () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '支付方式',
          '平安银行信用卡(2299)',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
        },
      });
      final candidateToml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
      const baseToml = '''
schemaVersion = 1
rulesVersion = "base"

[[templates]]
id = "wechat_payment_detail_v1"
enabled = true
priority = 100
baseConfidence = 0.88

[templates.match]
appNameKeywords = ["微信"]
keywordsAll = ["支付时间", "支付方式"]

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"
confidence = 0.95
''';

      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: candidateToml,
        baseToml: baseToml,
      );

      expect(verification.passed, isTrue);
      expect(verification.actual['matched_template_id'],
          'wechat_sample_candidate_v1');
    });

    test('reports regression when merged candidate changes existing samples',
        () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '拼多多',
          '¥-19.50',
          '支付时间',
          '2026年05月31日 14:27:40',
          '支付方式',
          '平安银行信用卡(2299)',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
        },
      });
      final candidateToml = RuleUpgradeCandidateGenerator.generate(upgradeCase);
      const baseToml = '''
schemaVersion = 1
rulesVersion = "base"

[[templates]]
id = "old_wechat_template"
enabled = true
priority = 100
baseConfidence = 0.88

[templates.match]
appNameKeywords = ["微信"]
keywordsAll = ["旧规则关键字"]

[[templates.extract]]
field = "paymentChannel"
type = "constant"
value = "微信支付"
confidence = 0.95
''';

      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: candidateToml,
        baseToml: baseToml,
        regressionSamples: const [
          RuleUpgradeRegressionSample(
            id: 'existing_wechat',
            sourceAppName: '微信',
            ocrText: '旧规则关键字\n支付时间\n支付方式',
            expected: {
              'matchedTemplateId': 'old_wechat_template',
              'paymentChannel': '微信支付',
            },
          ),
        ],
      );

      expect(verification.passed, isFalse);
      expect(verification.regression?.passed, isFalse);
      expect(
        verification.failures,
        contains(contains('regression: 1 existing sample(s) failed')),
      );
    });

    test('uses confirmed values when labels and values are split in OCR',
        () async {
      final upgradeCase = RuleUpgradeCase.fromJson({
        'schema': RuleUpgradeCase.schema,
        'status': 'reviewed',
        'case_id': 'wechat_split_label_sample',
        'image': 'image/单条/微信-单条.jpg',
        'source_app': '微信',
        'ocr_text': [
          '当前状态',
          '支付时间',
          '收单机构',
          '支付方式',
          '交易单号',
          '商户单号',
          '拼多多',
          '-19.50',
          '19.80',
          '支付成功',
          '0.301',
          '2026年05月31日 14:27:40',
          '财付通支付科技有限公司',
          '平安银行信用卡(2299)',
          '9223292424251435949411772872',
          'XP9250027811994856890233755142',
        ].join('\n'),
        'expected': {
          'amount': -19.5,
          'time': '2026-05-31T14:27:40',
          'payment_channel': '微信支付',
          'payment_method': '平安银行信用卡(2299)',
          'counterparty': '拼多多',
          'acquirer': '财付通支付科技有限公司',
          'details': [
            '19.8',
            '0.3',
            '9223292424251435949411772872',
            'XP9250027811994856890233755142',
          ],
        },
      });
      final toml = RuleUpgradeCandidateGenerator.generate(upgradeCase);

      final verification = await RuleUpgradeCandidateVerifier.verify(
        upgradeCase: upgradeCase,
        candidateToml: toml,
      );

      expect(toml, contains('field = "details.remaining_text"'));
      expect(verification.failures, isEmpty);
    });
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _StringAssetBundle(this.assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Missing test asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }
}
