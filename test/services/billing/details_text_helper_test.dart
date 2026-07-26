import 'package:beecount/services/billing/details_text_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detailsMapToText', () {
    test('keeps user-facing fields and hides internal diagnostics', () {
      final text = detailsMapToText({
        'screenshot_source_confidence': 0.0,
        'screenshot_source_method': 'usage_stats_no_candidate',
        'ocr_payment_channel': '支付宝',
        'route_start': '天津测试甲站',
        'route_end': '天津测试乙站',
        'trip_time_range': '2026-07-06 18:13:41至2026-07-06 18:21:55',
        'remaining_text': '<账单详情\n支付宝\n订单号\n20260706',
        'billing_rule_template_id': 'alipay_payment_detail_v1',
        'billing_rule_confidence': 0.8495,
        'ai_enhance_status': 'failed',
        'ai_enhance_error': 'empty_ai_result',
      });

      expect(text, contains('出发站: 天津测试甲站'));
      expect(text, contains('到达站: 天津测试乙站'));
      expect(text, contains('通行时间: 2026-07-06 18:13:41至2026-07-06 18:21:55'));
      expect(text, isNot(contains('screenshot_source')));
      expect(text, isNot(contains('ocr_payment_channel')));
      expect(text, isNot(contains('remaining_text')));
      expect(text, isNot(contains('支付宝: true')));
      expect(text, isNot(contains('billing_rule_')));
      expect(text, isNot(contains('ai_enhance_')));
    });

    test('returns null when only internal details are present', () {
      final text = detailsMapToText({
        'remaining_text': '账单详情\n支付宝',
        'billing_rule_template_id': 'alipay_payment_detail_v1',
        'ai_enhance_status': 'failed',
      });

      expect(text, isNull);
    });

    test('显式明细在前，通用标签值按截图顺序追加', () {
      final text = detailsMapToText({
        'order_no': '9569805267061115767991919176',
        'merchant_order_no': 'sub2_202607260bofXWQU',
        'additional_fields': [
          {'label': '支付奖励', 'value': '已领取3积分'},
          {'label': '支付渠道', 'value': '支付宝'},
        ],
      });

      expect(
        text,
        '订单号: 9569805267061115767991919176\n'
        '商户单号: sub2_202607260bofXWQU\n'
        '支付奖励：已领取3积分\n'
        '支付渠道：支付宝',
      );
    });
  });

  group('mergeDetailsTextParts', () {
    test('逐行规范冒号和空白并按语义去重', () {
      final merged = mergeDetailsTextParts(const [
        ' 交易单号 : OCR-123  \n补充信息： 同一条 ',
        '交易单号：OCR-123\n补充信息 : 同一条',
        '\n  无冒号   内容  ',
        '无冒号 内容',
      ]);

      expect(
        merged,
        '交易单号：OCR-123\n补充信息：同一条\n无冒号 内容',
      );
    });
  });
}
