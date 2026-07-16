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
}
