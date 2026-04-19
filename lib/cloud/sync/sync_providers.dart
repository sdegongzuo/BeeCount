import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    hide SyncStatus;

import '../../providers/database_providers.dart';
import 'change_tracker.dart';
import 'sync_engine.dart';

/// ChangeTracker provider
final changeTrackerProvider = Provider<ChangeTracker>((ref) {
  final db = ref.watch(databaseProvider);
  return ChangeTracker(db);
});

/// SyncEngine provider（需要已认证的 BeeCountCloudProvider）
final syncEngineProvider = Provider.family<SyncEngine, BeeCountCloudProvider>(
  (ref, provider) {
    final db = ref.watch(databaseProvider);
    final tracker = ref.watch(changeTrackerProvider);
    final repo = ref.watch(repositoryProvider);
    return SyncEngine(
      db: db,
      provider: provider,
      changeTracker: tracker,
      repo: repo,
    );
  },
);

/// 同步引擎状态（区别于 sync_service.dart 中的 SyncStatus）
final syncEngineStatusProvider =
    StateProvider<SyncEngineStatus>((ref) => SyncEngineStatus.idle);

/// 未推送变更数量
final unpushedChangeCountProvider = FutureProvider<int>((ref) async {
  final tracker = ref.watch(changeTrackerProvider);
  return tracker.getUnpushedCount();
});
