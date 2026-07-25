import 'package:beecount/services/billing/discount_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const semantics = DiscountSemantics();

  test('优惠文案清洗为详情展示文本和正数统计金额', () {
    final unionPay = semantics.parse('银联优惠-¥1.00');
    expect(unionPay.displayText, '银联优惠（¥1.00）');
    expect(unionPay.amount, 1.00);

    final totalDiscount = semantics.parse('共优惠￥0.26');
    expect(totalDiscount.displayText, '共优惠（¥0.26）');
    expect(totalDiscount.amount, 0.26);

    final cardDiscount = semantics.parse('银行卡立减优惠0.30元');
    expect(cardDiscount.displayText, '银行卡立减优惠（¥0.30）');
    expect(cardDiscount.amount, 0.30);

    final labeledNegativeAmount = semantics.parse('-0.34');
    expect(labeledNegativeAmount.displayText, '优惠（¥0.34）');
    expect(labeledNegativeAmount.amount, 0.34);

    final dynamicCampaign = semantics.parse('百次立减\n-0.05');
    expect(dynamicCampaign.displayText, '百次立减（¥0.05）');
    expect(dynamicCampaign.amount, 0.05);

    final realizedAfterUpperBound = semantics.parse('最高减10元，已减2元');
    expect(realizedAfterUpperBound.displayText, '最高减10元，已减（¥2.00）');
    expect(realizedAfterUpperBound.amount, 2.00);

    final negativeAfterUpperBound = semantics.parse('信用卡至高减10元优惠 -0.14');
    expect(
      negativeAfterUpperBound.displayText,
      '信用卡至高减10元优惠（¥0.14）',
    );
    expect(negativeAfterUpperBound.amount, 0.14);
  });

  test('非金额优惠只保留详情证据且不参与统计', () {
    final points = semantics.parse('获得10积分');
    expect(points.displayText, '获得10积分');
    expect(points.amount, isNull);

    final rate = semantics.parse('享8折优惠');
    expect(rate.displayText, '享8折优惠');
    expect(rate.amount, isNull);
  });

  test('条件优惠和优惠券面额不作为已兑现优惠统计', () {
    const semantics = DiscountSemantics();

    for (final text in [
      '满100元减20元',
      '赠10元优惠券',
      '最高优惠10元',
      '至高优惠10元',
      '信用卡最高优惠10元',
      '立减次数3',
    ]) {
      final result = semantics.parse(text);
      expect(result.displayText, text);
      expect(result.amount, isNull);
    }
  });
}
