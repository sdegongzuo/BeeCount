/// 将 details Map 转换为可存储的行文本。
///
/// 规则：
/// - 简单键值：每行 'key: value'
/// - List：逗号拼接
/// - 嵌套 Map：压平成一行 'key: child=value, child2=value2'
/// - 空 Map 返回 null
String? detailsMapToText(Map<String, dynamic>? details) {
  if (details == null || details.isEmpty) return null;

  final lines = <String>[];
  for (final entry in details.entries) {
    final key = entry.key;
    if (_isInternalDetailKey(key)) continue;
    final value = entry.value;
    if (value == null) continue;
    final label = _detailLabel(key);

    if (value is Map) {
      if (value.isEmpty) continue;
      final inner = value.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      if (inner.isNotEmpty) {
        lines.add('$label: $inner');
      }
    } else if (value is List) {
      if (value.isEmpty) continue;
      lines.add('$label: ${value.join(', ')}');
    } else {
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      lines.add('$label: $text');
    }
  }

  return lines.isEmpty ? null : lines.join('\n');
}

bool _isInternalDetailKey(String key) {
  return key == 'remaining_text' ||
      key == 'ocr_payment_channel' ||
      key == 'ai_details_text' ||
      key.startsWith('screenshot_source_') ||
      key.startsWith('billing_rule_') ||
      key.startsWith('ai_enhance_') ||
      key.startsWith('ai_rule_') ||
      key.startsWith('ai_conflict_');
}

String _detailLabel(String key) {
  return _detailLabels[key] ?? key;
}

const _detailLabels = {
  'route_start': '出发站',
  'route_end': '到达站',
  'trip_time_range': '通行时间',
  'transaction_no': '交易单号',
  'merchant_order_no': '商户单号',
  'order_no': '订单号',
  'order_amount': '订单金额',
  'discount': '优惠',
  'product_summary': '商品摘要',
  'store_name': '门店',
  'transaction_channel': '交易渠道',
  'transaction_type': '交易类型',
  'bill_category': '账单分类',
  'issuer': '发卡机构',
  'merchant_no': '商户编号',
  'terminal_no': '终端编号',
  'batch_no': '批次号',
  'voucher_no': '凭证号',
  'auth_no': '授权号',
  'reference_no': '参考号',
};
