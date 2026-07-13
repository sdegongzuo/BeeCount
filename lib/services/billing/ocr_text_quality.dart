bool isUsableRapidOcrText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) return false;

  final hasAmount = RegExp(r'[¥￥]?-?\d+(?:[.,]\d{1,2})').hasMatch(normalized);
  if (hasAmount) return true;

  const paymentTerms = [
    '交易',
    '支付',
    '账单',
    '金额',
    '收款',
    '付款',
    '商户',
    '商家',
    '订单',
    '时间',
    '消费',
  ];
  final matchedTerms = paymentTerms.where(normalized.contains).length;
  return matchedTerms >= 2;
}
