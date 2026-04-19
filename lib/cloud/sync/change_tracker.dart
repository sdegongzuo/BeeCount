import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../services/system/logger_service.dart';

/// 本地变更追踪器
/// 在 Repository 层捕获写操作，记录到 local_changes 表
/// 同步引擎读取未推送的变更并上传到服务端
class ChangeTracker {
  final BeeDatabase db;

  ChangeTracker(this.db);

  /// 记录一条本地变更
  Future<void> recordChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      entitySyncId: entitySyncId,
      ledgerId: ledgerId,
      action: action,
      payloadJson: d.Value(payloadJson),
    ));
    logger.debug('ChangeTracker', '$action $entityType($entitySyncId)');
  }

  /// 获取所有未推送的变更
  Future<List<LocalChange>> getUnpushedChanges() async {
    return await (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull())
          ..orderBy([(c) => d.OrderingTerm.asc(c.id)]))
        .get();
  }

  /// 获取指定账本的未推送变更
  Future<List<LocalChange>> getUnpushedChangesForLedger(int ledgerId) async {
    return await (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull() & c.ledgerId.equals(ledgerId))
          ..orderBy([(c) => d.OrderingTerm.asc(c.id)]))
        .get();
  }

  /// 标记变更已推送
  Future<void> markPushed(List<int> changeIds) async {
    if (changeIds.isEmpty) return;
    final now = DateTime.now();
    await (db.update(db.localChanges)
          ..where((c) => c.id.isIn(changeIds)))
        .write(LocalChangesCompanion(pushedAt: d.Value(now)));
    logger.debug('ChangeTracker', '标记 ${changeIds.length} 条变更已推送');
  }

  /// 清理已推送的旧变更（保留最近 7 天）
  Future<int> cleanupPushedChanges({Duration retention = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(retention);
    final count = await (db.delete(db.localChanges)
          ..where((c) => c.pushedAt.isNotNull() & c.pushedAt.isSmallerThanValue(cutoff)))
        .go();
    if (count > 0) {
      logger.info('ChangeTracker', '清理 $count 条已推送的旧变更');
    }
    return count;
  }

  /// 获取未推送变更数量
  Future<int> getUnpushedCount() async {
    final result = await (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull()))
        .get();
    return result.length;
  }
}
