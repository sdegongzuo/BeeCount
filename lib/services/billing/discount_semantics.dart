class DiscountParseResult {
  final String? displayText;
  final double? amount;

  const DiscountParseResult({
    required this.displayText,
    required this.amount,
  });
}

/// 优惠信息的唯一业务语义入口。
///
/// [displayText] 用于交易详情，[amount] 始终是“节省金额”的正数，
/// 专用于统计；无法安全识别金额时仍保留原文，但不产生统计值。
class DiscountSemantics {
  const DiscountSemantics();

  static final RegExp _realizedDiscountPattern = RegExp(
    r'(?:优惠|立减|减免|已减|节省|省)'
    r'[\s\-−－—:：]*'
    r'(?:[¥￥]\s*(\d+(?:\.\d{1,2})?)|(\d+(?:\.\d{1,2})?)\s*元)',
  );
  static final RegExp _moneyPattern = RegExp(
    r'(?:[¥￥]\s*\d+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?\s*元)',
  );
  static final RegExp _trailingSeparator = RegExp(r'[\s\-−－—:：]+$');
  static final RegExp _spaces = RegExp(r'\s+');

  DiscountParseResult parse(String? input) {
    final original = input?.trim();
    if (original == null || original.isEmpty) {
      return const DiscountParseResult(displayText: null, amount: null);
    }

    final normalized = original.replaceAll(_spaces, ' ');
    if (normalized.contains('优惠券') ||
        RegExp(r'满\s*\d+(?:\.\d+)?\s*元?\s*(?:减|优惠)').hasMatch(normalized)) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final match = _realizedDiscountPattern.firstMatch(normalized);
    if (match == null) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final parsed = double.tryParse(match.group(1) ?? match.group(2) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final moneyMatch = _moneyPattern.firstMatch(match.group(0)!);
    if (moneyMatch == null) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }
    var description = normalized
        .replaceRange(
          match.start + moneyMatch.start,
          match.start + moneyMatch.end,
          '',
        )
        .trim();
    description = description.replaceFirst(_trailingSeparator, '').trim();
    if (description.isEmpty) description = '优惠';

    return DiscountParseResult(
      displayText: '$description（¥${parsed.toStringAsFixed(2)}）',
      amount: parsed.abs(),
    );
  }
}
