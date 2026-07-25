import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';
import 'package:beecount/data/repositories/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late TransactionRepository repository;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalTransactionRepository(db);
  });

  tearDown(() => db.close());

  test('累计优惠只汇总账本和时间范围内的支出交易', () async {
    final july = DateTime.utc(2026, 7, 10);
    await repository.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 8.90,
      discountAmount: 1.00,
      happenedAt: july,
    );
    await repository.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 19.70,
      discountAmount: 0.30,
      happenedAt: DateTime.utc(2026, 7, 20),
    );
    await repository.addTransaction(
      ledgerId: 1,
      type: 'income',
      amount: 100,
      discountAmount: 5,
      happenedAt: july,
    );
    await repository.addTransaction(
      ledgerId: 2,
      type: 'expense',
      amount: 10,
      discountAmount: 9,
      happenedAt: july,
    );
    await repository.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 12,
      discountAmount: 7,
      happenedAt: DateTime.utc(2026, 6, 30),
    );

    final total = await repository.totalDiscountInRange(
      ledgerId: 1,
      start: DateTime.utc(2026, 7),
      end: DateTime.utc(2026, 8),
    );

    expect(total, 1.30);
  });
}
