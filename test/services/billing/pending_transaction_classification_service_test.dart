import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/pending_transaction_classification_service.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repository;
  late int ledgerId;
  late int pendingId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    ledgerId = await repository.createLedger(name: '待分类测试');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.createCategory(name: '餐饮', kind: 'expense');
    pendingId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 28,
      happenedAt: DateTime.utc(2026, 7, 16),
      note: '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲',
      merchantFullName: '天津海河测试餐厅甲',
      detailsText: '补充信息：和朋友聚餐',
      needsClassification: true,
    );
    await repository.upsertBillingAttachment(
      originKey: 'billing:test',
      transactionId: pendingId,
      fileName: 'billing-test.png',
      width: 1080,
      height: 1920,
    );
  });

  tearDown(() => db.close());

  test('按账本查询待分类交易并加载分类与附件证据', () async {
    final otherLedger = await repository.createLedger(name: '另一个账本');
    await repository.addTransaction(
      ledgerId: otherLedger,
      type: 'expense',
      amount: 99,
      happenedAt: DateTime.utc(2026, 7, 14),
      needsClassification: true,
    );
    await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 7, 15),
    );

    final service = PendingTransactionClassificationService(repository);
    final pending = await service.listPending(ledgerId: ledgerId);

    expect(pending.map((item) => item.transaction.id), [pendingId]);
    final draft = await service.loadDraft(pendingId);
    expect(draft, isNotNull);
    expect(draft!.categories.map((category) => category.name),
        containsAll(<String>['其他', '餐饮']));
    expect(draft.attachments.single.fileName, 'billing-test.png');
    expect(draft.structuredSummary, '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲');
  });

  test('仅本次确认原子更新交易并登记同步 change，但不创建规则', () async {
    final category = (await repository.getAllCategories())
        .singleWhere((item) => item.name == '餐饮');
    final beforeChanges = await db.select(db.localChanges).get();
    final service = PendingTransactionClassificationService(repository);

    await service.confirmClassification(
      transactionId: pendingId,
      categoryId: category.id,
      memoryScope: ClassificationMemoryScope.currentTransaction,
    );

    final updated = await repository.getTransactionById(pendingId);
    expect(updated!.categoryId, category.id);
    expect(updated.needsClassification, isFalse);
    final afterChanges = await db.select(db.localChanges).get();
    expect(afterChanges.length, beforeChanges.length + 1);
    expect(afterChanges.last.entityType, 'transaction');
    expect(afterChanges.last.action, 'update');
    expect(
        await SqlitePersonalCategoryRuleStore(db).loadActiveRules(), isEmpty);
  });

  for (final scope in <ClassificationMemoryScope>[
    ClassificationMemoryScope.currentLedger,
    ClassificationMemoryScope.global,
  ]) {
    test('$scope 使用商户证据和稳定 category syncId 记忆规则', () async {
      final category = (await repository.getAllCategories())
          .singleWhere((item) => item.name == '餐饮');
      final service = PendingTransactionClassificationService(repository);

      await service.confirmClassification(
        transactionId: pendingId,
        categoryId: category.id,
        memoryScope: scope,
      );

      final rule =
          (await SqlitePersonalCategoryRuleStore(db).loadActiveRules()).single;
      expect(rule.matchText, '天津海河测试餐厅甲');
      expect(rule.categorySyncId, category.syncId);
      expect(rule.ledgerId,
          scope == ClassificationMemoryScope.currentLedger ? ledgerId : null);
      expect(rule.matchText, isNot(contains('和朋友聚餐')));
    });
  }

  test('规则保存失败会回滚交易补正和同步 change', () async {
    final category = (await repository.getAllCategories())
        .singleWhere((item) => item.name == '餐饮');
    final beforeChanges = await db.select(db.localChanges).get();
    final service = PendingTransactionClassificationService(
      repository,
      categoryRuleStore: _FailAfterSaveCategoryRuleStore(db),
    );

    await expectLater(
      service.confirmClassification(
        transactionId: pendingId,
        categoryId: category.id,
        memoryScope: ClassificationMemoryScope.currentLedger,
      ),
      throwsA(isA<StateError>()),
    );

    final unchanged = await repository.getTransactionById(pendingId);
    expect(unchanged!.categoryId, isNull);
    expect(unchanged.needsClassification, isTrue);
    expect(await db.select(db.localChanges).get(),
        hasLength(beforeChanges.length));
    expect(
        await SqlitePersonalCategoryRuleStore(db).loadActiveRules(), isEmpty);
  });

  test('没有商户证据时拒绝记忆规则且不使用自由补充信息', () async {
    final noEvidenceId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 18,
      happenedAt: DateTime.utc(2026, 7, 17),
      note: '商品：海河测试饮品甲',
      detailsText: '补充信息：天津海河测试餐厅甲',
      needsClassification: true,
    );
    final category = (await repository.getAllCategories())
        .singleWhere((item) => item.name == '餐饮');

    await expectLater(
      PendingTransactionClassificationService(repository).confirmClassification(
        transactionId: noEvidenceId,
        categoryId: category.id,
        memoryScope: ClassificationMemoryScope.currentLedger,
      ),
      throwsA(isA<StateError>()),
    );

    expect(
        (await repository.getTransactionById(noEvidenceId))!
            .needsClassification,
        isTrue);
    expect(
        await SqlitePersonalCategoryRuleStore(db).loadActiveRules(), isEmpty);
  });

  test('拒绝交易类型不匹配的分类', () async {
    final incomeCategoryId =
        await repository.createCategory(name: '工资', kind: 'income');

    await expectLater(
      PendingTransactionClassificationService(repository).confirmClassification(
        transactionId: pendingId,
        categoryId: incomeCategoryId,
        memoryScope: ClassificationMemoryScope.currentTransaction,
      ),
      throwsA(isA<StateError>()),
    );

    expect(
        (await repository.getTransactionById(pendingId))!.needsClassification,
        isTrue);
  });

  test('记忆规则时拒绝没有稳定 syncId 的分类', () async {
    final category = (await repository.getAllCategories())
        .singleWhere((item) => item.name == '餐饮');
    await (db.update(db.categories)
          ..where((item) => item.id.equals(category.id)))
        .write(const CategoriesCompanion(syncId: d.Value(null)));

    await expectLater(
      PendingTransactionClassificationService(repository).confirmClassification(
        transactionId: pendingId,
        categoryId: category.id,
        memoryScope: ClassificationMemoryScope.global,
      ),
      throwsA(isA<StateError>()),
    );

    expect(
        (await repository.getTransactionById(pendingId))!.needsClassification,
        isTrue);
  });
}

class _FailAfterSaveCategoryRuleStore extends SqlitePersonalCategoryRuleStore {
  const _FailAfterSaveCategoryRuleStore(super.db);

  @override
  Future<void> remember({
    required String matchText,
    required String categorySyncId,
    required int? ledgerId,
  }) async {
    await super.remember(
      matchText: matchText,
      categorySyncId: categorySyncId,
      ledgerId: ledgerId,
    );
    throw StateError('injected_rule_write_failure');
  }
}
