import 'package:beecount/services/ai/bill_extraction_service.dart';
import 'package:beecount/services/billing/fast_billing_rule_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/platform/screenshot_source_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FastBillingRuleService', () {
    test('accepts high confidence WeChat payment detail rule result', () async {
      final traces = <BillExtractionTraceEvent>[];
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_wechatRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _wechatPaymentText,
        allNumbers: const [],
      );

      final evaluation = await service.evaluate(
        baseResult: baseResult,
        sourceInfo: const ScreenshotSourceInfo(
          packageName: 'com.tencent.mm',
          appName: '微信',
          paymentChannel: '微信支付',
          confidence: 0.96,
          method: 'usage_stats',
        ),
        traceSink: traces.add,
      );

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, 12.34);
      expect(evaluation.result.time, DateTime(2026, 6, 30, 12, 51, 18));
      expect(evaluation.result.paymentChannel, '微信支付');
      expect(evaluation.result.paymentMethod, '零钱');
      expect(evaluation.result.merchantFullName, '天津河西测试餐饮有限公司戊');
      expect(evaluation.result.fastBillingAccepted, isTrue);
      expect(evaluation.result.fastBillingRejectReasons, isEmpty);
      expect(evaluation.result.billingRuleResult?.matchedTemplateId,
          'wechat_payment_detail_v1');
      expect(
        traces.map((event) => event.stage),
        contains('billing_rule'),
      );
    });

    test('rejects low confidence rule result when required fields are missing',
        () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_wechatRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _wechatPaymentText.replaceAll('2026年06月30日 12:51:18\n', ''),
        allNumbers: const [],
      );

      final evaluation = await service.evaluate(
        baseResult: baseResult,
        sourceInfo: const ScreenshotSourceInfo(
          packageName: 'com.tencent.mm',
          appName: '微信',
          paymentChannel: '微信支付',
          confidence: 0.96,
          method: 'usage_stats',
        ),
      );

      expect(evaluation.accepted, isFalse);
      expect(evaluation.rejectReasons, contains('missing_time'));
      expect(evaluation.result.amount, 12.34);
      expect(evaluation.result.paymentChannel, '微信支付');
      expect(evaluation.result.time, isNull);
      expect(evaluation.result.fastBillingAccepted, isFalse);
      expect(
          evaluation.result.fastBillingRejectReasons, contains('missing_time'));
    });

    test('keeps OCR detected payment channel when source channel conflicts',
        () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_emptyRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: '美团账单\n支付成功\n-20.70\n下单时间\n2026-07-04 21:31:28',
        amount: -20.70,
        time: DateTime(2026, 7, 4, 21, 31, 28),
        paymentChannel: '美团',
        allNumbers: const ['20.70'],
      );

      final evaluation = await service.evaluate(
        baseResult: baseResult,
        sourceInfo: const ScreenshotSourceInfo(
          paymentChannel: '支付宝',
          confidence: 0.9,
          method: 'test_pending_payload',
        ),
      );

      expect(evaluation.accepted, isFalse);
      expect(evaluation.rejectReasons, contains('no_rule_match'));
      expect(evaluation.result.paymentChannel, '美团');
    });

    test('accepts strong WeChat OCR text when source app is unavailable',
        () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_wechatRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _wechatPaymentTextWithoutSourceAppSignal,
        allNumbers: const ['19.80', '19.50', '0.30'],
      );

      final evaluation = await service.evaluate(baseResult: baseResult);

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -19.5);
      expect(evaluation.result.time, DateTime(2026, 5, 31, 14, 27, 40));
      expect(evaluation.result.paymentChannel, '微信支付');
      expect(evaluation.result.paymentMethod, '平安银行信用卡(2299)');
      expect(evaluation.result.acquirer, '财付通支付科技有限公司');
      expect(evaluation.result.billingRuleResult?.matchedTemplateId,
          'wechat_payment_detail_v1');
    });

    test('accepts Meituan bill detail without source package', () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_meituanRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _meituanBillText,
        amount: -20.70,
        time: DateTime(2026, 7, 4, 21, 31, 28),
        paymentChannel: '美团',
        allNumbers: const ['20.70', '20'],
      );

      final evaluation = await service.evaluate(baseResult: baseResult);

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -20.70);
      expect(evaluation.result.time, DateTime(2026, 7, 4, 21, 31, 28));
      expect(evaluation.result.paymentChannel, '美团');
      expect(evaluation.result.note, '天津海河测试盖饭（和平测试店）');
      expect(evaluation.result.details?['transaction_no'],
          '9912501641549198789139965392');
      expect(evaluation.result.details?['merchant_order_no'],
          '0_9101216766373434');
    });

    test('accepts JD bill detail without source package', () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_jdRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _jdBillText,
        amount: -45.60,
        time: DateTime(2026, 7, 3, 21, 4, 50),
        paymentChannel: '京东',
        allNumbers: const ['45.60', '45', '0.40'],
      );

      final evaluation = await service.evaluate(baseResult: baseResult);

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -45.60);
      expect(evaluation.result.time, DateTime(2026, 7, 3, 21, 4, 50));
      expect(evaluation.result.paymentChannel, '京东');
      expect(evaluation.result.note, '京东买药');
      expect(evaluation.result.paymentMethod, '中国银行信用卡（2853）');
      expect(evaluation.result.details?['order_no'], '9717542574519413');
      expect(evaluation.result.details?['merchant_order_no'],
          '9458313000119266428366399457');
      expect(evaluation.result.details?['discount'], '-0.40');
    });

    test('extracts JD product title as note when service detail is not a shop',
        () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_jdRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _jdProductBillText,
        amount: -62.90,
        time: DateTime(2026, 7, 3, 20, 25, 26),
        paymentChannel: '京东',
        allNumbers: const ['62.90', '62', '1.00', '1'],
      );

      final evaluation = await service.evaluate(baseResult: baseResult);

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -62.90);
      expect(evaluation.result.time, DateTime(2026, 7, 3, 20, 25, 26));
      expect(evaluation.result.paymentChannel, '京东');
      expect(evaluation.result.note, '滨海测试家用木质砧板');
      expect(evaluation.result.paymentMethod, '中国银行信用卡（2853）');
      expect(evaluation.result.details?['order_no'], '9393828750240214');
      expect(evaluation.result.details?['merchant_order_no'],
          '9356035498922568809136331765');
      expect(evaluation.result.details?['discount'], '-1.00');
    });

    test('accepts Douyin payment detail when gallery is foreground', () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_douyinRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _douyinPaymentText,
        allNumbers: const ['8.74', '8', '3.48', '3', '0.42'],
        amount: -3.48,
        note: '天津海河测试科技有限公司辛',
        paymentChannel: '抖音',
      );

      final evaluation = await service.evaluate(
        baseResult: baseResult,
        sourceInfo: const ScreenshotSourceInfo(
          packageName: 'com.coloros.gallery3d',
          appName: '相册',
          confidence: 0.5,
          method: 'usage_stats',
          screenshotTimeMillis: 9442496185408,
        ),
      );

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -3.48);
      expect(evaluation.result.note, '天津海河测试科技有限公司辛');
      expect(evaluation.result.time,
          DateTime.fromMillisecondsSinceEpoch(9442496185408));
      expect(evaluation.result.paymentChannel, '抖音');
      expect(evaluation.result.paymentMethod, '抖音月付');
      expect(evaluation.result.billingRuleResult?.matchedTemplateId,
          'douyin_payment_detail_v1');
    });

    test('accepts Alipay ETC auto debit payment detail', () async {
      final service = FastBillingRuleService(
        ruleRepository: _MemoryRuleRepository(_alipayRuleSet()),
        ruleEngine: BillingRuleEngineImpl(),
      );
      final baseResult = OcrResult(
        rawText: _alipayEtcPaymentText,
        allNumbers: const ['3.75', '3'],
        amount: -3.75,
        time: DateTime(2026, 7, 3, 23, 30, 20),
        paymentChannel: '支付宝',
      );

      final evaluation = await service.evaluate(
        baseResult: baseResult,
        sourceInfo: const ScreenshotSourceInfo(
          packageName: 'com.eg.android.AlipayGphone',
          paymentChannel: '支付宝',
          confidence: 0.9,
          method: 'usage_stats',
          screenshotTimeMillis: 9331861134258,
        ),
      );

      expect(evaluation.accepted, isTrue);
      expect(evaluation.rejectReasons, isEmpty);
      expect(evaluation.result.amount, -3.75);
      expect(evaluation.result.time, DateTime(2026, 7, 3, 23, 30, 20));
      expect(evaluation.result.paymentChannel, '支付宝');
      expect(evaluation.result.paymentMethod, '平安银行信用卡(2299)');
      expect(evaluation.result.note, 'ETC服务');
      expect(evaluation.result.details?['route_start'], '天津测试甲站');
      expect(evaluation.result.details?['route_end'], '天津测试乙站');
      expect(evaluation.result.billingRuleResult?.matchedTemplateId,
          'alipay_payment_detail_v1');
    });
  });
}

