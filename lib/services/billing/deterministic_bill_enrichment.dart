enum BillCategorySource {
  personalRule,
  pageRule,
  merchantDictionary,
  keywordRule,
  fallback,
}

class BillCategoryRef {
  final int localId;
  final String? syncId;
  final String name;

  const BillCategoryRef({
    required this.localId,
    required this.syncId,
    required this.name,
  });
}

class PersonalCategoryRule {
  final String matchText;
  final String categorySyncId;
  final int? ledgerId;

  const PersonalCategoryRule({
    required this.matchText,
    required this.categorySyncId,
    this.ledgerId,
  });
}

class DeterministicCategoryResult {
  final BillCategoryRef category;
  final BillCategorySource source;
  final bool needsClassification;

  const DeterministicCategoryResult({
    required this.category,
    required this.source,
    required this.needsClassification,
  });
}

/// 图片分享记账的确定性分类边界。
///
/// 个人规则的目标只保存跨设备稳定的分类 syncId，本机 ID 仅在本次匹配时解析。
class DeterministicBillClassifier {
  final List<PersonalCategoryRule> personalRules;
  final Map<String, String> merchantDictionary;
  final Map<String, String> keywordRules;

  const DeterministicBillClassifier({
    this.personalRules = const [],
    this.merchantDictionary = const {},
    this.keywordRules = const {},
  });

  DeterministicCategoryResult classify({
    required int ledgerId,
    required String? merchant,
    required String searchableText,
    String? pageCategorySyncId,
    required String fallbackCategorySyncId,
    required List<BillCategoryRef> categories,
  }) {
    // 个人规则只能消费调用方已经确认过来源的商户证据；全文仅供后续
    // 公共关键词规则使用，避免备注或 OCR 中的次要文字改变个人分类。
    final personalText = (merchant ?? '').toLowerCase();
    final scopedRules = personalRules
        .where((rule) =>
            (rule.ledgerId == ledgerId || rule.ledgerId == null) &&
            personalText.contains(rule.matchText.toLowerCase()))
        .toList()
      ..sort((a, b) {
        final scope =
            (b.ledgerId != null ? 1 : 0).compareTo(a.ledgerId != null ? 1 : 0);
        return scope != 0
            ? scope
            : b.matchText.length.compareTo(a.matchText.length);
      });
    for (final rule in scopedRules) {
      final category = _bySyncId(categories, rule.categorySyncId);
      if (category != null) {
        return _matched(category, BillCategorySource.personalRule);
      }
    }

    final page = _bySyncId(categories, pageCategorySyncId);
    if (page != null) return _matched(page, BillCategorySource.pageRule);

    final merchantMatch =
        _firstMappedMatch(merchant ?? '', merchantDictionary, categories);
    if (merchantMatch != null) {
      return _matched(merchantMatch, BillCategorySource.merchantDictionary);
    }
    final keywordMatch =
        _firstMappedMatch(searchableText, keywordRules, categories);
    if (keywordMatch != null) {
      return _matched(keywordMatch, BillCategorySource.keywordRule);
    }

    final fallback = _bySyncId(categories, fallbackCategorySyncId);
    if (fallback == null) throw StateError('other_category_not_found');
    return DeterministicCategoryResult(
      category: fallback,
      source: BillCategorySource.fallback,
      needsClassification: true,
    );
  }

  BillCategoryRef? _firstMappedMatch(
    String text,
    Map<String, String> rules,
    List<BillCategoryRef> categories,
  ) {
    final normalized = text.toLowerCase();
    final matches = rules.entries
        .where((entry) => normalized.contains(entry.key.toLowerCase()))
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final match in matches) {
      final category = _bySyncId(categories, match.value);
      if (category != null) return category;
    }
    return null;
  }
}

DeterministicCategoryResult _matched(
        BillCategoryRef category, BillCategorySource source) =>
    DeterministicCategoryResult(
      category: category,
      source: source,
      needsClassification: false,
    );

BillCategoryRef? _bySyncId(List<BillCategoryRef> categories, String? syncId) {
  if (syncId == null || syncId.isEmpty) return null;
  for (final category in categories) {
    if (category.syncId == syncId) return category;
  }
  return null;
}

String? buildStructuredBillSummary({
  String? merchant,
  String? productSummary,
  String? storeName,
  String? routeStart,
  String? routeEnd,
  bool labelMerchant = true,
}) {
  final fields = <(String, String?)>[
    (labelMerchant ? '商户' : '', merchant),
    ('商品', productSummary),
    ('门店', storeName),
    ('出发站', routeStart),
    ('到达站', routeEnd),
  ];
  final lines = fields
      .where((field) => field.$2 != null && field.$2!.trim().isNotEmpty)
      .map((field) => field.$1.isEmpty
          ? field.$2!.trim()
          : '${field.$1}：${field.$2!.trim()}')
      .toList();
  return lines.isEmpty ? null : lines.join('\n');
}
