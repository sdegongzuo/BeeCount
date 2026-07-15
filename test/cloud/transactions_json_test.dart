// transactions_json 单元测试。
//
// 锁死 parseJsonToImportData 对 paymentChannel / merchantFullName /
// acquirer / detailsText（含换行）的解析正确性。

import 'dart:convert';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/cloud/transactions_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('parseJsonToImportData', () {
    test('保留 paymentChannel / merchantFullName / acquirer 字段', () {
      final json = _buildJson(items: [
        {
          'type': 'expense',
          'amount': 100.0,
          'happenedAt': '2026-01-01T00:00:00.000Z',
          'note': 'test',
          'paymentChannel': '微信支付',
          'merchantFullName': '天津海河测试餐厅甲',
          'acquirer': '银联',
          'syncId': 'sync-1',
        },
      ]);

      final data = parseJsonToImportData(json);
      expect(data.transactions.length, 1);
      final tx = data.transactions.first;
      expect(tx.paymentChannel, '微信支付');
      expect(tx.merchantFullName, '天津海河测试餐厅甲');
      expect(tx.acquirer, '银联');
    });

    test('保留 detailsText 中的换行符', () {
      final details = '商户:天津海河测试餐厅甲\n金额:38.00\n时间:2026-01-01';
      final json = _buildJson(items: [
        {
          'type': 'expense',
          'amount': 38.0,
          'happenedAt': '2026-01-01T00:00:00.000Z',
          'detailsText': details,
          'syncId': 'sync-2',
        },
      ]);

      final data = parseJsonToImportData(json);
      expect(data.transactions.length, 1);
      expect(data.transactions.first.detailsText, details);
      // 关键断言：换行被保留
      expect(data.transactions.first.detailsText, contains('\n'));
    });

    test('同时保留全部 6 个元信息字段', () {
      final json = _buildJson(items: [
        {
          'type': 'expense',
          'amount': 50.0,
          'happenedAt': '2026-06-01T08:00:00.000Z',
          'note': '午餐',
          'paymentMethod': '信用卡',
          'counterparty': '美团',
          'paymentChannel': '支付宝',
          'merchantFullName': '肯德基',
          'acquirer': '银联',
          'detailsText': '订单号:123\n商户:肯德基\n金额:50.00',
          'syncId': 'sync-3',
        },
      ]);

      final data = parseJsonToImportData(json);
      final tx = data.transactions.first;
      expect(tx.paymentMethod, '信用卡');
      expect(tx.counterparty, '美团');
      expect(tx.paymentChannel, '支付宝');
      expect(tx.merchantFullName, '肯德基');
      expect(tx.acquirer, '银联');
      expect(tx.detailsText, contains('\n'));
    });

    test('字段缺失时为 null', () {
      final json = _buildJson(items: [
        {
          'type': 'income',
          'amount': 200.0,
          'happenedAt': '2026-01-01T00:00:00.000Z',
          'syncId': 'sync-4',
        },
      ]);

      final data = parseJsonToImportData(json);
      final tx = data.transactions.first;
      expect(tx.paymentMethod, isNull);
      expect(tx.counterparty, isNull);
      expect(tx.paymentChannel, isNull);
      expect(tx.merchantFullName, isNull);
      expect(tx.acquirer, isNull);
      expect(tx.detailsText, isNull);
      expect(tx.needsClassification, isFalse);
    });

    test('保留结构化待分类状态', () {
      final json = _buildJson(items: [
        {
          'type': 'expense',
          'amount': 12.0,
          'happenedAt': '2026-07-16T00:00:00.000Z',
          'needsClassification': true,
          'syncId': 'sync-pending-1',
        },
      ]);

      final tx = parseJsonToImportData(json).transactions.single;
      expect(tx.needsClassification, isTrue);
    });
  });

  test('export preserves the structured pending-classification state',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'export'),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 12,
            needsClassification: const Value(true),
          ),
        );

    final exportedJson = await exportTransactionsJson(db, ledgerId);
    await db.close();
    final exported = jsonDecode(exportedJson) as Map<String, dynamic>;
    final item = (exported['items'] as List).single as Map<String, dynamic>;
    expect(exported['version'], 8);
    expect(item['needsClassification'], isTrue);

    final targetDb = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(targetDb.close);
    final targetLedgerId = await targetDb.into(targetDb.ledgers).insert(
          LedgersCompanion.insert(name: 'import'),
        );
    final result = await importTransactionsJson(
      LocalRepository(targetDb),
      targetLedgerId,
      exportedJson,
    );
    expect(result.inserted, 1);
    expect(
      (await (targetDb.select(targetDb.transactions)).getSingle())
          .needsClassification,
      isTrue,
    );
  });
}

String _buildJson({required List<Map<String, dynamic>> items}) {
  return jsonEncode({
    'version': 7,
    'exportedAt': '2026-06-06T00:00:00.000Z',
    'ledgerId': 1,
    'ledgerName': 'test',
    'currency': 'CNY',
    'count': items.length,
    'accounts': <Map<String, dynamic>>[],
    'categories': <Map<String, dynamic>>[],
    'tags': <Map<String, dynamic>>[],
    'items': items,
  });
}
