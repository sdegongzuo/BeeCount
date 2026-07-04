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
    expect(transaction?.note, 'ETC服务');
  });
}
