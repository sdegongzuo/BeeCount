import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_job_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/smart_billing_providers.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('switching current ledger cannot redirect confirmation or learned scope',
      () async {
    SharedPreferences.setMockInitialValues(const {});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = LocalRepository(db);
    final originalLedger = await repository.createLedger(name: '原账本');
    final otherLedger = await repository.createLedger(name: '后来切换的账本');
    await repository.createCategory(name: '其他', kind: 'expense');
    final categoryId =
        await repository.createCategory(name: '咖啡', kind: 'expense');
    final jobs = LocalBillingJobRepository(db);
    final job = await jobs.createJob(
      imagePath: '/tmp/captured-ledger-confirm.png',
      ledgerId: originalLedger,
    );
    await jobs.updateFinalResultJson(
      job.id,
      jsonEncode(OcrResult(
        rawText: '天津海河测试餐厅甲\n18.00',
        allNumbers: const ['18.00'],
        amount: 18,
        time: DateTime(2026, 7, 16, 9, 30),
        merchantFullName: '天津海河测试餐厅甲',
      ).toJson()),
    );
    await jobs.updateStatus(job.id, BillingJobStatus.awaitingConfirmation);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.read(currentLedgerIdProvider.notifier).state = otherLedger;
    final service =
        await container.read(pendingBillConfirmationServiceProvider.future);

    final result = await service.confirm(
      jobId: job.id,
      amount: 18,
      time: DateTime(2026, 7, 16, 9, 30),
      supplementalNote: '',
      categoryId: categoryId,
      rememberCategoryRule: true,
    );

    final transaction =
        await repository.getTransactionById(result.transactionId);
    expect(transaction!.ledgerId, originalLedger);
    expect(transaction.ledgerId, isNot(otherLedger));
    final learned = await SqlitePersonalCategoryRuleStore(db).loadActiveRules();
    expect(learned.single.matchText, '天津海河测试餐厅甲');
    expect(learned.single.ledgerId, originalLedger);
  });
}
