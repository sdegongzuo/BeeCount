/// Normalizes bill recognition fields after OCR/AI extraction.
///
/// This layer keeps the final user-facing fields stable while preserving
/// rewritten raw values in `details.original_fields`.
class BillRecognitionNormalizer {
  const BillRecognitionNormalizer();

  NormalizedBillRecognition normalize(
    BillRecognitionFields fields, {
    String? detectedPaymentChannel,
  }) {
    final original = fields;
    var details = _normalizeDetails(fields.details);

    var category = _normalizeCategory(fields.category);
    var paymentMethod = _normalizePaymentMethod(fields.paymentMethod);
    var paymentChannel =
        _normalizePaymentChannel(detectedPaymentChannel ?? fields.paymentChannel);
    var counterparty = _normalizeCounterparty(fields.counterparty);
    var merchantFullName = _normalizeEntityName(fields.merchantFullName);
    var note = _normalizeNote(
      fields.note,
      counterparty: counterparty,
      paymentChannel: paymentChannel,
    );

    final counterpartyStoreName = _extractTrailingStoreName(counterparty);
    if (counterpartyStoreName != null) {
      details = _putIfAbsent(details, 'store_name', counterpartyStoreName);
      counterparty = _removeTrailingParentheses(counterparty);
    }

    final originalFields = <String, dynamic>{};
    _recordOriginal(originalFields, 'note', original.note, note);
    _recordOriginal(originalFields, 'category', original.category, category);
    _recordOriginal(
      originalFields,
      'payment_method',
      original.paymentMethod,
      paymentMethod,
    );
    _recordOriginal(
      originalFields,
      'payment_channel',
      original.paymentChannel,
      paymentChannel,
    );
    _recordOriginal(
      originalFields,
      'counterparty',
      original.counterparty,
      counterparty,
    );
    _recordOriginal(
      originalFields,
      'merchant_full_name',
      original.merchantFullName,
      merchantFullName,
    );

    if (originalFields.isNotEmpty) {
      details = {
        ...details,
        'original_fields': {
          ..._asStringKeyMap(details['original_fields']),
          ...originalFields,
        },
      };
    }

    return NormalizedBillRecognition(
      note: note,
      category: category,
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
      counterparty: counterparty,
      merchantFullName: merchantFullName,
      details: details.isEmpty ? null : details,
    );
  }

  static String? _normalizeCategory(String? value) {
    final text = _cleanText(value);
    if (text == null) return null;
    return _categoryAliases[_compact(text)] ?? text;
  }

  static String? _normalizePaymentMethod(String? value) {
    final text = _normalizeBrackets(_cleanText(value));
    if (text == null) return null;
    return text.replaceAll('[', '(').replaceAll(']', ')');
  }

  static String? _normalizePaymentChannel(String? value) {
    final text = _cleanText(value);
    if (text == null) return null;

    final compact = _compact(text);
    if (compact.contains('微信')) return '微信支付';
    if (compact.contains('支付宝')) return '支付宝';
    if (compact.contains('银联云闪付') || compact.contains('云闪付')) {
      return '云闪付';
    }
    return _paymentChannelAliases[compact] ?? text;
  }

  static String? _normalizeCounterparty(String? value) {
    final text = _normalizeEntityName(value);
    if (text == null) return null;
    return text
        .replaceAll(RegExp(r'[_＿]财付通$'), '')
        .replaceAll(RegExp(r'\(银联云闪付\)$'), '')
        .trim();
  }

  static String? _normalizeEntityName(String? value) {
    return _normalizeBrackets(_cleanText(value));
  }

  static String? _normalizeNote(
    String? value, {
    required String? counterparty,
    required String? paymentChannel,
  }) {
    final text = _normalizeBrackets(_cleanText(value));
    if (text == null) return null;

    final compact = _compact(text);
    if (compact == '拼多多购物' &&
        paymentChannel == '微信支付' &&
        counterparty == '拼多多') {
      return '拼多多';
    }
    if (compact == 'ETC通行费') return 'ETC服务';
    if (compact == '月卡会员神券包') return '月卡会员超值神券包';
    return text;
  }

  static Map<String, dynamic> _normalizeDetails(Map<String, dynamic>? value) {
    if (value == null) return {};
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || entry.value == null) continue;
      final rawValue = entry.value;
      if (rawValue is String) {
        final text = rawValue.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          result[key] = text;
        }
      } else if (rawValue is Map) {
        final nested = _asStringKeyMap(rawValue);
        if (nested.isNotEmpty) result[key] = nested;
      } else {
        result[key] = rawValue;
      }
    }
    return result;
  }

  static Map<String, dynamic> _putIfAbsent(
    Map<String, dynamic> details,
    String key,
    dynamic value,
  ) {
    if (details.containsKey(key) || value == null) return details;
    return {...details, key: value};
  }

  static void _recordOriginal(
    Map<String, dynamic> target,
    String key,
    String? before,
    String? after,
  ) {
    if (before == null || after == null) return;
    if (before.trim() == after.trim()) return;
    target[key] = before;
  }

  static String? _extractTrailingStoreName(String? value) {
    if (value == null) return null;
    final match = RegExp(r'\(([^()]*店)\)$').firstMatch(value);
    return match?.group(1)?.trim();
  }

  static String? _removeTrailingParentheses(String? value) {
    return value?.replaceFirst(RegExp(r'\([^()]+\)$'), '').trim();
  }

  static String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _normalizeBrackets(String? value) {
    return value
        ?.replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll('［', '[')
        .replaceAll('］', ']');
  }

  static String _compact(String value) {
    return _normalizeBrackets(value)!.replaceAll(RegExp(r'\s+'), '');
  }

  static Map<String, dynamic> _asStringKeyMap(dynamic value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
}

class BillRecognitionFields {
  final String? note;
  final String? category;
  final String? paymentMethod;
  final String? paymentChannel;
  final String? counterparty;
  final String? merchantFullName;
  final Map<String, dynamic>? details;

  const BillRecognitionFields({
    this.note,
    this.category,
    this.paymentMethod,
    this.paymentChannel,
    this.counterparty,
    this.merchantFullName,
    this.details,
  });
}

class NormalizedBillRecognition {
  final String? note;
  final String? category;
  final String? paymentMethod;
  final String? paymentChannel;
  final String? counterparty;
  final String? merchantFullName;
  final Map<String, dynamic>? details;

  const NormalizedBillRecognition({
    this.note,
    this.category,
    this.paymentMethod,
    this.paymentChannel,
    this.counterparty,
    this.merchantFullName,
    this.details,
  });
}

const _categoryAliases = {
  '医疗保健': '医疗',
  '醫療保健': '醫療',
};

const _paymentChannelAliases = {
  '微信': '微信支付',
  'wechatpay': '微信支付',
  'alipay': '支付宝',
  'unionpay': '云闪付',
};
