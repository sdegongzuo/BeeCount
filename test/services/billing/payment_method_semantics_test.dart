import 'package:beecount/services/billing/payment_method_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const semantics = PaymentMethodSemantics();

  group('PaymentMethodSemantics.canonicalize', () {
    test('canonicalizes supported OCR card variants conservatively', () {
      expect(
        semantics.canonicalize('中国银行银联信用卡[2853]').value,
        '中国银行信用卡(2853)',
      );
      expect(
        semantics.canonicalize(' 招商银行 银联 信用卡【7549】 ').value,
        '招商银行信用卡(7549)',
      );
      expect(
        semantics.canonicalize('工商银行借记卡（4886）').value,
        '工商银行借记卡(4886)',
      );
      expect(
        semantics.canonicalize('平安银行信用卡(2299)>').value,
        '平安银行信用卡(2299)',
      );
    });

    test('does not remove 银联 from an entity or unknown value', () {
      expect(
        semantics.canonicalize('财付通(银联云闪付)').value,
        '财付通(银联云闪付)',
      );
      expect(semantics.canonicalize('银联商务').value, '银联商务');
      expect(semantics.canonicalize('微信零钱').value, '微信零钱');
      expect(
        semantics.canonicalize('Apple Pay').status,
        PaymentMethodNormalizationStatus.unchanged,
      );
      expect(semantics.canonicalize('Apple Pay').value, 'Apple Pay');
    });

    test('rejects invalid candidates and treats blanks as empty', () {
      expect(
        semantics.canonicalize('支付方式').status,
        PaymentMethodNormalizationStatus.rejected,
      );
      expect(
        semantics.canonicalize('中国银行\n信用卡').status,
        PaymentMethodNormalizationStatus.rejected,
      );
      expect(
        semantics.canonicalize('x' * 129).status,
        PaymentMethodNormalizationStatus.rejected,
      );
      expect(
        semantics.canonicalize('  ').status,
        PaymentMethodNormalizationStatus.empty,
      );
    });

    test('is idempotent', () {
      final once = semantics.canonicalize('中国银行银联信用卡[2853]').value;
      expect(semantics.canonicalize(once).value, once);
    });
  });

  test('formatForHome shortens only the homepage representation', () {
    const canonical = '中国银行信用卡(2853)';
    expect(semantics.formatForHome(canonical), '中行信用卡(2853)');
    expect(canonical, '中国银行信用卡(2853)');
    expect(
      semantics.formatForHome('数字人民币-招商银行钱包(0076)'),
      '数字人民币-招行钱包(0076)',
    );
  });
}
