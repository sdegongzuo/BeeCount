import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/billing/pending_transaction_classification_page.dart';
import 'package:beecount/services/billing/pending_transaction_classification_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('展示账单证据并由用户明确选择分类记忆范围', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
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

    await tester.pumpWidget(MaterialApp(
      home: PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: PendingTransactionClassificationService(repository),
        resolveAttachmentPath: (_) async => '/missing/receipt.png',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('待分类账单'), findsOneWidget);
    expect(find.text('商户：天津海河测试餐厅甲\n商品：海河测试饮品甲'), findsOneWidget);
    expect(find.text('¥28.50'), findsOneWidget);
    expect(find.text('2026-07-16 12:30'), findsOneWidget);
    expect(find.text('图片证据'), findsOneWidget);
    expect(find.text('仅修正本次账单'), findsOneWidget);
    expect(find.text('记住到当前账本'), findsOneWidget);
    expect(find.text('记住到所有账本'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    await tester.tap(find.text('记住到当前账本'));
    await tester.tap(find.byKey(const Key('confirmClassification')));
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

    await tester.pumpWidget(MaterialApp(
      home: PendingTransactionClassificationPage(
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

    await tester.pumpWidget(MaterialApp(
      home: PendingTransactionClassificationPage(
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

    await tester.pumpWidget(MaterialApp(
      home: PendingTransactionClassificationPage(
        ledgerId: ledgerId,
        transactionId: transactionId,
        service: _FailConfirmService(repository),
        resolveAttachmentPath: (_) async => '/unused',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
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
