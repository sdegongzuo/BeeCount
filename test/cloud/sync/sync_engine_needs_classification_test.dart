import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBeeCountCloudProvider extends BeeCountCloudProvider {
  _FakeBeeCountCloudProvider(this.result);

  final BeeCountCloudPullResult result;

  @override
  CloudAuthService get auth => NoopAuthService();

  @override
  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
  }) async =>
      result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync pull applies pending-classification state on insert and update',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'sync',
            syncId: const Value('ledger-sync-1'),
          ),
        );
    final repo = LocalRepository(db);
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime.utc(2026, 7, 15),
      syncId: 'tx-existing',
    );
    final provider = _FakeBeeCountCloudProvider(
      BeeCountCloudPullResult(
        changes: [
          BeeCountCloudSyncChange(
            changeId: 1,
            ledgerId: 'ledger-sync-1',
            entityType: 'transaction',
            entitySyncId: 'tx-new',
            action: 'create',
            payload: {
              'type': 'expense',
              'amount': 12,
              'happenedAt': '2026-07-16T00:00:00.000Z',
              'needsClassification': true,
            },
          ),
          BeeCountCloudSyncChange(
            changeId: 2,
            ledgerId: 'ledger-sync-1',
            entityType: 'transaction',
            entitySyncId: 'tx-existing',
            action: 'update',
            payload: {
              'type': 'expense',
              'amount': 20,
              'happenedAt': '2026-07-15T00:00:00.000Z',
              'needsClassification': true,
            },
          ),
        ],
        serverCursor: 2,
        hasMore: false,
      ),
    );
    final engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: ChangeTracker(db),
      repo: repo,
    );

    expect(await engine.replayAllChanges(), 2);
    expect(
      (await repo.getTransactionBySyncId('tx-new'))?.needsClassification,
      isTrue,
    );
    expect(
      (await repo.getTransactionBySyncId('tx-existing'))
          ?.needsClassification,
      isTrue,
    );
  });
}
