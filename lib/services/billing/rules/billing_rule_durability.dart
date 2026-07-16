import 'dart:io';

import 'package:flutter/services.dart';

/// 规则状态机的持久化屏障。
///
/// 屏障返回前必须保证文件内容和承载 rename 的父目录元数据都已提交；失败必须
/// 抛出，使状态机保持未提交并在下次启动恢复。
abstract class BillingRuleDurability {
  /// 同步指定文件及其父目录。
  Future<void> syncFileAndParent(File file);
}

/// Android 生产环境通过原生 `fsync(2)` 同步文件和父目录。
class AndroidBillingRuleDurability implements BillingRuleDurability {
  static const _channel =
      MethodChannel('com.tntlikely.beecount/billing_rule_durability');

  /// 创建 Android 原生持久化屏障。
  const AndroidBillingRuleDurability();

  @override
  Future<void> syncFileAndParent(File file) async {
    await _channel.invokeMethod<void>('syncFileAndParent', file.absolute.path);
  }
}

/// 非 Android 和单元测试使用的文件 flush 屏障。
///
/// Dart 未暴露目录 fd；Android 生产绝不会走该实现。桌面测试通过注入 seam
/// 验证调用顺序，文件本身仍使用 RandomAccessFile.flush。
class DartBillingRuleDurability implements BillingRuleDurability {
  /// 创建 Dart 文件持久化屏障。
  const DartBillingRuleDurability();

  @override
  Future<void> syncFileAndParent(File file) async {
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }
}

/// 当前平台的生产持久化实现。
BillingRuleDurability productionBillingRuleDurability() => Platform.isAndroid
    ? const AndroidBillingRuleDurability()
    : const DartBillingRuleDurability();
