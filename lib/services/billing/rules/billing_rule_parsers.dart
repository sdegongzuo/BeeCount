class BillingRuleParserTypes {
  static const amount = 'amount';
  static const signedAmount = 'signedAmount';
  static const zhDatetime = 'zhDatetime';
  static const isoDatetime = 'isoDatetime';
  static const institutionName = 'institutionName';
  static const paymentMethod = 'paymentMethod';
  static const regexGroup = 'regexGroup';
  static const raw = 'raw';
  static const string = 'string';
}

class BillingRuleParseResult {
  final Object? value;
  final double confidence;
  final String? error;

  const BillingRuleParseResult({
    required this.value,
    this.confidence = 1,
    this.error,
  });

  bool get success => error == null;
}

class BillingRuleParsers {
  static BillingRuleParseResult parse(
    String? parser,
    String input, {
    String? pattern,
    Map<String, dynamic> options = const {},
  }) {
    final parserType = parser ?? BillingRuleParserTypes.raw;
    switch (parserType) {
      case BillingRuleParserTypes.amount:
      case BillingRuleParserTypes.signedAmount:
        return _parseAmount(input);
      case BillingRuleParserTypes.zhDatetime:
        return _parseZhDatetime(input);
      case BillingRuleParserTypes.isoDatetime:
        return _parseIsoDatetime(input);
      case BillingRuleParserTypes.institutionName:
        return BillingRuleParseResult(value: _normalizeInstitutionName(input));
      case BillingRuleParserTypes.paymentMethod:
        return BillingRuleParseResult(value: _normalizePaymentMethod(input));
      case BillingRuleParserTypes.regexGroup:
        return _parseRegexGroup(input, pattern: pattern, options: options);
      case BillingRuleParserTypes.raw:
      case BillingRuleParserTypes.string:
        return BillingRuleParseResult(value: input.trim());
      default:
        return BillingRuleParseResult(
          value: input.trim(),
          confidence: 0.6,
          error: 'Unsupported parser: $parserType',
        );
    }
  }

  static BillingRuleParseResult _parseAmount(String input) {
    final normalized = input
        .replaceAll(RegExp(r'[¥￥元,\s]'), '')
        .replaceAll('－', '-')
        .replaceAll('−', '-');
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(normalized);
    if (match == null) {
      return BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'Amount not found',
      );
    }
    final value = double.tryParse(match.group(0)!);
    if (value == null) {
      return BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'Invalid amount',
      );
    }
    return BillingRuleParseResult(value: value);
  }

  static BillingRuleParseResult _parseZhDatetime(String input) {
    final match = RegExp(
      r'(\d{4})年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*'
      r'(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?',
    ).firstMatch(input.trim());
    if (match == null) {
      return BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'Chinese datetime not found',
      );
    }
    return BillingRuleParseResult(
      value: DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6) ?? '0'),
      ),
    );
  }

  static BillingRuleParseResult _parseIsoDatetime(String input) {
    final value = DateTime.tryParse(input.trim());
    if (value == null) {
      return BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'ISO datetime not found',
      );
    }
    return BillingRuleParseResult(value: value);
  }

  static BillingRuleParseResult _parseRegexGroup(
    String input, {
    String? pattern,
    Map<String, dynamic> options = const {},
  }) {
    final regexPattern = pattern ?? options['pattern'] as String?;
    if (regexPattern == null || regexPattern.isEmpty) {
      return const BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'Regex pattern is required',
      );
    }
    final groupIndex = _intOption(options['groupIndex']) ?? 1;
    final match = RegExp(regexPattern, multiLine: true).firstMatch(input);
    if (match == null || groupIndex > match.groupCount) {
      return const BillingRuleParseResult(
        value: null,
        confidence: 0,
        error: 'Regex group not found',
      );
    }
    return BillingRuleParseResult(value: match.group(groupIndex)?.trim());
  }
}

String _normalizeInstitutionName(String input) {
  return input.trim().replaceAll('料技', '科技').replaceAll('適', '通');
}

String _normalizePaymentMethod(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'[>〉]+$'), '')
      .trim()
      .replaceAllMapped(RegExp(r'\[(\d{3,6})\]'), (match) {
    return '(${match.group(1)})';
  });
}

int? _intOption(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
