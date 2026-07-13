import 'package:beecount/services/billing/ocr_text_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isUsableRapidOcrText', () {
    test('accepts a payment detail with a monetary amount', () {
      expect(
        isUsableRapidOcrText('''
银联交易详情
淘宝平台商户
-¥27.82
交易时间 2026-06-14 12:22:17
'''),
        isTrue,
      );
    });

    test('rejects nonempty garbled text without payment evidence', () {
      expect(
        isUsableRapidOcrText('''
炼
羞燥从膦折力
锕赉字丿扒啮
8永妇-可0妇
尘涩竟午;煨煨瓯腴獒奉块
'''),
        isFalse,
      );
    });
  });
}
