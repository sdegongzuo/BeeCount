/// Returns the most specific stable text that can identify a merchant for a
/// personal category rule.
///
/// Direct OCR fields win over the structured summary. User-authored
/// supplemental notes are intentionally not accepted by this API.
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

/// Extracts only the `商户` field from a deterministic structured summary.
String? merchantFromStructuredSummary(String? summary) {
  if (summary == null || summary.trim().isEmpty) return null;
  return RegExp(r'(?:^|\n)\s*商户\s*[：:]\s*([^\n]+)')
      .firstMatch(summary)
      ?.group(1)
      ?.trim();
}
