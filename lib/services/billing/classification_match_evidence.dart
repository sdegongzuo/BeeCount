/// 返回可供个人分类规则稳定识别商户的最具体文本。
///
/// OCR 直接字段优先于结构化摘要；此接口有意拒绝用户自由补充文本。
String? classificationMatchText({
  String? merchantFullName,
  String? counterparty,
  String? structuredSummary,
}) {
  for (final candidate in <String?>[
    merchantFullName,
    counterparty,
    merchantFromStructuredSummary(structuredSummary),
  ]) {
    final normalized = candidate?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

/// 只从确定性结构化摘要中提取“商户”字段。
String? merchantFromStructuredSummary(String? summary) {
  if (summary == null || summary.trim().isEmpty) return null;
  return RegExp(r'(?:^|\n)\s*商户\s*[：:]\s*([^\n]+)')
      .firstMatch(summary)
      ?.group(1)
      ?.trim();
}
