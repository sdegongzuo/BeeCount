import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/deterministic_bill_enrichment.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('确认分类可按当前账本或全局记住并在重启后用于相似账单', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '测试账本'),
        );
    final store = SqlitePersonalCategoryRuleStore(db);
    await store.remember(
      matchText: '天津海河测试餐厅甲',
      categorySyncId: 'category-food-sync',
      ledgerId: ledgerId,
    );
    await store.remember(
      matchText: '滴滴',
      categorySyncId: 'category-travel-sync',
      ledgerId: null,
    );

    final rules = await SqlitePersonalCategoryRuleStore(db).loadActiveRules();
    expect(rules, hasLength(2));
    expect(
      rules.singleWhere((rule) => rule.matchText == '天津海河测试餐厅甲').ledgerId,
      ledgerId,
    );
    expect(
      rules.singleWhere((rule) => rule.matchText == '滴滴').ledgerId,
      isNull,
    );
    expect(rules.map((rule) => rule.categorySyncId),
        containsAll(['category-food-sync', 'category-travel-sync']));
    final futureBill =
        DeterministicBillClassifier(personalRules: rules).classify(
      ledgerId: ledgerId,
      merchant: '天津海河测试餐厅甲天津和平测试门店甲',
      searchableText: '天津海河测试餐厅甲 支付成功',
      fallbackCategorySyncId: 'category-other-sync',
      categories: const [
        BillCategoryRef(
          localId: 3,
          syncId: 'category-food-sync',
          name: '餐饮',
        ),
        BillCategoryRef(
          localId: 9,
          syncId: 'category-other-sync',
          name: '其他',
        ),
      ],
    );
    expect(futureBill.category.localId, 3);
    expect(futureBill.source, BillCategorySource.personalRule);
  });
}