const _wechatPaymentText = '''
微信支付
支付详情
当前状态
支付成功
金额
12.34元
支付时间
2026年06月30日 12:51:18
商户全称
天津河西测试餐饮有限公司戊
收单机构
财付通支付科技有限公司
支付方式
零钱
交易单号
9422548327273593242578194027
商户单号
M95275990721980
''';

const _wechatPaymentTextWithoutSourceAppSignal = '''
拼多多
服务
交易详情
-19.50
拼多多
原价
￥19.80
优惠
摇优惠·银行卡多笔立减优惠0.30
当前状态
支付成功
支付时间
2026年05月31日 14:27:40
商品
商户单号
XP9250027811994856890233755142
收单机构
财付通支付科技有限公司
支付方式
平安银行信用卡(2299)
交易单号
9223292424251435949411772872
''';

const _douyinPaymentText = '''
删除
账单详情
4O

天津海河测试科技有限公司辛
-3.48
支付成功
关联记录
与其它1笔订单共支付8.74元
￥ 0.42
抖音支付优惠
付款方式
抖音月付>
月付账单信息
7月1日券使用后计入月付账单
抖音支付勋章
点击领取抖音支付勋章
抖音支付积分
已领取6积分，去兑好礼
更多
商品订单
鲜萃有堡两件套上新达人专属
申请电子交易凭证
v
联系商家
>
m
''';

