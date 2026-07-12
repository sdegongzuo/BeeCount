import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/category_repository.dart';
import 'package:beecount/data/repositories/local/local_category_repository.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalCategoryRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalCategoryRepository(db);
  });

  tearDown(() => db.close());

  test('拒绝删除被全部领域对象引用的分类', () async {
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '账本'),
        );
    final sourceId = await repo.createCategory(name: '旧分类', kind: 'expense');
    final source = await repo.getCategoryById(sourceId);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1,
          categoryId: Value(sourceId),
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          amount: 10,
          categoryId: Value(sourceId),
        ));
    await db.into(db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 2,
            categoryId: Value(sourceId),
            frequency: 'monthly',
            startDate: DateTime(2026),
          ),
        );
    await SqlitePersonalCategoryRuleStore(db).remember(
      matchText: '咖啡',
      categorySyncId: source!.syncId!,
      ledgerId: ledgerId,
    );

    await expectLater(
      repo.deleteCategory(sourceId),
      throwsA(isA<CategoryReferencedException>()),
    );
    expect(await repo.getCategoryById(sourceId), isNotNull);
  });

  test('一级分类删除检查覆盖子分类及其引用', () async {
    final parentId = await repo.createCategory(name: '父', kind: 'expense');
    await repo.createSubCategory(
        parentId: parentId, name: '子', kind: 'expense');

    await expectLater(
      repo.deleteCategory(parentId),
      throwsA(isA<CategoryReferencedException>()),
    );
  });

  test('预览并在同一事务迁移全部引用后删除旧分类', () async {
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '账本'),
        );
    final sourceId = await repo.createCategory(name: '旧', kind: 'expense');
    final targetId = await repo.createCategory(name: '新', kind: 'expense');
    final childId = await repo.createSubCategory(
      parentId: sourceId,
      name: '子',
      kind: 'expense',
    );
    final source = await repo.getCategoryById(sourceId);
    final target = await repo.getCategoryById(targetId);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1,
          categoryId: Value(sourceId),
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          amount: 10,
          categoryId: Value(sourceId),
        ));
    await db.into(db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 2,
            categoryId: Value(sourceId),
            frequency: 'monthly',
            startDate: DateTime(2026),
          ),
        );
    final rules = SqlitePersonalCategoryRuleStore(db);
    await rules.remember(
      matchText: '咖啡',
      categorySyncId: source!.syncId!,
      ledgerId: ledgerId,
    );

    final preview = await repo.getCategoryMigrationPreview(
      fromCategoryId: sourceId,
      toCategoryId: targetId,
    );
    expect(preview.transactionCount, 1);
    expect(preview.budgetCount, 1);
    expect(preview.recurringTransactionCount, 1);
    expect(preview.subCategoryCount, 1);
    expect(preview.personalCategoryRuleCount, 1);

    await repo.migrateCategory(
        fromCategoryId: sourceId, toCategoryId: targetId);

    expect(await repo.getCategoryById(sourceId), isNull);
    expect((await repo.getCategoryById(childId))!.parentId, targetId);
    expect(
        (await db.select(db.transactions).get()).single.categoryId, targetId);
    expect((await db.select(db.budgets).get()).single.categoryId, targetId);
    expect((await db.select(db.recurringTransactions).get()).single.categoryId,
        targetId);
    expect(
        (await rules.loadActiveRules()).single.categorySyncId, target!.syncId);
  });

  test('迁移任一步失败时全部回滚', () async {
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '账本'),
        );
    final sourceId = await repo.createCategory(name: '旧', kind: 'expense');
    final targetId = await repo.createCategory(name: '新', kind: 'expense');
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1,
          categoryId: Value(sourceId),
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          amount: 10,
          categoryId: Value(sourceId),
        ));
    await db.customStatement('''
      CREATE TRIGGER fail_category_budget_migration
      BEFORE UPDATE OF category_id ON budgets
      BEGIN SELECT RAISE(ABORT, 'forced migration failure'); END
    ''');

    await expectLater(
      repo.migrateCategory(fromCategoryId: sourceId, toCategoryId: targetId),
      throwsA(anything),
    );
    expect(await repo.getCategoryById(sourceId), isNotNull);
    expect(
        (await db.select(db.transactions).get()).single.categoryId, sourceId);
    expect((await db.select(db.budgets).get()).single.categoryId, sourceId);
  });

  test('零引用分类可以直接删除', () async {
    final id = await repo.createCategory(name: '空分类', kind: 'expense');
    await repo.deleteCategory(id);
    expect(await repo.getCategoryById(id), isNull);
  });
}
