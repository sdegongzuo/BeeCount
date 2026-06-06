// SyncDiffService 单元测试。
//
// 锁死 applySyncChanges 在 added/modified 场景下正确传递
// paymentMethod / counterparty / paymentChannel / merchantFullName /
// acquirer / detailsText 六个元信息字段到数据库。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync_diff_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncDiffService.applySyncChanges', () {
    late int ledgerId;

    setUp(() async {
      ledgerId = await repo.createLedger(name: 'test');
    });

    test('added: 本地交易保留全部 6 个元信息字段', () async {
      final cloudTx = ImportTransaction(
        type: 'expense',
        amount: 100.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        note: 'test',
        paymentMethod: '信用卡',
        counterparty: '天津海河测试餐厅甲',
        paymentChannel: '微信支付',
        merchantFullName: '天津海河测试餐厅甲(天津和平测试门店甲)',
        acquirer: '银联',
        detailsText: '订单号:ABC\n商户:天津海河测试餐厅甲\n金额:100.00',
        syncId: 'sync-added-1',
      );

      final importData = ImportData(transactions: [cloudTx]);

      final result = await syncDiffService.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: [
          SyncChange(
            type: SyncChangeType.added,
            cloudTransaction: cloudTx,
          ),
        ],
        importData: importData,
      );

      expect(result.addedCount, 1);

      // 从数据库读回验证
      final local = await repo.getTransactionBySyncId('sync-added-1');
      expect(local, isNotNull);
      expect(local!.paymentMethod, '信用卡');
      expect(local.counterparty, '天津海河测试餐厅甲');
      expect(local.paymentChannel, '微信支付');
      expect(local.merchantFullName, '天津海河测试餐厅甲(天津和平测试门店甲)');
      expect(local.acquirer, '银联');
      expect(local.detailsText, '订单号:ABC\n商户:天津海河测试餐厅甲\n金额:100.00');
    });

    test('modified: 更新后本地交易保留全部 6 个元信息字段', () async {
      // 先创建一笔本地交易
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 50.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        note: 'old',
        syncId: 'sync-mod-1',
      );

      // 云端版本带完整元信息
      final cloudTx = ImportTransaction(
        type: 'expense',
        amount: 88.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        note: 'updated',
        paymentMethod: '借记卡',
        counterparty: '美团',
        paymentChannel: '支付宝',
        merchantFullName: '麦当劳(望京店)',
        acquirer: '网联',
        detailsText: '订单号:XYZ\n商户:麦当劳\n金额:88.00',
        syncId: 'sync-mod-1',
      );

      final importData = ImportData(transactions: [cloudTx]);

      final result = await syncDiffService.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: [
          SyncChange(
            type: SyncChangeType.modified,
            cloudTransaction: cloudTx,
          ),
        ],
        importData: importData,
      );

      expect(result.modifiedCount, 1);

      // 从数据库读回验证
      final local = await repo.getTransactionBySyncId('sync-mod-1');
      expect(local, isNotNull);
      expect(local!.amount, 88.0);
      expect(local.note, 'updated');
      expect(local.paymentMethod, '借记卡');
      expect(local.counterparty, '美团');
      expect(local.paymentChannel, '支付宝');
      expect(local.merchantFullName, '麦当劳(望京店)');
      expect(local.acquirer, '网联');
      expect(local.detailsText, '订单号:XYZ\n商户:麦当劳\n金额:88.00');
    });

    test('added: 元信息字段为 null 时不写入', () async {
      final cloudTx = ImportTransaction(
        type: 'income',
        amount: 200.0,
        happenedAt: DateTime.utc(2026, 6, 1),
        syncId: 'sync-null-1',
      );

      final importData = ImportData(transactions: [cloudTx]);

      await syncDiffService.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: [
          SyncChange(
            type: SyncChangeType.added,
            cloudTransaction: cloudTx,
          ),
        ],
        importData: importData,
      );

      final local = await repo.getTransactionBySyncId('sync-null-1');
      expect(local, isNotNull);
      expect(local!.paymentMethod, isNull);
      expect(local.counterparty, isNull);
      expect(local.paymentChannel, isNull);
      expect(local.merchantFullName, isNull);
      expect(local.acquirer, isNull);
      expect(local.detailsText, isNull);
    });
  });

  group('SyncDiffService.computeDiff 比较', () {
    late int ledgerId;

    setUp(() async {
      ledgerId = await repo.createLedger(name: 'test-diff');
    });

    test('paymentMethod 变更被检测为 diff', () async {
      // 创建本地交易
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        paymentMethod: '现金',
        syncId: 'sync-diff-1',
      );
      final localTxs = await repo.getTransactionsByLedger(ledgerId);

      // 云端版本 paymentMethod 不同
      final cloudTx = ImportTransaction(
        type: 'expense',
        amount: 100.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        paymentMethod: '信用卡',
        syncId: 'sync-diff-1',
      );

      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [cloudTx],
        localTransactions: localTxs,
      );

      expect(preview, isNotNull);
      expect(preview!.changes.length, 1);
      expect(preview.changes.first.type, SyncChangeType.modified);
      expect(preview.changes.first.diffDetails,
          anyElement(contains('支付方式')));
    });

    test('counterparty 变更被检测为 diff', () async {
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        counterparty: '旧商家',
        syncId: 'sync-diff-2',
      );
      final localTxs = await repo.getTransactionsByLedger(ledgerId);

      final cloudTx = ImportTransaction(
        type: 'expense',
        amount: 100.0,
        happenedAt: DateTime.utc(2026, 1, 1),
        counterparty: '新商家',
        syncId: 'sync-diff-2',
      );

      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [cloudTx],
        localTransactions: localTxs,
      );

      expect(preview, isNotNull);
      expect(preview!.changes.length, 1);
      expect(preview.changes.first.diffDetails,
          anyElement(contains('交易对方')));
    });

    test('全部 6 字段相同时不产生 diff', () async {
      // 使用本地 DateTime（非 UTC），避免 SyncDiffService 按本地时区
      // 比较时因 UTC→本地转换产生时间差异而误报 diff。
      final happenedAt = DateTime(2026, 1, 1, 12, 0);

      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100.0,
        happenedAt: happenedAt,
        paymentMethod: '信用卡',
        counterparty: '天津海河测试餐厅甲',
        paymentChannel: '微信支付',
        merchantFullName: '天津海河测试餐厅甲',
        acquirer: '银联',
        detailsText: '订单号:123',
        syncId: 'sync-diff-3',
      );
      final localTxs = await repo.getTransactionsByLedger(ledgerId);

      final cloudTx = ImportTransaction(
        type: 'expense',
        amount: 100.0,
        happenedAt: happenedAt,
        paymentMethod: '信用卡',
        counterparty: '天津海河测试餐厅甲',
        paymentChannel: '微信支付',
        merchantFullName: '天津海河测试餐厅甲',
        acquirer: '银联',
        detailsText: '订单号:123',
        syncId: 'sync-diff-3',
      );

      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [cloudTx],
        localTransactions: localTxs,
      );

      expect(preview, isNotNull);
      expect(preview!.changes, isEmpty);
    });
  });
}