const _alipayEtcPaymentText = '''
账单详情

支付宝
-3.75
自动扣款成功
管理自动扣款
ETC服务免密支付
支付时间
2026-07-03 23:30:20
付款方式
平安银行信用卡(2299)>
温馨提示
ETC服务为先通行后扣费，扣费可能延
迟，请关注行程时间
支付奖励
已领取2积分>
交易详情
已支付
ETC服务
ETC
出发：天津测试甲站
ETC
到达：天津测试乙站
2026-07-03 21:51:58至2026-07-03 22:03:19
行程详情
联系商家
推荐服务
点击查看今日可用红包等优惠
去查看 >
%
更多
+++
0
''';

const _meituanBillText = '''
账单详情
全部账单
6
天津海河测试盖饭（和平测试店）
-20.70
支付成功
下单时间
2026-07-04 21:31:28
美团
下单平台
美团App
外卖
交易单号
9912501641549198789139965392
7610 复制
商家单号
0_9101216766373434
收起^
常见问题
''';

const _jdBillText = '''
账单详情
京东平台商户
-45.60
交易成功
-0.40
支付立减
支付方式
中国银行信用卡（2853）
创建时间
2026-07-03 21:04:50
总订单编号
9717542574519413
商户单号
9458313000119266428366399457
共1笔订单
服务详情
O京东买药
阿苯达唑打虫药
迪泰阿苯达唑胶囊8粒阿苯达唑片人用
成人儿童皆可用
可苯达唑胶囊
共2件丨完成丨订单编号：9717542574519413
*
京东笔笔返
查看更多权益>
其他服务
账单分类
其他网购
查看常见问题
对此账单有疑问
''';

const _jdProductBillText = '''
账单详情
京东平台商户
-62.90
交易成功
-1.00
支付立减
支付方式
中国银行信用卡（2853）
创建时间
2026-07-03 20:25:26
总订单编号
9393828750240214
商户单号
9356035498922568809136331765
共1笔订单
服务详情
滨海测试家用木质砧板
珍稀花梨
抗菌整切
全调硬术
共1件丨等待收货丨订单编号：99982957145287...
*
京东笔笔返
查看更多权益>
其他服务
账单分类
日用百货
查看常见问题
对此账单有疑问
''';

BillingRuleSet _emptyRuleSet() {
  return const BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: 'test.empty',
    paymentChannels: [],
    templates: [],
  );
}

