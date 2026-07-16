import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../providers/smart_billing_providers.dart';
import '../../providers/theme_providers.dart';
import '../../utils/notification_android.dart';
import '../../utils/notification_factory.dart';
import '../ai/ai_settings_page.dart';
import '../automation/auto_billing_settings_page.dart';
import 'shortcuts_guide_page.dart';
import 'billing_rule_update_page.dart';
import '../../l10n/app_localizations.dart';

/// Google Play 版本(CI 注入)。截屏自动记账依赖 READ_MEDIA_IMAGES,在 Google
/// Play 渠道被砍掉,这里用来隐藏入口。详见 release.yml 的临时 manifest 配置。
const _isGooglePlayBuild =
    bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);

/// 智能记账二级页面
class SmartBillingPage extends ConsumerWidget {
  const SmartBillingPage({super.key});

  String _attachmentFormatLabel(
    AppLocalizations l10n,
    SmartBillingAttachmentFormat format,
  ) {
    switch (format) {
      case SmartBillingAttachmentFormat.jpeg:
        return l10n.smartBillingAttachmentFormatJpeg;
      case SmartBillingAttachmentFormat.webp:
        return l10n.smartBillingAttachmentFormatWebp;
      case SmartBillingAttachmentFormat.avif:
        return l10n.smartBillingAttachmentFormatAvif;
    }
  }

  String _attachmentFormatDesc(
    AppLocalizations l10n,
    SmartBillingAttachmentFormat format,
  ) {
    switch (format) {
      case SmartBillingAttachmentFormat.jpeg:
        return l10n.smartBillingAttachmentFormatJpegDesc;
      case SmartBillingAttachmentFormat.webp:
        return l10n.smartBillingAttachmentFormatWebpDesc;
      case SmartBillingAttachmentFormat.avif:
        return l10n.smartBillingAttachmentFormatAvifDesc;
    }
  }

