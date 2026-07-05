import 'dart:io';

import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_parsers.dart';
import 'package:beecount/services/billing/rules/billing_rule_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingRuleEngineImpl', () {
    test(
        'matches templates by source package and keywords with stable priority',
        () async {
      final engine = BillingRuleEngineImpl();
      final traces = <BillingRuleTrace>[];
      final ruleSet = BillingRuleSet(
        schemaVersion: 1,
        rulesVersion: '2026.07.01.1',
        paymentChannels: const [],
        templates: [
          _template(
            id: 'wechat_payment_detail_v2',
            priority: 100,
            match: const BillingRuleTemplateMatch(
              sourcePackages: ['com.tencent.mm'],
              keywordsAll: ['当前状态', '支付时间'],
            ),
            extractors: const [
              BillingFieldExtractorRule(
                field: 'paymentChannel',
                type: BillingRuleExtractorTypes.constant,
                value: '微信支付',
                confidence: 0.95,
              ),
            ],
          ),
          _template(
            id: 'wechat_payment_detail_v1',
            priority: 10,
            match: const BillingRuleTemplateMatch(
              keywordsAny: ['支付时间'],
            ),
            extractors: const [
              BillingFieldExtractorRule(
                field: 'paymentChannel',
                type: BillingRuleExtractorTypes.constant,
                value: 'fallback',
              ),
            ],
          ),
        ],
      );

      final result = await engine.evaluate(
        ruleSet: ruleSet,
        sourcePackage: 'com.tencent.mm',
        ocrText: '当前状态\n支付成功\n支付时间\n2026年06月30日 12:51:18',
        traceSink: traces.add,
      );

      expect(result.matchedTemplateId, 'wechat_payment_detail_v2');
      expect(result.paymentChannel, '微信支付');
      expect(result.fields['paymentChannel']?.confidence, 0.95);
      expect(traces.single.rulesVersion, '2026.07.01.1');
      expect(traces.single.matchedRuleIds, [
        'wechat_payment_detail_v2',
        'wechat_payment_detail_v1',
      ]);
    });

    test('matches image-only share rules by extracted source app name',
        () async {
      const cases = [
        _ImageShareRuleCase(
          imagePath: 'image/单条/支付宝-单条.jpg',
          sourceAppName: '支付宝',
          templateId: 'alipay_image_share_v1',
          paymentChannel: '支付宝',
        ),
        _ImageShareRuleCase(
          imagePath: 'image/单条/微信-单条.jpg',
          sourceAppName: '微信',
          templateId: 'wechat_image_share_v1',
          paymentChannel: '微信支付',
        ),
        _ImageShareRuleCase(
          imagePath: 'image/单条/美团-单条.jpg',
          sourceAppName: '美团',
          templateId: 'meituan_image_share_v1',
          paymentChannel: '美团',
        ),
        _ImageShareRuleCase(
          imagePath: 'image/单条/京东-单条.jpg',
          sourceAppName: '京东',
          templateId: 'jd_image_share_v1',
          paymentChannel: '京东',
        ),
        _ImageShareRuleCase(
          imagePath: 'image/单条/拼多多-单条.jpg',
          sourceAppName: '拼多多',
          templateId: 'pinduoduo_image_share_v1',
          paymentChannel: '拼多多',
        ),
        _ImageShareRuleCase(
          imagePath: 'image/单条/云闪付-单条.jpg',
          sourceAppName: '云闪付',
          templateId: 'unionpay_image_share_v1',
          paymentChannel: '云闪付',
        ),
      ];

      final ruleSet = BillingRuleSet(
        schemaVersion: 1,
        rulesVersion: '2026.07.05.image-share',
        paymentChannels: const [],
        templates: [
          for (final c in cases)
            _template(
              id: c.templateId,
              match: BillingRuleTemplateMatch(
                appNameKeywords: [c.sourceAppName],
              ),
              extractors: [
                BillingFieldExtractorRule(
                  field: 'paymentChannel',
                  type: BillingRuleExtractorTypes.constant,
                  value: c.paymentChannel,
                  confidence: 0.95,
                ),
              ],
            ),
        ],
      );

      for (final c in cases) {
        final sharedImage = File(c.imagePath);
        expect(await sharedImage.exists(), isTrue, reason: c.imagePath);

        final result = await BillingRuleEngineImpl().evaluate(
          ruleSet: ruleSet,
          sourceAppName: c.sourceAppName,
          ocrText: '',
        );

        expect(result.matchedTemplateId, c.templateId, reason: c.sourceAppName);
        expect(result.paymentChannel, c.paymentChannel,
            reason: c.sourceAppName);
      }
    });

    test('returns an empty traceable result when no template matches',
        () async {
      final traces = <BillingRuleTrace>[];

      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: '2026.07.01.1',
          paymentChannels: const [],
          templates: [
            _template(
              id: 'alipay_detail',
              match: const BillingRuleTemplateMatch(
                sourcePackages: ['com.eg.android.AlipayGphone'],
                keywordsAll: ['交易成功'],
              ),
            ),
          ],
        ),
        sourcePackage: 'com.tencent.mm',
        ocrText: '当前状态\n支付成功',
        traceSink: traces.add,
      );

      expect(result.matchedTemplateId, isNull);
      expect(result.confidence, 0);
      expect(result.fields, isEmpty);
      expect(traces.single.matchedRuleIds, isEmpty);
      expect(traces.single.result, same(result));
    });

    test('extracts all supported field extractor types and nested details',
        () async {
      final traces = <BillingRuleTrace>[];
      final ocrText = [
        '当前状态',
        '支付成功',
        '商户名称：天津海河测试餐厅甲',
        '合计：¥5.07',
        '支付时间',
        '2026年06月30日 12:51:18',
        '张三',
        '收款方',
        '备注',
        '午餐套餐',
        '支付方式',
        '平安银行信用卡(2299)',
        '交易单号',
        '9422548327273593242578194027',
      ].join('\n');

      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: '2026.07.01.1',
          paymentChannels: const [],
          templates: [
            _template(
              id: 'wechat_payment_detail',
              match: const BillingRuleTemplateMatch(
                sourcePackages: ['com.tencent.mm'],
                keywordsAll: ['当前状态', '交易单号'],
              ),
              extractors: const [
                BillingFieldExtractorRule(
                  field: 'paymentChannel',
                  type: BillingRuleExtractorTypes.constant,
                  value: '微信支付',
                  confidence: 0.96,
                ),
                BillingFieldExtractorRule(
                  field: 'amount',
                  type: BillingRuleExtractorTypes.regex,
                  pattern: r'合计[:：]\s*([¥￥]?\s*\d+(?:\.\d+)?)',
                  parser: BillingRuleParserTypes.amount,
                  confidence: 0.94,
                ),
                BillingFieldExtractorRule(
                  field: 'time',
                  type: BillingRuleExtractorTypes.labelNextLine,
                  label: '支付时间',
                  parser: BillingRuleParserTypes.zhDatetime,
                  confidence: 0.93,
                ),
                BillingFieldExtractorRule(
                  field: 'counterparty',
                  type: BillingRuleExtractorTypes.labelPreviousLine,
                  label: '收款方',
                  confidence: 0.82,
                ),
                BillingFieldExtractorRule(
                  field: 'note',
                  type: BillingRuleExtractorTypes.betweenLabels,
                  label: '备注',
                  confidence: 0.8,
                  options: {'endLabel': '支付方式'},
                ),
                BillingFieldExtractorRule(
                  field: 'merchantFullName',
                  type: BillingRuleExtractorTypes.nearKeyword,
                  label: '商户名称',
                  pattern: r'商户名称[:：]\s*(.+)',
                  confidence: 0.85,
                ),
                BillingFieldExtractorRule(
                  field: 'paymentMethod',
                  type: BillingRuleExtractorTypes.labelNextLine,
                  label: '支付方式',
                  confidence: 0.81,
                ),
                BillingFieldExtractorRule(
                  field: 'details.transaction_no',
                  type: BillingRuleExtractorTypes.labelNextLine,
                  label: '交易单号',
                  pattern: r'\d{20,}',
                  confidence: 0.9,
                ),
              ],
            ),
          ],
        ),
        sourcePackage: 'com.tencent.mm',
        ocrText: ocrText,
        traceSink: traces.add,
      );

      expect(result.paymentChannel, '微信支付');
      expect(result.amount, 5.07);
      expect(result.time, DateTime(2026, 6, 30, 12, 51, 18));
      expect(result.counterparty, '张三');
      expect(result.note, '午餐套餐');
      expect(result.merchantFullName, '天津海河测试餐厅甲');
      expect(result.paymentMethod, '平安银行信用卡(2299)');
      expect(result.details, {
        'transaction_no': '9422548327273593242578194027',
      });
      expect(
          result.fields.keys,
          containsAll([
            'paymentChannel',
            'amount',
            'time',
            'counterparty',
            'note',
            'merchantFullName',
            'paymentMethod',
            'details.transaction_no',
          ]));
      for (final fieldResult in result.fields.values) {
        expect(fieldResult.evidence, isNotEmpty, reason: fieldResult.field);
        expect(fieldResult.confidence, greaterThan(0),
            reason: fieldResult.field);
        expect(fieldResult.extractorType, isNotEmpty,
            reason: fieldResult.field);
      }
      expect(traces.single.fieldEvidence['details.transaction_no'], isNotEmpty);
      expect(traces.single.result?.toJson()['details'], {
        'transaction_no': '9422548327273593242578194027',
      });
      expect(result.confidence, greaterThan(0.8));
    });
  });

  group('BillingRuleParsers', () {
    test('parses amount values with currency marks and separators', () {
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.amount,
          '¥-1,234.50',
        ).value,
        -1234.5,
      );
      expect(
        BillingRuleParsers.parse(BillingRuleParserTypes.amount, '￥5.07').value,
        5.07,
      );
    });

    test('parses Chinese and ISO date time values', () {
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.zhDatetime,
          '2026年06月30日 12:51:18',
        ).value,
        DateTime(2026, 6, 30, 12, 51, 18),
      );
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.isoDatetime,
          '2026-06-30T12:51:18',
        ).value,
        DateTime(2026, 6, 30, 12, 51, 18),
      );
    });

    test('parses regex groups and raw strings', () {
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.regexGroup,
          '订单号：abc-123',
          pattern: r'订单号[:：]\s*([a-z]+-\d+)',
        ).value,
        'abc-123',
      );
      expect(
        BillingRuleParsers.parse(BillingRuleParserTypes.raw, '  原始 文本  ').value,
        '原始 文本',
      );
    });
  });
}

class _ImageShareRuleCase {
  final String imagePath;
  final String sourceAppName;
  final String templateId;
  final String paymentChannel;

  const _ImageShareRuleCase({
    required this.imagePath,
    required this.sourceAppName,
    required this.templateId,
    required this.paymentChannel,
  });
}

BillingRuleTemplate _template({
  required String id,
  BillingRuleTemplateMatch match = const BillingRuleTemplateMatch(),
  List<BillingFieldExtractorRule> extractors = const [],
  int priority = 0,
}) {
  return BillingRuleTemplate(
    id: id,
    priority: priority,
    baseConfidence: 0.88,
    match: match,
    extractors: extractors,
  );
}
