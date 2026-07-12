import 'package:beecount/services/billing/deterministic_bill_enrichment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const categories = [
    BillCategoryRef(localId: 1, syncId: 'food-sync', name: '餐饮'),
    BillCategoryRef(localId: 2, syncId: 'travel-sync', name: '交通'),
    BillCategoryRef(localId: 9, syncId: 'other-sync', name: '其他'),
  ];

  test('分类严格按个人、页面、商户、关键词、其他的顺序决定', () {
    final classifier = DeterministicBillClassifier(
      personalRules: const [
        PersonalCategoryRule(
          matchText: '天津海河测试餐厅甲',
          categorySyncId: 'travel-sync',
          ledgerId: 7,
        ),
      ],
      merchantDictionary: const {'天津海河测试餐厅甲': 'food-sync'},
      keywordRules: const {'咖啡': 'food-sync'},
    );

    final personal = classifier.classify(
      ledgerId: 7,
      merchant: '天津海河测试餐厅甲',
      searchableText: '天津海河测试餐厅甲 咖啡',
      pageCategorySyncId: 'food-sync',
      categories: categories,
    );
    expect(personal.category.localId, 2);
    expect(personal.source, BillCategorySource.personalRule);

    final page = classifier.classify(
      ledgerId: 8,
      merchant: '未知商户',
      searchableText: '咖啡',
      pageCategorySyncId: 'travel-sync',
      categories: categories,
    );
    expect(page.category.localId, 2);
    expect(page.source, BillCategorySource.pageRule);
  });

  test('账本规则优先于全局规则且目标使用稳定同步标识', () {
    final classifier = DeterministicBillClassifier(personalRules: const [
      PersonalCategoryRule(
        matchText: '滴滴',
        categorySyncId: 'food-sync',
      ),
      PersonalCategoryRule(
        matchText: '滴滴',
        categorySyncId: 'travel-sync',
        ledgerId: 3,
      ),
    ]);

    expect(
      classifier
          .classify(
            ledgerId: 3,
            merchant: '滴滴出行',
            searchableText: '滴滴出行',
            categories: categories,
          )
          .category
          .localId,
      2,
    );
    expect(
      classifier
          .classify(
            ledgerId: 4,
            merchant: '滴滴出行',
            searchableText: '滴滴出行',
            categories: categories,
          )
          .category
          .localId,
      1,
    );
  });

  test('无法可靠分类时使用其他并标记待分类', () {
    final result = const DeterministicBillClassifier().classify(
      ledgerId: 1,
      merchant: '未知',
      searchableText: '没有命中',
      categories: categories,
    );
    expect(result.category.localId, 9);
    expect(result.needsClassification, isTrue);
    expect(result.source, BillCategorySource.fallback);
  });

  test('结构化摘要只包含图片可验证字段且格式稳定', () {
    final summary = buildStructuredBillSummary(
      merchant: ' 天津海河测试餐厅甲 ',
      productSummary: '海河测试饮品甲',
      storeName: '天津和平测试门店甲',
      routeStart: null,
      routeEnd: null,
    );
    expect(summary, '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲\n门店：天津和平测试门店甲');
  });
}
