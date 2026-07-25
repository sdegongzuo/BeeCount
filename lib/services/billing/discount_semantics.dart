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
  static final RegExp _campaignNegativeAmountPattern = RegExp(
    r'(?:优惠|立减|减免|已减|节省|省)'
    r'[\s:：]*[\-−－—]\s*'
    r'(?:[¥￥]\s*)?(\d+(?:\.\d{1,2})?)\s*(?:元)?',
  );
  static final RegExp _moneyPattern = RegExp(
    r'(?:[¥￥]\s*\d+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?\s*元)',
  );
  static final RegExp _labeledNegativeAmountPattern = RegExp(
    r'^[\-−－—]\s*(?:[¥￥]\s*)?(\d+(?:\.\d{1,2})?)\s*(?:元)?$',
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
    final hasConditionalUpperBound =
        RegExp(r'(?:最高|至高|最多|可省).*(?:优惠|立减|减免|节省|省|减)').hasMatch(normalized);
    final hasRealizedAmountAfterUpperBound = RegExp(
      r'(?:最高|至高|最多|可省).*\d+(?:\.\d+)?\s*元'
      r'.*(?:优惠|立减|减免|已减|节省|省)[\s:：\-−－—]*'
      r'(?:[¥￥]\s*\d|\d+(?:\.\d+)?\s*元|[\-−－—]\s*(?:[¥￥]\s*)?\d)',
    ).hasMatch(normalized);
    if (hasConditionalUpperBound && !hasRealizedAmountAfterUpperBound) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final labeledNegativeAmount =
        _labeledNegativeAmountPattern.firstMatch(normalized);
    if (labeledNegativeAmount != null) {
      final parsed = double.tryParse(labeledNegativeAmount.group(1)!);
      if (parsed != null && parsed.isFinite && parsed > 0) {
        return DiscountParseResult(
          displayText: '优惠（¥${parsed.toStringAsFixed(2)}）',
          amount: parsed,
        );
      }
    }

    final campaignNegative =
        _campaignNegativeAmountPattern.firstMatch(normalized);
    final match =
        campaignNegative ?? _realizedDiscountPattern.firstMatch(normalized);
    if (match == null) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final parsed = double.tryParse(
      match.group(1) ?? match.group(2) ?? '',
    );
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return DiscountParseResult(displayText: normalized, amount: null);
    }

    final moneyMatch = _moneyPattern.firstMatch(match.group(0)!);
    final amountStart = moneyMatch?.start ??
        match.group(0)!.lastIndexOf(match.group(1) ?? match.group(2)!);
    final amountEnd = moneyMatch?.end ?? match.group(0)!.length;
    var description = normalized
        .replaceRange(
          match.start + amountStart,
          match.start + amountEnd,
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
