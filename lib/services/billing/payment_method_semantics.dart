enum PaymentMethodNormalizationStatus {
  empty,
  unchanged,
  normalized,
  rejected,
}

class PaymentMethodNormalizationResult {
  final PaymentMethodNormalizationStatus status;
  final String? value;
  final String? reason;

  const PaymentMethodNormalizationResult._(
    this.status,
    this.value, [
    this.reason,
  ]);

  const PaymentMethodNormalizationResult.empty()
      : this._(PaymentMethodNormalizationStatus.empty, null);

  const PaymentMethodNormalizationResult.unchanged(String value)
      : this._(PaymentMethodNormalizationStatus.unchanged, value);

  const PaymentMethodNormalizationResult.normalized(String value)
      : this._(PaymentMethodNormalizationStatus.normalized, value);

  const PaymentMethodNormalizationResult.rejected(String reason)
      : this._(PaymentMethodNormalizationStatus.rejected, null, reason);

  bool get isRejected => status == PaymentMethodNormalizationStatus.rejected;
}

/// 支付方式唯一业务语义入口。
///
/// canonical value 用于持久化、详情展示、比较和规则回归；
/// [formatForHome] 的简称只允许用于主页展示。
class PaymentMethodSemantics {
  const PaymentMethodSemantics();

  static final RegExp _controlCharacters =
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  static final RegExp _labelOnly = RegExp(r'^(?:支付方式|付款方式|卡号|银行卡|支付账户)[:：]?$');
  static final RegExp _trailingArrow = RegExp(r'\s*[>〉＞]+\s*$');
  static final RegExp _tailBrackets =
      RegExp(r'\s*[\[【（(]\s*(\d{3,6})\s*[\]】）)]\s*$');
  static final RegExp _cardNetworkModifier =
      RegExp(r'(?<=银行)\s*银联\s*(?=(?:信用卡|借记卡|贷记卡|准贷记卡))');
  static final RegExp _cardStructure =
      RegExp(r'银行\s*(?:银联\s*)?(?:信用卡|借记卡|贷记卡|准贷记卡)');
  static final RegExp _spaces = RegExp(r'\s+');

  static const Map<String, String> _homeBankAliases = {
    '中国邮政储蓄银行': '邮储',
    '邮储银行': '邮储',
    '中国建设银行': '建行',
    '建设银行': '建行',
    '中国工商银行': '工行',
    '工商银行': '工行',
    '中国农业银行': '农行',
    '农业银行': '农行',
    '中国银行': '中行',
    '交通银行': '交行',
    '招商银行': '招行',
    '平安银行': '平安',
    '浦发银行': '浦发',
    '兴业银行': '兴业',
    '中信银行': '中信',
    '光大银行': '光大',
    '民生银行': '民生',
    '广发银行': '广发',
    '华夏银行': '华夏',
  };

  PaymentMethodNormalizationResult canonicalize(String? input) {
    final trimmed = input?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return const PaymentMethodNormalizationResult.empty();
    }
    if (trimmed.contains('\n') ||
        trimmed.contains('\r') ||
        _controlCharacters.hasMatch(trimmed)) {
      return const PaymentMethodNormalizationResult.rejected(
        'payment method must be a single printable line',
      );
    }
    if (trimmed.length > 128) {
      return const PaymentMethodNormalizationResult.rejected(
        'payment method is too long',
      );
    }
    if (_labelOnly.hasMatch(trimmed)) {
      return const PaymentMethodNormalizationResult.rejected(
        'payment method contains only a label',
      );
    }

    var value = trimmed
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll('［', '[')
        .replaceAll('］', ']');
    value = value.replaceFirst(_trailingArrow, '');
    value = value.replaceFirstMapped(
      _tailBrackets,
      (match) => '(${match.group(1)})',
    );
    if (_cardStructure.hasMatch(value)) {
      value = value.replaceAll(_cardNetworkModifier, '');
      value = value.replaceAll(_spaces, '');
    }

    if (value.isEmpty) {
      return const PaymentMethodNormalizationResult.rejected(
        'payment method is empty after normalization',
      );
    }
    return value == trimmed
        ? PaymentMethodNormalizationResult.unchanged(value)
        : PaymentMethodNormalizationResult.normalized(value);
  }

  String? formatForHome(String? canonicalValue) {
    if (canonicalValue == null || canonicalValue.isEmpty) return null;
    for (final entry in _homeBankAliases.entries) {
      if (canonicalValue.contains(entry.key)) {
        return canonicalValue.replaceFirst(entry.key, entry.value);
      }
    }
    return canonicalValue;
  }
}
