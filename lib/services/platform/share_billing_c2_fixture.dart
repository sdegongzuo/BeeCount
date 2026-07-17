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

  /// 从 OCR 的完整数值 token 中选择一个不同于当前金额的确认值。
  ///
  /// OCR 的候选列表可能同时包含 `18.50` 和它的整数片段 `18`。C2 只能
  /// 模拟用户选择图片中真实存在的完整金额，不能把派生片段当成校正证据。
  static double selectDistinctExactAmountCandidate({
    required String rawText,
    required double? currentAmount,
    required Iterable<String> candidates,
  }) {
    final exactTokens = RegExp(
      r'(?:^|[^\d.])([+-]?\d+(?:,\d{3})*(?:\.\d{1,2})?)(?=$|[^\d.])',
      multiLine: true,
    )
        .allMatches(rawText)
        .map((match) => match.group(1)!.replaceAll(',', ''))
        .toSet();
    final current = currentAmount?.abs();
    for (final candidate in candidates) {
      final normalized =
          candidate.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.+-]'), '');
      final parsed = double.tryParse(normalized)?.abs();
      if (parsed == null || parsed == 0 || parsed == current) continue;
      if (exactTokens.contains(normalized) ||
          exactTokens.contains('-$normalized') ||
          exactTokens.contains('+$normalized')) {
        return parsed;
      }
    }
    throw StateError('fixture_did_not_produce_alternate_amount_candidate');
  }

  @override
  bool operator ==(Object other) =>
      other is ShareBillingC2Fixture && other.fixtureId == fixtureId;

  @override
  int get hashCode => fixtureId.hashCode;
}
