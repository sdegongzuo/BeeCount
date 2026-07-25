import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in WeChat rule extracts supermarket receipt details', () async {
    final ruleSet = await TomlBillingRuleRepository().loadBuiltInRuleSet();
    final result = await BillingRuleEngineImpl().evaluate(
      ruleSet: ruleSet,
      sourcePackage: 'com.tencent.mm',
      ocrText: [
        '当前状态',
        '支付成功',
        '-86.42',
        '支付时间',
        '2026年6月18日 13:24:36',
        '商品',
        '天津和平测试超市甲',
        '商户全称',
        '天津河西测试商贸有限公司卯',
        '收单机构',
        '天津海河测试支付科技有限公司辰',
        '支付方式',
        '中国银行信用卡(2853)',
        '交易单号',
        '9422548327273593242578194027',
        '原价',
        '￥88.12',
        '优惠',
        '摇优惠·银行卡多笔立减优惠￥1.70',
      ].join('\n'),
    );

    expect(result.matchedTemplateId, 'wechat_payment_detail_v1');
    expect(result.amount, -86.42);
    expect(result.time, DateTime(2026, 6, 18, 13, 24, 36));
    expect(result.note, '天津和平测试超市甲');
    expect(result.counterparty, '天津和平测试超市甲');
    expect(result.merchantFullName, '天津河西测试商贸有限公司卯');
    expect(result.acquirer, '天津海河测试支付科技有限公司辰');
    expect(result.paymentMethod, '中国银行信用卡(2853)');
    expect(result.details?['order_amount'], '￥88.12');
    expect(result.details?['discount'], '摇优惠·银行卡多笔立减优惠（¥1.70）');
    expect(
      result.details?['transaction_no'],
      '9422548327273593242578194027',
    );
  });
}
