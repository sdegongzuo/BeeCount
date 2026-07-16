import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 公共账单规则在应用文档目录中的唯一文件布局。
///
/// 所有生产读取、更新与恢复链都必须通过该对象取得路径，避免不同入口各自
/// 推导目录后读取到不同快照。
class BillingRuleStorage {
  /// 当前活动公共规则文件名。
  static const activeFileName = 'billing_rules.active.toml';

  /// 上一版安全公共规则文件名。
  static const previousFileName = 'billing_rules.previous.toml';

  /// 已下载、完成基础校验但尚未激活的候选规则文件名。
  static const pendingFileName = 'billing_rules.pending.toml';

  /// 最近检查时间文件名。
  static const lastCheckFileName = 'billing_rules.last_check.json';

  /// 可恢复激活状态机及最近一次更新诊断。
  static const activationJournalFileName =
      'billing_rules.activation_journal.json';

  /// 跨进程/Isolate 串行规则状态转换的锁文件名。
  static const lockFileName = 'billing_rules.lock';

  /// 规则专用目录。
  final Directory directory;

  /// 使用已确定的规则目录创建文件布局。
  const BillingRuleStorage(this.directory);

  /// 当前活动规则。
  File get activeFile => File(path.join(directory.path, activeFileName));

  /// 上一版安全快照。
  File get previousFile => File(path.join(directory.path, previousFileName));

  /// 下载校验中、等待原子激活的候选包。
  File get pendingFile => File(path.join(directory.path, pendingFileName));

  /// 上一版快照原子替换前的临时文件。
  File get previousPendingFile => File('${previousFile.path}.pending');

  /// 归档失败后恢复 active 所使用的原子临时文件。
  File get activeRecoveryPendingFile =>
      File('${activeFile.path}.recovery.pending');

  /// 手动回滚 active 所使用的原子临时文件。
  File get activeRollbackPendingFile =>
      File('${activeFile.path}.rollback.pending');

  /// 手动回滚 previous 所使用的原子临时文件。
  File get previousRollbackPendingFile =>
      File('${previousFile.path}.rollback.pending');

  /// 最近更新检查记录。
  File get lastCheckFile => File(path.join(directory.path, lastCheckFileName));

  /// 可恢复激活 journal。成功后也保留 committed 快照供诊断区读取。
  File get activationJournalFile =>
      File(path.join(directory.path, activationJournalFileName));

  /// journal 原子替换使用的固定临时路径。
  File get activationJournalPendingFile =>
      File('${activationJournalFile.path}.pending');

  /// 由操作系统释放语义保护的跨 Isolate 文件锁。
  File get lockFile => File(path.join(directory.path, lockFileName));

  /// 在本进程内按规范化目录串行执行一次规则文件状态转换。
  ///
  /// 即使调用方创建了多个更新服务或多个 [BillingRuleStorage] 实例，只要目录
  /// 相同，更新、激活和回滚就不会交错。
  Future<T> runExclusive<T>(Future<T> Function() action) =>
      _mutexFor(directory).run(() async {
        await directory.create(recursive: true);
        final handle = await lockFile.open(mode: FileMode.append);
        try {
          await _acquireExclusiveFileLock(handle);
          return await action();
        } finally {
          try {
            await handle.unlock();
          } finally {
            await handle.close();
          }
        }
      });
}

Future<void> _acquireExclusiveFileLock(RandomAccessFile handle) async {
  while (true) {
    try {
      await handle.lock(FileLock.exclusive);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}

final Map<String, _BillingRuleStorageMutex> _storageMutexes = {};

_BillingRuleStorageMutex _mutexFor(Directory directory) {
  var key = path.normalize(path.absolute(directory.path));
  if (Platform.isWindows) key = key.toLowerCase();
  return _storageMutexes.putIfAbsent(key, _BillingRuleStorageMutex.new);
}

class _BillingRuleStorageMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = previous.then((_) => released.future);
    await previous;
    try {
      return await action();
    } finally {
      released.complete();
    }
  }
}

Future<BillingRuleStorage>? _productionStorage;

/// 返回进程内唯一的生产规则文件布局。
///
/// 路径固定为 application documents 下的 `rules` 目录。
Future<BillingRuleStorage> productionBillingRuleStorage() =>
    _productionStorage ??= _createProductionBillingRuleStorage();

Future<BillingRuleStorage> _createProductionBillingRuleStorage() async {
  final documents = await getApplicationDocumentsDirectory();
  return BillingRuleStorage(Directory(path.join(documents.path, 'rules')));
}
