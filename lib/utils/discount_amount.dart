double? normalizeDiscountAmount(num? value) {
  final amount = value?.toDouble();
  if (amount == null || !amount.isFinite || amount <= 0) return null;
  return amount;
}
