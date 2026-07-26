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
    if (key == 'additional_fields') {
      if (value is List) {
        for (final item in value) {
          if (item is! Map) continue;
          final itemLabel = item['label']?.toString().trim() ?? '';
          final itemValue = item['value']?.toString().trim() ?? '';
          if (itemLabel.isEmpty || itemValue.isEmpty) continue;
          lines.add('$itemLabel：$itemValue');
        }
      }
      continue;
    }
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

/// 合并多个明细文本来源，并按“行”的语义去重。
///
/// 全角/半角冒号以及冒号两侧、行内连续空白会统一，输出保留首次出现顺序。
String? mergeDetailsTextParts(Iterable<String?> parts) {
  final lines = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    if (part == null || part.trim().isEmpty) continue;
    for (final rawLine in part.split(RegExp(r'\r?\n'))) {
      final line = _normalizeDetailLine(rawLine);
      if (line == null || !seen.add(line)) continue;
      lines.add(line);
    }
  }
  return lines.isEmpty ? null : lines.join('\n');
}

String? _normalizeDetailLine(String rawLine) {
  final trimmed = rawLine.trim();
  if (trimmed.isEmpty) return null;
  final separator = RegExp(r'[：:]').firstMatch(trimmed);
  if (separator == null) return _collapseWhitespace(trimmed);
  final key = _collapseWhitespace(trimmed.substring(0, separator.start));
  final value = _collapseWhitespace(trimmed.substring(separator.end));
  if (key.isEmpty || value.startsWith('//')) {
    return _collapseWhitespace(trimmed);
  }
  return value.isEmpty ? '$key：' : '$key：$value';
}

String _collapseWhitespace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

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
  'supplemental_note': '补充信息',
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
