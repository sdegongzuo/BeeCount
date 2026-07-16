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

  /// 最近更新检查记录。
  File get lastCheckFile => File(path.join(directory.path, lastCheckFileName));
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