BillingRuleSet _meituanRuleSet() {
  return BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: '2026.07.01.1',
    paymentChannels: const [],
    templates: const [
      BillingRuleTemplate(
        id: 'meituan_bill_detail_v1',
        priority: 88,
        baseConfidence: 0.86,
        match: BillingRuleTemplateMatch(
          keywordsAll: ['账单详情', '支付成功', '下单平台'],
          keywordsAny: ['美团App', '外卖', '美团账单', '交易单号', '商家单号'],
        ),
        extractors: [
          BillingFieldExtractorRule(
            field: 'paymentChannel',
            type: 'constant',
            value: '美团',
            confidence: 0.94,
          ),
          BillingFieldExtractorRule(
            field: 'amount',
            type: 'regex',
            pattern: r'^\s*([-−]\s*\d{1,6}\.\d{1,2})\s*$',
            parser: 'signedAmount',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'time',
            type: 'labelNextLine',
            label: '下单时间',
            parser: 'isoDatetime',
            confidence: 0.88,
          ),
          BillingFieldExtractorRule(
            field: 'note',
            type: 'regex',
            pattern: r'^(.{2,40}(?:店|饭|餐厅|外卖).*)$',
            confidence: 0.8,
          ),
          BillingFieldExtractorRule(
            field: 'details.transaction_no',
            type: 'labelNextLine',
            label: '交易单号',
            pattern: r'\d{20,}',
            confidence: 0.86,
          ),
          BillingFieldExtractorRule(
            field: 'details.merchant_order_no',
            type: 'labelNextLine',
            label: '商家单号',
            confidence: 0.8,
          ),
        ],
      ),
    ],
  );
}

BillingRuleSet _jdRuleSet() {
  return BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: '2026.07.01.1',
    paymentChannels: const [],
    templates: const [
      BillingRuleTemplate(
        id: 'jd_bill_detail_v1',
        priority: 87,
        baseConfidence: 0.86,
        match: BillingRuleTemplateMatch(
          keywordsAll: ['账单详情', '京东平台商户', '交易成功'],
          keywordsAny: ['支付方式', '创建时间', '总订单编号', '京东买药', '账单分类'],
        ),
        extractors: [
          BillingFieldExtractorRule(
            field: 'paymentChannel',
            type: 'constant',
            value: '京东',
            confidence: 0.93,
          ),
          BillingFieldExtractorRule(
            field: 'amount',
            type: 'regex',
            pattern: r'^\s*([-−]\s*\d{1,6}\.\d{1,2})\s*$',
            parser: 'signedAmount',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'time',
            type: 'labelNextLine',
            label: '创建时间',
            parser: 'isoDatetime',
            confidence: 0.88,
          ),
          BillingFieldExtractorRule(
            field: 'paymentMethod',
            type: 'labelNextLine',
            label: '支付方式',
            confidence: 0.84,
          ),
          BillingFieldExtractorRule(
            field: 'note',
            type: 'labelNextLine',
            label: '服务详情',
            pattern: r'[O0]?(.{2,40})',
            confidence: 0.8,
          ),
          BillingFieldExtractorRule(
            field: 'details.order_no',
            type: 'labelNextLine',
            label: '总订单编号',
            pattern: r'\d{10,}',
            confidence: 0.86,
          ),
          BillingFieldExtractorRule(
            field: 'details.merchant_order_no',
            type: 'labelNextLine',
            label: '商户单号',
            pattern: r'\d{10,}',
            confidence: 0.82,
          ),
          BillingFieldExtractorRule(
            field: 'details.discount',
            type: 'nearKeyword',
            label: '支付立减',
            pattern: r'([-−]\d{1,6}\.\d{1,2})',
            options: {'windowLines': 1},
            confidence: 0.72,
          ),
        ],
      ),
    ],
  );
}

BillingRuleSet _wechatRuleSet() {
  return BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: '2026.07.01.1',
    paymentChannels: const [],
    templates: [
      BillingRuleTemplate(
        id: 'wechat_payment_detail_v1',
        priority: 100,
        baseConfidence: 0.88,
        match: const BillingRuleTemplateMatch(
          sourcePackages: ['com.tencent.mm'],
          keywordsAll: ['当前状态', '支付时间', '交易单号'],
          keywordsAny: ['微信支付', '支付详情', '交易详情', '财付通支付科技有限公司'],
        ),
        extractors: const [
          BillingFieldExtractorRule(
            field: 'paymentChannel',
            type: 'constant',
            value: '微信支付',
            confidence: 0.95,
          ),
          BillingFieldExtractorRule(
            field: 'amount',
            type: 'regex',
            pattern: r'^\s*([¥￥]?\s*[-+]?\d{1,6}\.\d{1,2})\s*(?:元)?\s*$',
            parser: 'signedAmount',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'time',
            type: 'labelNextLine',
            label: '支付时间',
            parser: 'zhDatetime',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'merchantFullName',
            type: 'labelNextLine',
            label: '商户全称',
            confidence: 0.85,
          ),
          BillingFieldExtractorRule(
            field: 'acquirer',
            type: 'labelNextLine',
            label: '收单机构',
            confidence: 0.8,
          ),
          BillingFieldExtractorRule(
            field: 'paymentMethod',
            type: 'labelNextLine',
            label: '支付方式',
            confidence: 0.85,
          ),
          BillingFieldExtractorRule(
            field: 'details.transaction_no',
            type: 'labelNextLine',
            label: '交易单号',
            pattern: r'\d{20,}',
            confidence: 0.9,
          ),
        ],
      ),
    ],
  );
}

