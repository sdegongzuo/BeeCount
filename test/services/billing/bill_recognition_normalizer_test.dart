import 'package:beecount/services/billing/bill_recognition_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillRecognitionNormalizer', () {
    const normalizer = BillRecognitionNormalizer();

    test('normalizes formats and preserves rewritten originals', () {
      final result = normalizer.normalize(
        const BillRecognitionFields(
          category: '医疗保健',
          paymentMethod: '中国银行银联准贷记卡[2853]',
          paymentChannel: '银联云闪付',
        ),
      );

      expect(result.category, '医疗');
      expect(result.paymentMethod, '中国银行银联准贷记卡(3610)');
      expect(result.paymentChannel, '云闪付');
      expect(result.details?['original_fields'], {
        'category': '医疗保健',
        'payment_method': '中国银行银联准贷记卡[2853]',
        'payment_channel': '银联云闪付',
      });
    });

    test('keeps store name in details and normalizes counterparty', () {
      final result = normalizer.normalize(
        const BillRecognitionFields(
          note: '天津津门测试餐厅乙',
          category: '餐饮',
          counterparty: '天津津门测试餐厅乙（南开测试店）',
          paymentMethod: '中国银行信用卡(2853)',
          details: {
            'transaction_no': '9084770061104736748300498358',
          },
        ),
      );

      expect(result.counterparty, '天津津门测试餐厅乙');
      expect(result.details?['store_name'], '南开测试店');
      expect(result.details?['transaction_no'], '9084770061104736748300498358');
      expect(result.details?['original_fields'], {
        'counterparty': '天津津门测试餐厅乙（南开测试店）',
      });
    });

    test('normalizes known note variants', () {
      final pinduoduo = normalizer.normalize(
        const BillRecognitionFields(
          note: '拼多多购物',
          paymentChannel: '拼多多',
          counterparty: '拼多多',
        ),
        detectedPaymentChannel: '微信支付',
      );

      final etc = normalizer.normalize(
        const BillRecognitionFields(note: 'ETC通行费'),
      );

      final membership = normalizer.normalize(
        const BillRecognitionFields(note: '月卡会员神券包'),
      );

      expect(pinduoduo.note, '拼多多');
      expect(pinduoduo.paymentChannel, '微信支付');
      expect(pinduoduo.details?['original_fields'], {
        'note': '拼多多购物',
        'payment_channel': '拼多多',
      });
      expect(etc.note, 'ETC服务');
      expect(membership.note, '月卡会员超值神券包');
    });
  });
}