  Future<void> _showAttachmentFormatSheet(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(smartBillingAttachmentFormatProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.smartBillingAttachmentFormat,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              RadioGroup<SmartBillingAttachmentFormat>(
                groupValue: current,
                onChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(smartBillingAttachmentFormatProvider.notifier)
                      .state = value;
                  Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final format in SmartBillingAttachmentFormat.values)
                      RadioListTile<SmartBillingAttachmentFormat>(
                        value: format,
                        title: Text(_attachmentFormatLabel(l10n, format)),
                        subtitle: Text(_attachmentFormatDesc(l10n, format)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAttachmentQualitySheet(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    var current = ref.read(smartBillingAttachmentQualityProvider).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.smartBillingAttachmentQuality,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.smartBillingAttachmentQualityDesc,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: BeeTokens.textSecondary(context),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '${current.round()}%',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Slider(
                      value: current,
                      min: 5,
                      max: 100,
                      divisions: 95,
                      label: '${current.round()}%',
                      activeColor: ref.watch(primaryColorProvider),
                      onChanged: (value) {
                        setModalState(() => current = value);
                        ref
                            .read(
                                smartBillingAttachmentQualityProvider.notifier)
                            .state = value.round();
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('5%'),
                        Text('100%'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 显示功能引导弹窗
  void _showFeatureGuideDialog(
    BuildContext context,
    String title,
    String description,
    String aiRequirement,
    bool requiresAI, {
    bool showBackgroundRunGuide = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final shouldShowBackgroundRunGuide =
        Platform.isAndroid && showBackgroundRunGuide;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),
            if (shouldShowBackgroundRunGuide) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '分享图片记账需要允许蜜蜂记账在后台短时运行。ColorOS/OPlus 可能会冻结刚分享唤起的后台进程，请在系统设置中允许自启动、后台运行，并关闭电池优化。',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: requiresAI
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: requiresAI ? Colors.orange : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    requiresAI ? Icons.warning_amber : Icons.psychology,
                    color: requiresAI ? Colors.orange : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiRequirement,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            requiresAI ? Colors.orange[900] : Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.smartBillingGuideHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (shouldShowBackgroundRunGuide)
            TextButton(
              onPressed: () async {
                final androidUtil = NotificationFactory.getInstance()
                    as AndroidNotificationUtil;
                await androidUtil.requestIgnoreBatteryOptimizations();
              },
              child: const Text('关闭电池优化'),
            ),
          if (shouldShowBackgroundRunGuide)
            TextButton(
              onPressed: () async {
                final androidUtil = NotificationFactory.getInstance()
                    as AndroidNotificationUtil;
                await androidUtil.openBackgroundRunSettings();
              },
              child: const Text('后台运行设置'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonKnow),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.smartBillingPageTitle,
            subtitle: l10n.smartBillingPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: AppListTile(
                    leading: Icons.rule_folder_outlined,
                    title: '公共识别规则',
                    subtitle: '查看版本、检查安全更新或回滚',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BillingRuleUpdatePage(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // AI设置卡片
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // AI智能识别设置
                      AppListTile(
                        leading: Icons.psychology_outlined,
                        title: l10n.aiSettingsTitle,
                        subtitle: l10n.aiSettingsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AISettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 快速记账功能引导
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 图片记账
                      AppListTile(
                        leading: Icons.photo_library_outlined,
                        title: l10n.smartBillingImageBilling,
                        subtitle: l10n.smartBillingImageBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingImageBilling,
                            l10n.smartBillingImageBillingGuide,
                            l10n.smartBillingAIOptional,
                            false,
                            showBackgroundRunGuide: true,
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),

                      // 拍照记账
                      AppListTile(
                        leading: Icons.camera_alt_outlined,
                        title: l10n.smartBillingCameraBilling,
                        subtitle: l10n.smartBillingCameraBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingCameraBilling,
                            l10n.smartBillingCameraBillingGuide,
                            l10n.smartBillingAIOptional,
                            false,
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),

                      // 语音记账
                      AppListTile(
                        leading: Icons.mic_outlined,
                        title: l10n.smartBillingVoiceBilling,
                        subtitle: l10n.smartBillingVoiceBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingVoiceBilling,
                            l10n.smartBillingVoiceBillingGuide,
                            l10n.smartBillingAIRequired,
                            true,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 截图自动记账
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (!(Platform.isAndroid && _isGooglePlayBuild)) ...[
                        AppListTile(
                          leading: Icons.auto_fix_high,
                          title: l10n.autoScreenshotBilling,
                          subtitle: Platform.isAndroid
                              ? l10n.autoScreenshotBillingDesc
                              : l10n.autoScreenshotBillingIosDesc,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AutoBillingSettingsPage()),
                            );
                          },
                        ),
                        BeeTokens.cardDivider(context),
                      ],
                      // 快捷指令
                      AppListTile(
                        leading: Icons.app_shortcut,
                        title: l10n.shortcutsGuide,
                        subtitle: l10n.shortcutsGuideDesc,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ShortcutsGuidePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 智能记账通用设置
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 自动关联标签
                      AppListTile(
                        leading: Icons.label_outline,
                        title: l10n.smartBillingAutoTags,
                        subtitle: l10n.smartBillingAutoTagsDesc,
                        trailing: Switch.adaptive(
                          value: ref.watch(smartBillingAutoTagsProvider),
                          activeColor: ref.watch(primaryColorProvider),
                          onChanged: (value) {
                            ref
                                .read(smartBillingAutoTagsProvider.notifier)
                                .state = value;
                          },
                        ),
                      ),
                      BeeTokens.cardDivider(context),
                      // 自动添加附件
                      AppListTile(
                        leading: Icons.attachment_outlined,
                        title: l10n.smartBillingAutoAttachment,
                        subtitle: l10n.smartBillingAutoAttachmentDesc,
                        trailing: Switch.adaptive(
                          value: ref.watch(smartBillingAutoAttachmentProvider),
                          activeColor: ref.watch(primaryColorProvider),
                          onChanged: (value) {
                            ref
                                .read(
                                    smartBillingAutoAttachmentProvider.notifier)
                                .state = value;
                          },
                        ),
                      ),
                      BeeTokens.cardDivider(context),
                      AppListTile(
                        leading: Icons.image_outlined,
                        title: l10n.smartBillingAttachmentFormat,
                        subtitle: _attachmentFormatLabel(
                          l10n,
                          ref.watch(smartBillingAttachmentFormatProvider),
                        ),
                        enabled: ref.watch(smartBillingAutoAttachmentProvider),
                        onTap: () => _showAttachmentFormatSheet(context, ref),
                      ),
                      BeeTokens.cardDivider(context),
                      AppListTile(
                        leading: Icons.tune_outlined,
                        title: l10n.smartBillingAttachmentQuality,
                        subtitle:
                            '${ref.watch(smartBillingAttachmentQualityProvider)}% · ${l10n.smartBillingAttachmentQualityDesc}',
                        enabled: ref.watch(smartBillingAutoAttachmentProvider),
                        onTap: () => _showAttachmentQualitySheet(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
