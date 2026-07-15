import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'Bill Creation');
    await repo.createCategory(name: '其他', kind: 'expense');
    await repo.createCategory(name: '其他退费', kind: 'income');
  });

  tearDown(() async {
    await db.close();
  });

  test('keeps negative OCR amount as expense when text has trailing plus noise',
      () async {
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '''
账单详情
支付宝
-3.75
自动扣款成功
支付时间
2026-07-03 23:30:20
更多
+++
0
<''',
        amount: -3.75,
        note: 'ETC服务',
        time: DateTime(2026, 7, 3, 23, 30, 20),
        paymentChannel: '支付宝',
        allNumbers: const ['3.75', '3'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    expect(transactionId, isNotNull);
    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.type, 'expense');
    expect(transaction?.amount, 3.75);
    expect(transaction?.note, isNull);
  });

  test('图片分享分类与备注不消费 AI 输出', () async {
    final foodId = await repo.createCategory(name: '餐饮', kind: 'expense');
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '天津海河测试餐厅甲 咖啡 支付成功',
        amount: 28,
        time: DateTime(2026, 7, 12),
        note: '天津海河测试餐厅甲',
        merchantFullName: '天津海河测试餐厅甲',
        details: const {'product_summary': '海河测试饮品甲', 'store_name': '天津和平测试门店甲'},
        aiCategoryName: '交通',
        allNumbers: const ['28'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, foodId);
    expect(transaction?.needsClassification, isFalse);
    expect(transaction?.note, '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲\n门店：天津和平测试门店甲');
  });

  test('图片分享优先使用图片中的商户字段做确定性分类', () async {
    final foodCategoryId =
        await repo.createCategory(name: '餐饮', kind: 'expense');
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '滴滴 支付成功',
        amount: 28,
        time: DateTime(2026, 7, 12),
        allNumbers: const ['28'],
        merchantFullName: '天津海河测试餐厅甲',
        aiCategoryName: '交通',
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, foodCategoryId);
  });

  test('图片分享无法可靠分类时仍创建到其他并记录待分类', () async {
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '未知服务 支付成功',
        amount: 12,
        time: DateTime(2026, 7, 12),
        allNumbers: const ['12'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction, isNotNull);
    expect(transaction?.needsClassification, isTrue);
    expect(transaction?.detailsText, isNot(contains('待分类：是')));
  });
}