BillingRuleSet _douyinRuleSet() {
  return BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: '2026.07.04.1',
    paymentChannels: const [],
    templates: [
      BillingRuleTemplate(
        id: 'douyin_payment_detail_v1',
        priority: 90,
        baseConfidence: 0.86,
        match: const BillingRuleTemplateMatch(
          sourcePackages: ['com.ss.android.ugc.aweme'],
          keywordsAll: ['账单详情', '支付成功', '付款方式'],
          keywordsAny: ['抖音支付', '抖音月付', '商品订单'],
        ),
        extractors: const [
          BillingFieldExtractorRule(
            field: 'paymentChannel',
            type: 'constant',
            value: '抖音',
            confidence: 0.95,
          ),
          BillingFieldExtractorRule(
            field: 'amount',
            type: 'regex',
            pattern: r'^\s*([-−]\s*\d{1,6}\.\d{1,2})\s*$',
            parser: 'signedAmount',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'paymentMethod',
            type: 'labelNextLine',
            label: '付款方式',
            pattern: r'([^>]+)',
            confidence: 0.85,
          ),
          BillingFieldExtractorRule(
            field: 'note',
            type: 'regex',
            pattern: r'^([^\n]{2,30}(?:有限公司|责任公司|股份公司|公司|店|商行))$',
            confidence: 0.82,
          ),
        ],
      ),
    ],
  );
}

BillingRuleSet _alipayRuleSet() {
  return BillingRuleSet(
    schemaVersion: 1,
    rulesVersion: '2026.07.04.2',
    paymentChannels: const [],
    templates: [
      BillingRuleTemplate(
        id: 'alipay_payment_detail_v1',
        priority: 95,
        baseConfidence: 0.87,
        match: const BillingRuleTemplateMatch(
          sourcePackages: ['com.eg.android.AlipayGphone'],
          keywordsAll: ['账单详情', '支付时间', '付款方式'],
          keywordsAny: ['支付宝', '自动扣款成功', '交易详情', '已支付'],
        ),
        extractors: const [
          BillingFieldExtractorRule(
            field: 'paymentChannel',
            type: 'constant',
            value: '支付宝',
            confidence: 0.95,
          ),
          BillingFieldExtractorRule(
            field: 'amount',
            type: 'regex',
            pattern: r'^\s*([-−]\s*\d{1,6}\.\d{1,2})\s*$',
            parser: 'signedAmount',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'time',
            type: 'labelNextLine',
            label: '支付时间',
            parser: 'isoDatetime',
            confidence: 0.9,
          ),
          BillingFieldExtractorRule(
            field: 'paymentMethod',
            type: 'labelNextLine',
            label: '付款方式',
            pattern: r'([^>]+)',
            confidence: 0.85,
          ),
          BillingFieldExtractorRule(
            field: 'note',
            type: 'nearKeyword',
            label: '交易详情',
            pattern: r'(ETC服务)',
            options: {'windowLines': 3},
            confidence: 0.82,
          ),
          BillingFieldExtractorRule(
            field: 'details.route_start',
            type: 'regex',
            pattern: r'出发[:：]\s*([^\n]+)',
            confidence: 0.8,
          ),
          BillingFieldExtractorRule(
            field: 'details.route_end',
            type: 'regex',
            pattern: r'到达[:：]\s*([^\n]+)',
            confidence: 0.8,
          ),
          BillingFieldExtractorRule(
            field: 'details.trip_time_range',
            type: 'regex',
            pattern:
                r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}至\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})',
            confidence: 0.75,
          ),
        ],
      ),
    ],
  );
}

class _MemoryRuleRepository implements BillingRuleRepository {
  final BillingRuleSet ruleSet;

  const _MemoryRuleRepository(this.ruleSet);

  @override
  Future<BillingRuleSet> loadActiveRuleSet() async => ruleSet;

  @override
  Future<BillingRuleSet> loadBuiltInRuleSet() async => ruleSet;

  @override
  Future<BillingRuleSet?> loadDebugOverrideRuleSet() async => null;

  @override
  Future<void> validateRuleSet(BillingRuleSet ruleSet) async {}
}
