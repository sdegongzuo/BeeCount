import 'dart:async';
import 'dart:io';

import 'package:beecount/ai/tasks/bill_extraction_task.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/ai_async_enhance_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;
  late int shoppingCategoryId;
  late int foodCategoryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'Task 06');
    shoppingCategoryId = await repo.createCategory(
      name: '购物',
      kind: 'expense',
    );
    foodCategoryId = await repo.createCategory(
      name: '餐饮',
      kind: 'expense',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('keeps rule amount time and payment channel when AI conflicts',
      () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => BillInfo(
        amount: -99.99,
        time: DateTime(2026, 1, 1, 8, 0),
        paymentChannel: '支付宝',
        note: '拼多多',
        category: '购物',
        paymentMethod: '平安银行信用卡(2299)',
        counterparty: '拼多多',
        details: const {'merchant_order_no': 'XP123'},
      ),
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '微信支付交易详情',
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.succeeded);
    expect(tx?.amount, 19.5);
    expect(tx?.happenedAt, DateTime(2026, 5, 31, 14, 27, 40));
    expect(tx?.paymentChannel, '微信支付');
    expect(tx?.note, '拼多多');
    expect(tx?.categoryId, shoppingCategoryId);
    expect(tx?.paymentMethod, '平安银行信用卡(2299)');
    expect(tx?.counterparty, '拼多多');
    expect(tx?.detailsText, contains('ai_enhance_status: succeeded'));
    expect(tx?.detailsText, contains('ai_conflict_amount: -99.99'));
    expect(tx?.detailsText, contains('merchant_order_no: XP123'));
  });

  test('fills allowed AI fields after the base transaction exists', () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => const BillInfo(
        note: '天津津门测试餐厅乙',
        category: '餐饮',
        paymentMethod: '中国银行信用卡(2853)',
        counterparty: '天津津门测试餐厅乙',
        merchantFullName: '天津滨海测试信息技术有限公司丁',
        acquirer: '上海富友支付服务股份有限公司',
        details: {'store_name': '南开测试店'},
      ),
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '微信支付交易详情',
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.succeeded);
    expect(tx?.amount, 19.5);
    expect(tx?.paymentChannel, '微信支付');
    expect(tx?.note, '天津津门测试餐厅乙');
    expect(tx?.categoryId, foodCategoryId);
    expect(tx?.paymentMethod, '中国银行信用卡(2853)');
    expect(tx?.counterparty, '天津津门测试餐厅乙');
    expect(tx?.merchantFullName, '天津滨海测试信息技术有限公司丁');
    expect(tx?.acquirer, '上海富友支付服务股份有限公司');
    expect(tx?.detailsText, contains('store_name: 南开测试店'));
  });

  test('marks AI failures without rolling back the base transaction', () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => throw StateError('provider failed'),
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '微信支付交易详情',
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.failed);
    expect(tx?.amount, 19.5);
    expect(tx?.note, '财付通支付科技有限公司');
    expect(tx?.detailsText, contains('ai_enhance_status: failed'));
    expect(tx?.detailsText,
        contains('ai_enhance_error: Bad state: provider failed'));
  });

  test('marks AI timeout without rolling back the base transaction', () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final service = AiAsyncEnhanceService(
      repo: repo,
      timeout: const Duration(milliseconds: 10),
      loadBillInfo: (_) => Completer<BillInfo?>().future,
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '微信支付交易详情',
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.timeout);
    expect(tx?.amount, 19.5);
    expect(tx?.paymentChannel, '微信支付');
    expect(tx?.detailsText, contains('ai_enhance_status: timeout'));
  });

  test('records vision rule audit and default-enabled suggestion on low score',
      () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final image = File('${Directory.systemTemp.path}/bee_audit_test.jpg');
    await image.writeAsBytes(const [1, 2, 3]);
    addTearDown(() async {
      if (await image.exists()) {
        await image.delete();
      }
    });

    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => const BillInfo(
        note: 'ETC服务',
        category: '交通',
      ),
      enableRuleAudit: true,
      auditRuleResult: (_) async => const AiRuleAuditResult(
        ruleScore: 0.61,
        accepted: false,
        issues: ['payment_channel: 规则来源与视觉证据不一致'],
      ),
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '账单详情 ETC服务',
      imageFile: image,
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.succeeded);
    expect(outcome.ruleAudit?.ruleScore, 0.61);
    expect(tx?.detailsText, contains('ai_rule_audit_score: 0.61'));
    expect(tx?.detailsText, contains('ai_rule_audit_accepted: false'));
    expect(tx?.detailsText, contains('ai_rule_review_default_enabled: true'));
    expect(
        tx?.detailsText, contains('ai_rule_review_status: active_suggestion'));
  });

  test('skips vision rule audit by default', () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final image = File('${Directory.systemTemp.path}/bee_audit_default_off.jpg');
    await image.writeAsBytes(const [1, 2, 3]);
    addTearDown(() async {
      if (await image.exists()) {
        await image.delete();
      }
    });

    var auditCalled = false;
    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => const BillInfo(note: 'ETC service'),
      auditRuleResult: (_) async {
        auditCalled = true;
        return const AiRuleAuditResult(
          ruleScore: 0.61,
          accepted: false,
        );
      },
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: 'bill detail ETC service',
      imageFile: image,
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.succeeded);
    expect(outcome.ruleAudit, isNull);
    expect(auditCalled, isFalse);
    expect(tx?.detailsText, contains('ai_enhance_status: succeeded'));
    expect(tx?.detailsText, isNot(contains('ai_rule_audit_score')));
    expect(tx?.detailsText, isNot(contains('ai_rule_review_default_enabled')));
  });

  test('marks vision rule audit timeout without failing enhancement', () async {
    final txId = await _insertBaseTransaction(repo, ledgerId);
    final image = File('${Directory.systemTemp.path}/bee_audit_timeout.jpg');
    await image.writeAsBytes(const [1, 2, 3]);
    addTearDown(() async {
      if (await image.exists()) {
        await image.delete();
      }
    });

    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (_) async => const BillInfo(
        note: '天津海河测试咖啡馆丑',
        category: '咖啡',
      ),
      enableRuleAudit: true,
      auditRuleResult: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const AiRuleAuditResult(ruleScore: 1, accepted: true);
      },
      auditTimeout: const Duration(milliseconds: 10),
    );

    final outcome = await service.enhanceTransaction(
      transactionId: txId,
      rawText: '账单详情 天津海河测试咖啡馆丑',
      imageFile: image,
    );

    final tx = await repo.getTransactionById(txId);
    expect(outcome.status, AiAsyncEnhanceStatus.succeeded);
    expect(outcome.ruleAudit, isNull);
    expect(tx?.detailsText, contains('ai_enhance_status: succeeded'));
    expect(tx?.detailsText, contains('ai_rule_audit_error:'));
    expect(tx?.detailsText, contains('TimeoutException'));
  });
}

Future<int> _insertBaseTransaction(
  LocalRepository repo,
  int ledgerId,
) {
  return repo.addTransaction(
    ledgerId: ledgerId,
    type: 'expense',
    amount: 19.5,
    happenedAt: DateTime(2026, 5, 31, 14, 27, 40),
    note: '财付通支付科技有限公司',
    paymentChannel: '微信支付',
    detailsText:
        'billing_rule_template_id: wechat_payment_detail_v1\ntransaction_no: 9223292424251435949411772872',
  );
}
