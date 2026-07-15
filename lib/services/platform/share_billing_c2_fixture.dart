import 'package:flutter/foundation.dart';

/// Android 分享 C2 tracer 的隔离命名空间。
///
/// runtime intent 只能证明 native 与 Dart 属于同一次 fixture；隔离路径始终
/// 由编译期常量派生，且仅 debug 构建允许启用。
class ShareBillingC2Fixture {
  static const compileTimeFixtureId =
      String.fromEnvironment('BEECOUNT_SHARE_C2_FIXTURE_ID');
  static final RegExp _validId = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

  final String fixtureId;

  const ShareBillingC2Fixture._(this.fixtureId);

  static ShareBillingC2Fixture? resolve({
    required String compileTimeId,
    required String? runtimeId,
    required bool isDebug,
  }) {
    final runtimeMissing = runtimeId == null || runtimeId.isEmpty;
    if (compileTimeId.isEmpty && runtimeMissing) return null;
    if (!isDebug) {
      throw StateError('Share C2 fixture is unavailable outside debug builds');
    }
    if (compileTimeId.isEmpty) {
      throw StateError(
          'Share C2 runtime fixture has no compile-time authority');
    }
    if (!_validId.hasMatch(compileTimeId)) {
      throw FormatException('Invalid BEECOUNT_SHARE_C2_FIXTURE_ID');
    }
    if (runtimeId != compileTimeId) {
      throw StateError('Share C2 runtime fixture does not match build fixture');
    }
    return ShareBillingC2Fixture._(compileTimeId);
  }

  static ShareBillingC2Fixture? fromRuntime(String? runtimeId) => resolve(
        compileTimeId: compileTimeFixtureId,
        runtimeId: runtimeId,
        isDebug: kDebugMode,
      );

  String get databaseFileName => 'beecount_share_c2_$fixtureId.sqlite';

  String get attachmentDirectoryName =>
      'beecount_share_c2_${fixtureId}_attachments';

  @override
  bool operator ==(Object other) =>
      other is ShareBillingC2Fixture && other.fixtureId == fixtureId;

  @override
  int get hashCode => fixtureId.hashCode;
}
