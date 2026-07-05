import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SmartBillingAttachmentFormat {
  jpeg('jpeg'),
  webp('webp'),
  avif('avif');

  const SmartBillingAttachmentFormat(this.storageKey);

  final String storageKey;

  static SmartBillingAttachmentFormat fromStorageKey(String? value) {
    return SmartBillingAttachmentFormat.values.firstWhere(
      (format) => format.storageKey == value,
      orElse: () => SmartBillingAttachmentFormat.jpeg,
    );
  }
}

/// 智能记账自动关联标签开关（默认开启）
final smartBillingAutoTagsProvider = StateProvider<bool>((ref) => true);

/// 智能记账自动添加附件开关（默认开启）
final smartBillingAutoAttachmentProvider = StateProvider<bool>((ref) => true);

/// 智能记账自动附件保存格式（默认沿用 JPEG 压缩）
final smartBillingAttachmentFormatProvider =
    StateProvider<SmartBillingAttachmentFormat>(
        (ref) => SmartBillingAttachmentFormat.jpeg);

/// 智能记账自动附件图片质量（默认 80）
final smartBillingAttachmentQualityProvider = StateProvider<int>((ref) => 80);

/// 智能记账自动关联标签持久化初始化
final smartBillingAutoTagsInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('smartBillingAutoTags');
  if (saved != null) {
    ref.read(smartBillingAutoTagsProvider.notifier).state = saved;
  }
  ref.listen<bool>(smartBillingAutoTagsProvider, (prev, next) async {
    await prefs.setBool('smartBillingAutoTags', next);
  });
});

/// 智能记账自动添加附件持久化初始化
final smartBillingAutoAttachmentInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('smartBillingAutoAttachment');
  if (saved != null) {
    ref.read(smartBillingAutoAttachmentProvider.notifier).state = saved;
  }
  ref.listen<bool>(smartBillingAutoAttachmentProvider, (prev, next) async {
    await prefs.setBool('smartBillingAutoAttachment', next);
  });
});

/// 智能记账自动附件保存格式持久化初始化
final smartBillingAttachmentFormatInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('smartBillingAttachmentFormat');
  ref.read(smartBillingAttachmentFormatProvider.notifier).state =
      SmartBillingAttachmentFormat.fromStorageKey(saved);
  ref.listen<SmartBillingAttachmentFormat>(smartBillingAttachmentFormatProvider,
      (prev, next) async {
    await prefs.setString('smartBillingAttachmentFormat', next.storageKey);
  });
});

/// 智能记账自动附件图片质量持久化初始化
final smartBillingAttachmentQualityInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('smartBillingAttachmentQuality');
  if (saved != null) {
    ref.read(smartBillingAttachmentQualityProvider.notifier).state =
        saved.clamp(5, 100);
  }
  ref.listen<int>(smartBillingAttachmentQualityProvider, (prev, next) async {
    await prefs.setInt('smartBillingAttachmentQuality', next.clamp(5, 100));
  });
});
