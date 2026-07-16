import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/data/seed_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认分类首次创建即拥有稳定 syncId，支持立即记住个人分类规则', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await SeedService.seedDatabase(
      db,
      lookupAppLocalizations(const Locale('zh')),
    );

    final categories = await db.select(db.categories).get();
    expect(categories, isNotEmpty);
    expect(categories.where((category) => category.name == '其他'), hasLength(1));
    expect(
      categories.where((category) => category.name == '其他收入'),
      hasLength(1),
    );
    expect(
      categories,
      everyElement(
        predicate<Category>(
          (category) => category.syncId?.trim().isNotEmpty == true,
          '分类 syncId 非空',
        ),
      ),
    );
    expect(
      categories.map((category) => category.syncId).toSet(),
      hasLength(categories.length),
    );
    expect(
      categories.singleWhere((category) => category.name == '其他').syncId,
      SeedService.categorySyncId('expense', 'other'),
    );
    expect(
      categories.singleWhere((category) => category.name == '其他收入').syncId,
      SeedService.categorySyncId('income', 'other'),
    );
    final expenseFallback =
        categories.singleWhere((category) => category.name == '其他');
    await SqlitePersonalCategoryRuleStore(db).remember(
      matchText: '新商户',
      categorySyncId: expenseFallback.syncId!,
      ledgerId: 1,
    );
    final remembered =
        await SqlitePersonalCategoryRuleStore(db).loadActiveRules();
    expect(remembered.single.categorySyncId, expenseFallback.syncId);
  });

  test('英文默认分类显式创建本地化的支出与收入兜底', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await SeedService.seedDatabase(
      db,
      lookupAppLocalizations(const Locale('en')),
    );

    final categories = await db.select(db.categories).get();
    expect(
      categories.where((category) => category.name == 'Other'),
      hasLength(1),
    );
    expect(
      categories.where((category) => category.name == 'Other income'),
      hasLength(1),
    );
  });
}
