import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/base_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/billing/pending_transaction_classification_page.dart';
import 'package:beecount/pages/category/category_manage_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/billing/pending_transaction_classification_service.dart';
import 'package:beecount/widgets/biz/category_selector_dialog.dart';
import 'package:beecount/widgets/category_icon.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp(Widget home, {BaseRepository? repository}) => ProviderScope(
      overrides: [
        if (repository != null)
          repositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: home,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh')],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('展示账单证据并由用户通过分类选择器对话框选择分类和记忆范围', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    final categoryId =
        await repository.createCategory(name: '餐饮', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 28.5,
      happenedAt: DateTime(2026, 7, 16, 12, 30),
      note: '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲',
      merchantFullName: '天津海河测试餐厅甲',
      needsClassification: true,
    );
    await repository.upsertBillingAttachment(
      originKey: 'billing:ui',
      transactionId: transactionId,
      fileName: 'receipt.png',
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/missing/receipt.png',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('待分类账单'), findsOneWidget);
    expect(find.text('商户：天津海河测试餐厅甲\n商品：海河测试饮品甲'), findsOneWidget);
    expect(find.text('¥28.50'), findsOneWidget);
    expect(find.text('2026-07-16 12:30'), findsOneWidget);
    expect(find.text('图片证据'), findsOneWidget);

    // 点击分类选择区域，打开分类选择器对话框
    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();

    // 在对话框中选择分类
    expect(find.byType(CategorySelectorDialog), findsOneWidget);
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    // 对话框已关闭，页面显示已选分类
    expect(find.byType(CategorySelectorDialog), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);

    final currentLedgerScope =
        find.byKey(const Key('classificationScope-currentLedger'));
    expect(currentLedgerScope.hitTestable(), findsOneWidget);
    expect(find.text('仅修正本次账单'), findsOneWidget);
    expect(find.text('记住到当前账本'), findsOneWidget);
    expect(find.text('记住到所有账本'), findsOneWidget);

    await tester.tap(currentLedgerScope);
    final confirmButton = find.byKey(const Key('confirmClassification'));
    await tester.scrollUntilVisible(
      confirmButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final updated = await repository.getTransactionById(transactionId);
    expect(updated!.categoryId, categoryId);
    expect(updated.needsClassification, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('加载失败显示稳定错误并允许重试', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12,
      happenedAt: DateTime(2026, 7, 17, 9),
      note: '商户：便利店',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: _FailFirstLoadService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('账单加载失败，请稍后重试'), findsOneWidget);
    expect(find.byKey(const Key('retryClassificationLoad')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retryClassificationLoad')));
    await tester.pumpAndSettle();
    expect(find.text('商户：便利店'), findsOneWidget);
  });

  testWidgets('附件路径解析失败显示稳定占位而不是持续转圈', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 15,
      happenedAt: DateTime(2026, 7, 17, 10),
      note: '商户：早餐店',
      needsClassification: true,
    );
    await repository.upsertBillingAttachment(
      originKey: 'billing:error-placeholder',
      transactionId: transactionId,
      fileName: 'missing.png',
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => throw Exception('resolver failed'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('图片暂时无法显示'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('确认发生非业务异常时显示通用提示并恢复确认按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.createCategory(name: '餐饮', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime(2026, 7, 17, 11),
      note: '商户：面馆',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: _FailConfirmService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    // 通过分类选择器对话框选择分类
    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('仅修正本次账单'));
    await tester.ensureVisible(
      find.byKey(const Key('confirmClassification')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmClassification')));
    await tester.pumpAndSettle();

    expect(find.text('分类更新失败，请稍后重试'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirmClassification')),
    );
    expect(button.onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('分类选择器展示父子层级结构而非扁平列表', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    final parentCategoryId =
        await repository.createCategory(name: '餐饮', kind: 'expense');
    final childCategoryId = await repository.createSubCategory(
      parentId: parentCategoryId,
      name: '早餐',
      kind: 'expense',
    );
    await repository.createSubCategory(
      parentId: parentCategoryId,
      name: '午餐',
      kind: 'expense',
    );
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 15,
      happenedAt: DateTime(2026, 7, 16, 8),
      note: '商户：早餐店',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    // 打开分类选择器对话框
    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();
    expect(find.byType(CategorySelectorDialog), findsOneWidget);

    // 父分类"餐饮"在对话框中可见
    expect(find.text('餐饮'), findsOneWidget);

    // 点击父分类"餐饮"展开其子分类
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    // 子分类"早餐"和"午餐"在对话框中可见
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);

    // 选择子分类"早餐"
    await tester.tap(find.text('早餐'));
    await tester.pumpAndSettle();

    // 对话框关闭，页面显示已选子分类
    expect(find.byType(CategorySelectorDialog), findsNothing);
    expect(find.text('早餐'), findsOneWidget);

    // 完成分类确认
    await tester.tap(find.text('仅修正本次账单'));
    await tester.ensureVisible(
      find.byKey(const Key('confirmClassification')),
    );
    await tester.tap(find.byKey(const Key('confirmClassification')));
    await tester.pumpAndSettle();

    final updated = await repository.getTransactionById(transactionId);
    expect(updated!.categoryId, childCategoryId);
    expect(updated.needsClassification, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('分类选择器对话框提供分类管理入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.createCategory(name: '餐饮', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime(2026, 7, 17, 9),
      note: '商户：便利店',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    // 打开分类选择器对话框
    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();
    expect(find.byType(CategorySelectorDialog), findsOneWidget);

    final manageEntry = find.byKey(const Key('categorySelector-manage'));
    expect(manageEntry, findsOneWidget);

    await tester.tap(manageEntry);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryManagePage), findsOneWidget);
    expect(find.text('分类管理'), findsOneWidget);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('新建分类'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('从分类管理返回后选择器立即刷新新增分类', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime(2026, 7, 17, 9),
      note: '商户：夜宵店',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();
    expect(find.text('夜宵'), findsNothing);

    await tester.tap(find.byKey(const Key('categorySelector-manage')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryManagePage), findsOneWidget);

    await repository.createCategory(name: '夜宵', kind: 'expense');
    Navigator.of(tester.element(find.byType(CategoryManagePage))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(CategorySelectorDialog), findsOneWidget);
    expect(find.text('夜宵'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('选中分类后页面显示已选分类名称和图标', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db, changeTracker: ChangeTracker(db));
    final ledgerId = await repository.createLedger(name: '日常');
    await repository.createCategory(name: '其他', kind: 'expense');
    await repository.createCategory(name: '餐饮', kind: 'expense');
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12,
      happenedAt: DateTime(2026, 7, 17, 10),
      note: '商户：面馆',
      needsClassification: true,
    );

    await tester.pumpWidget(_buildApp(
      PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
      repository: repository,
    ));
    await tester.pumpAndSettle();

    // 未选择时显示占位提示
    expect(find.text('点击选择分类'), findsOneWidget);
    expect(find.byType(CategoryIconWidget), findsNothing);

    // 打开对话框并选择分类
    await tester.tap(find.text('点击选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    // 页面显示已选分类名称和图标，占位提示消失
    expect(find.text('点击选择分类'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.byType(CategoryIconWidget), findsOneWidget);

    // 可以重新点击已选区域打开对话框切换分类
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.byType(CategorySelectorDialog), findsOneWidget);

    // 选择另一个分类
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FailFirstLoadService extends PendingTransactionClassificationService {
  _FailFirstLoadService(super.repository);

  var _failed = false;

  @override
  Future<PendingTransactionClassificationDraft?> loadDraft({
    required int ledgerId,
    required int transactionId,
  }) {
    if (!_failed) {
      _failed = true;
      throw Exception('temporary load failure');
    }
    return super.loadDraft(
      ledgerId: ledgerId,
      transactionId: transactionId,
    );
  }
}

class _FailConfirmService extends PendingTransactionClassificationService {
  _FailConfirmService(super.repository);

  @override
  Future<void> confirmClassification({
    required int ledgerId,
    required int transactionId,
    required int categoryId,
    required ClassificationMemoryScope memoryScope,
  }) async {
    throw Exception('database write failed');
  }
}
