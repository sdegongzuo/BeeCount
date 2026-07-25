import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/billing/details_text_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('云闪付账单的卡号归一为用户支付方式', () async {
    final ruleSet = await TomlBillingRuleRepository().loadBuiltInRuleSet();
    final result = await BillingRuleEngineImpl().evaluate(
      ruleSet: ruleSet,
      sourcePackage: 'com.unionpay',
      sourceAppName: '云闪付',
      ocrText: [
        '银联交易详情',
        '财付通(银联云闪付)',
        '-￥7.90',
        '收款方',
        '天津津门测试餐饮有限公司乙',
        '优惠信息',
        '银联优惠-¥1.00',
        '卡号',
        '中国银行银联信用卡[2853]',
        '交易时间',
        '2026-07-19 12:57:56',
        '交易渠道',
        '云闪付APP',
        '消费',
        '交易类别',
        '分类',
        '其他门类-其他',
        '发卡机构',
        '中国银行',
        '收单机构',
        '财付通支付科技有限公司',
        '商户编号',
        '946684247618003',
        '参考号',
        '936697774930',
      ].join('\n'),
    );

    expect(result.matchedTemplateId, 'unionpay_pinduoduo_single_v1');
    expect(result.paymentMethod, '中国银行信用卡(2853)');
    expect(result.details?['discount'], '银联优惠-¥1.00');
    expect(detailsMapToText(result.details), contains('优惠: 银联优惠-¥1.00'));
  });
}
