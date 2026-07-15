import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository create and update preserve pending-classification state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final ledgerId = await repo.createLedger(name: 'repository');
    final accountId = await repo.createAccount(
      ledgerId: ledgerId,
      name: 'cash',
    );
    final id = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12,
      accountId: accountId,
      happenedAt: DateTime.utc(2026, 7, 16),
      needsClassification: true,
    );
    expect((await repo.getTransactionById(id))?.needsClassification, isTrue);
    expect(
      (await repo.getAccountTransactions(accountId)).single.needsClassification,
      isTrue,
    );
    final tagId = await repo.createTag(name: 'pending');
    await repo.addTagToTransaction(transactionId: id, tagId: tagId);
    expect(
      (await repo.watchTransactionsByTag(tagId).first)
          .single
          .needsClassification,
      isTrue,
    );

    await repo.updateTransaction(
      id: id,
      type: 'expense',
      amount: 12,
      needsClassification: false,
    );
    expect((await repo.getTransactionById(id))?.needsClassification, isFalse);
  });
}
