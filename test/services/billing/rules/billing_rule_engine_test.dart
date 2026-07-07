import 'dart:io';

import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_extractors.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_parsers.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/billing/rules/billing_rule_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          imagePath: 'image/单条/云闪付-单条2.jpg',
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
      expect(
        result.details,
        containsPair('transaction_no', '9422548327273593242578194027'),
      );
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
      expect(
        traces.single.result?.toJson()['details'],
        containsPair('transaction_no', '9422548327273593242578194027'),
      );
      expect(result.confidence, greaterThan(0.8));
    });

    test('collects unmatched OCR lines into details', () async {
      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'candidate.test',
          paymentChannels: const [],
          templates: [
            _template(
              id: 'wechat_candidate',
              match: const BillingRuleTemplateMatch(
                appNameKeywords: ['微信'],
                keywordsAll: ['支付时间', '支付方式'],
              ),
              extractors: const [
                BillingFieldExtractorRule(
                  field: 'paymentChannel',
                  type: BillingRuleExtractorTypes.constant,
                  value: '微信支付',
                ),
                BillingFieldExtractorRule(
                  field: 'amount',
                  type: BillingRuleExtractorTypes.regex,
                  pattern: r'^\s*([¥￥]?\s*[-−+]?\d{1,6}\.\d{1,2})\s*(?:元)?\s*$',
                  parser: BillingRuleParserTypes.signedAmount,
                ),
                BillingFieldExtractorRule(
                  field: 'time',
                  type: BillingRuleExtractorTypes.regex,
                  pattern:
                      r'(\d{4}年\s*\d{1,2}\s*月\s*\d{1,2}\s*日\s+\d{1,2}:\d{2}:\d{2})',
                  parser: BillingRuleParserTypes.zhDatetime,
                ),
                BillingFieldExtractorRule(
                  field: 'paymentMethod',
                  type: BillingRuleExtractorTypes.regex,
                  pattern:
                      r'([^\n]{2,40}(?:银行|信用卡)[^\n]{0,30}(?:\(\d{3,6}\)|\[\d{3,6}\])?)',
                ),
                BillingFieldExtractorRule(
                  field: 'acquirer',
                  type: BillingRuleExtractorTypes.regex,
                  pattern: r'([^\n]{2,40}(?:支付[科料]技有限公司))',
                  parser: BillingRuleParserTypes.institutionName,
                ),
                BillingFieldExtractorRule(
                  field: 'details.remaining_text',
                  type: BillingRuleExtractorTypes.remainingLines,
                  options: {
                    'excludeLabels': [
                      '支付时间',
                      '支付方式',
                      '收单机构',
                      '交易单号',
                      '商户单号',
                      '当前状态',
                    ],
                  },
                ),
              ],
            ),
          ],
        ),
        sourceAppName: '微信',
        ocrText: [
          '拼多多',
          '-19.50',
          '原价',
          '￥19.80',
          '优惠',
          '银行卡多笔立减优惠0.30',
          '当前状态',
          '支付成功',
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
      );

      final remainingText = result.details?['remaining_text'] as String?;
      expect(remainingText, contains('原价'));
      expect(remainingText, contains('￥19.80'));
      expect(remainingText, contains('银行卡多笔立减优惠0.30'));
      expect(remainingText, contains('9223292424251435949411772872'));
      expect(remainingText, contains('XP9250027811994856890233755142'));
      expect(remainingText, isNot(contains('2026年05月31日 14:27:40')));
      expect(remainingText, isNot(contains('平安银行信用卡(2299)')));
      expect(remainingText, isNot(contains('财付通支付科技有限公司')));
    });

    test('adds remaining OCR lines while preserving structured details',
        () async {
      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: BillingRuleSet(
          schemaVersion: 1,
          rulesVersion: 'candidate.test',
          paymentChannels: const [],
          templates: [
            _template(
              id: 'unionpay_detail',
              match: const BillingRuleTemplateMatch(
                keywordsAll: ['银联交易详情', '交易时间', '参考号'],
              ),
              extractors: const [
                BillingFieldExtractorRule(
                  field: 'paymentChannel',
                  type: BillingRuleExtractorTypes.constant,
                  value: '云闪付',
                ),
                BillingFieldExtractorRule(
                  field: 'amount',
                  type: BillingRuleExtractorTypes.regex,
                  pattern: r'^\s*([-−]?[¥￥]\s*\d{1,6}\.\d{1,2})\s*$',
                  parser: BillingRuleParserTypes.signedAmount,
                ),
                BillingFieldExtractorRule(
                  field: 'time',
                  type: BillingRuleExtractorTypes.labelNextLine,
                  label: '交易时间',
                  parser: BillingRuleParserTypes.isoDatetime,
                ),
                BillingFieldExtractorRule(
                  field: 'details.reference_no',
                  type: BillingRuleExtractorTypes.labelNextLine,
                  label: '参考号',
                ),
              ],
            ),
          ],
        ),
        ocrText: [
          '银联交易详情',
          '淘宝平台商户',
          '-￥27.82',
          '优惠信息',
          '银联优惠-￥0.08',
          '交易时间',
          '2026-06-14 12:22:17',
          '商户编号',
          '972713631844736',
          '参考号',
          '957407753917',
        ].join('\n'),
      );

      expect(result.details?['reference_no'], '957407753917');
      final remainingText = result.details?['remaining_text'] as String?;
      expect(remainingText, contains('淘宝平台商户'));
      expect(remainingText, contains('优惠信息'));
      expect(remainingText, contains('银联优惠-￥0.08'));
      expect(remainingText, contains('商户编号'));
      expect(remainingText, contains('972713631844736'));
      expect(remainingText, isNot(contains('2026-06-14 12:22:17')));
      expect(remainingText, isNot(contains('957407753917')));
    });

    test('built-in UnionPay detail rule works without source app', () async {
      final ruleSet = await TomlBillingRuleRepository().loadBuiltInRuleSet();

      final result = await BillingRuleEngineImpl().evaluate(
        ruleSet: ruleSet,
        ocrText: [
          '银联交易详情',
          '淘',
          '淘宝平台商户',
          '-￥27.82',
          '优惠信息',
          '银联优惠-￥0.08',
          '收款方',
          '天津滨海测试家居有限公司庚',
          '卡号',
          '工商银行银联信用卡[2454]',
          '交易时间',
          '2026-06-14 12:22:17',
          '订单金额',
          '￥27.90',
          '交易渠道',
          '银行APP',
          '消费',
          '交易类别',
          '分类',
          '百货日用-日用百货',
          '发卡机构',
          '工商银行',
          '收单机构',
          '支付宝(中国)网络技术有限公司',
          '商户编号',
          '972713631844736',
          '终端编号',
          '01080209',
          '批次号',
          '561845',
          '凭证号',
          '500409',
          '参考号',
          '957407753917',
        ].join('\n'),
      );

      expect(result.matchedTemplateId, 'unionpay_pinduoduo_single_v1');
      expect(result.amount, -27.82);
      expect(result.time, DateTime(2026, 6, 14, 12, 22, 17));
      expect(result.paymentChannel, '云闪付');
      expect(result.paymentMethod, '工商银行银联信用卡(1044)');
      expect(result.counterparty, '天津滨海测试家居有限公司庚');
      expect(result.note, '天津滨海测试家居有限公司庚');
      expect(result.acquirer, '支付宝(中国)网络技术有限公司');
      expect(result.details?['merchant_no'], '972713631844736');
      expect(result.details?['terminal_no'], '01080209');
      expect(result.details?['order_amount'], '￥27.90');
      expect(result.details?['batch_no'], '561845');
      expect(result.details?['voucher_no'], '500409');
      expect(result.details?['reference_no'], '957407753917');
      final remainingText = result.details?['remaining_text'] as String?;
      expect(remainingText, contains('优惠信息'));
      expect(remainingText, contains('银联优惠-￥0.08'));
      expect(remainingText, isNot(contains('2026-06-14 12:22:17')));
      expect(remainingText, isNot(contains('工商银行银联信用卡[2454]')));
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
          BillingRuleParserTypes.zhDatetime,
          '2026年05 月31日 14:27:40',
        ).value,
        DateTime(2026, 5, 31, 14, 27, 40),
      );
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.isoDatetime,
          '2026-06-30T12:51:18',
        ).value,
        DateTime(2026, 6, 30, 12, 51, 18),
      );
    });

    test('normalizes common OCR mistakes in institution names', () {
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.institutionName,
          '财付通支付科技有限公司',
        ).value,
        '财付通支付科技有限公司',
      );
    });

    test('normalizes payment method OCR variants', () {
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.paymentMethod,
          '中国银行银联信用卡[2853]',
        ).value,
        '中国银行银联信用卡(3610)',
      );
      expect(
        BillingRuleParsers.parse(
          BillingRuleParserTypes.paymentMethod,
          '平安银行信用卡(2299)>',
        ).value,
        '平安银行信用卡(2299)',
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
