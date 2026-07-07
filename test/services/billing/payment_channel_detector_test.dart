import 'package:beecount/services/billing/bill_recognition_normalizer.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/payment_channel_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentChannelResolver', () {
    const resolver = PaymentChannelResolver();

    Future<String?> channelFor(String rawText) async {
      return (await resolver.resolve(rawText))?.channel;
    }

    test('detects Alipay bill details without Alipay brand text', () async {
      expect(
        await channelFor('''
账单详情 全部账单
天津津门测试网络科技有限公司壬
-34.00
交易成功
管理 自动扣款 津门测试云服务套餐自动续费
订单金额 34.32
建设银行天天减 -0.32
支付时间 2026-06-06 09:57:10
付款方式 建设银行信用卡(3932)
商品说明 S9503484253173447248799
支付奖励 已领取3积分
订单号 9611254796896706230407867877
商家订单号 913867211720612873803
账单管理
账单分类 文化休闲
'''),
        '支付宝',
      );
    });

    test('detects Alipay with OCR typo in pay time label', () async {
      expect(
        await channelFor('''
账单详情
支付时问
付款歉万式
管理自动扣款 ETC服务免密支付
支付奖励
支付宝
-2.53
自动扣款成功
平安银行信用卡(2299)
已支付
'''),
        '支付宝',
      );
    });

    test('detects UnionPay and ignores Alipay as acquirer', () async {
      final detection = await resolver.resolve('''
银联交易详情
饿了么平台商户 -¥16.74
收款方 天津滨海测试信息科技有限公司癸
卡号 招商银行银联信用卡[6428]
交易时间 2026-06-05 11:13:22
交易类别 消费
分类 百货日用-日用百货
发卡机构 招商银行信用卡中心
收单机构 支付宝(中国)网络技术有限公司
商户编号 99837770198304
终端编号 01080209
批次号 551978
凭证号 350409
授权号 161593
参考号 924154656816
''');

      expect(detection?.channel, '云闪付');
      expect(detection?.confidence, greaterThanOrEqualTo(0.95));
    });

    test('detects UnionPay receipt page without detail title', () async {
      expect(
        await channelFor('''
原价 优惠 付款方式
支付咸功
天津测试茶饮店_财付通(银联云闪付)
¥7.68
0.32元立减券- ¥0.32
中国銀行银联准贷记卡 [2853]
'''),
        '云闪付',
      );
    });

    test('detects Meituan while keeping payment method separate', () async {
      expect(
        await channelFor('''
账单详情 全部账单
天津测试超市-订单编号9206948839163952
-49.00 支付成功
支付方式 美团月付
下单时间 2026-05-03 18:31:44
消费场景 天津测试超市
交易单号 93436166922987259821343023152738
商家单号 9206948839163952-57068d897e012
常见问题 在哪里可以找到全部账单 打开美团App首页 搜索美团账单
'''),
        '美团',
      );
    });

    test('detects JD multi-order bill details', () async {
      expect(
        await channelFor('''
账单详情
京东平台商户
-210.95 交易成功
支付立减 -1.65
支付方式 中国银行信用卡(2853)
创建时间 2026-05-19 20:36:50
总订单编号 9964956301053902
商户单号 9054211058743323354445872907
服务详情 共2笔订单
京东笔笔返
'''),
        '京东',
      );
    });

    test('detects Pinduoduo without Pinduoduo brand text', () async {
      expect(
        await channelFor('''
账单详情
天津和平测试日用品二店
-4.75
当前状态 支付成功
商品详情 津门测试一体成型家用铁锤
订单详情
支付时间 2026-04-14 08:37:56
支付方式 平安银行信用卡(2299)
交易单号 93948095285743013904138360178735
商户单号 XP9869667409910336534743007541
'''),
        '拼多多',
      );
    });

    test('detects WeChat payment from text evidence without UnionPay conflict',
        () async {
      expect(
        await channelFor('''
交易详情
拼多多
-19.50
支付时间 2026年05月31日 14:27:40
支付方式 平安银行信用卡(2299)
收单机构 财付通支付科技有限公司
'''),
        '微信支付',
      );
    });
  });

  group('OcrService amount extraction', () {
    test('preserves OCR engine in serialized result', () {
      final result = OcrResult(
        rawText: '拼多多\n-19.50',
        allNumbers: const ['19.50'],
        ocrEngine: 'rapidocr',
      );

      expect(result.toJson()['ocr_engine'], 'rapidocr');
      expect(result.copyWithAI(note: '拼多多').toJson()['ocr_engine'], 'rapidocr');
    });

    test('does not use discount line as the primary amount', () {
      final result = OcrService().parsePaymentText('''
原价
优惠
付款方式
支付咸功
天津测试茶饮店_财付通(银联云闪付)
¥7.68
0.32元立减券- ¥0.32
中国銀行银联准贷记卡 [2853]
''');

      expect(result.amount, -7.68);
    });

    test('extracts negative currency top amount', () {
      final result = OcrService().parsePaymentText('''
银联交易详倩
拼多多平台商户
一¥23.60
中国银行銀联信用卡[2853]
''');

      expect(result.amount, -23.60);
    });

    test('prefers top negative amount over discount currency amount', () {
      final result = OcrService().parsePaymentText('''
拼多多
-19.50
原价 19.80
支付成功
优惠¥0.30
支付时间 2026年05月31日 14:27:40
支付方式 平安银行信用卡(2299)
''');

      expect(result.amount, -19.50);
    });

    test('extracts Chinese date with OCR spacing around month', () {
      final result = OcrService().parsePaymentText('''
支付时间
2026年05 月31日 14:27:40
支付方式 平安银行信用卡(2299)
''');

      expect(result.time, DateTime(2026, 5, 31, 14, 27, 40));
    });
  });

  group('BillRecognitionNormalizer channel precedence', () {
    test('detected channel overrides AI channel without changing method', () {
      final result = const BillRecognitionNormalizer().normalize(
        const BillRecognitionFields(
          paymentChannel: '云闪付',
          paymentMethod: '云闪付-招商银行(0791)',
        ),
        detectedPaymentChannel: '支付宝',
      );

      expect(result.paymentChannel, '支付宝');
      expect(result.paymentMethod, '云闪付-招商银行(0791)');
    });
  });
}
