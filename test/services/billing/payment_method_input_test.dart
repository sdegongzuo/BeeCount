import 'package:beecount/services/billing/payment_method_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('支付方式输入统一 canonicalize，并保留空值和拒绝状态', () {
    expect(
      canonicalizePaymentMethodInput('中国银行银联信用卡[2853]').value,
      '中国银行信用卡(2853)',
    );
    expect(canonicalizePaymentMethodInput(null).value, isNull);
    expect(canonicalizePaymentMethodInput('支付\n方式').isRejected, isTrue);
  });
}
