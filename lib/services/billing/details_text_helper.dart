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
    final value = entry.value;
    if (value == null) continue;

    if (value is Map) {
      if (value.isEmpty) continue;
      final inner = value.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      if (inner.isNotEmpty) {
        lines.add('$key: $inner');
      }
    } else if (value is List) {
      if (value.isEmpty) continue;
      lines.add('$key: ${value.join(', ')}');
    } else {
      lines.add('$key: $value');
    }
  }

  return lines.isEmpty ? null : lines.join('\n');
}
