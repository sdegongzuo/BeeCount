import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/billing_rule_update_providers.dart';
import '../../services/billing/rules/billing_rule_activation_journal.dart';
import '../../services/billing/rules/billing_rule_update_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/biz/biz.dart';

class BillingRuleUpdatePage extends ConsumerStatefulWidget {
  const BillingRuleUpdatePage({super.key});

  @override
  ConsumerState<BillingRuleUpdatePage> createState() =>
      _BillingRuleUpdatePageState();
}

class _BillingRuleUpdatePageState extends ConsumerState<BillingRuleUpdatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(billingRuleUpdateControllerProvider.notifier)
          .refreshDiagnostics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingRuleUpdateControllerProvider);
    final diagnostics = state.diagnostics;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(title: const Text('公共识别规则')),
      body: RefreshIndicator(
        onRefresh: ref
            .read(billingRuleUpdateControllerProvider.notifier)
            .refreshDiagnostics,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _statusRow(
                    context,
                    '更新功能',
                    state.updateEnabled ? '已启用' : '未启用',
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '当前规则版本',
                    diagnostics?.activeVersion ?? '正在读取',
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '可回滚版本',
                    diagnostics?.previousVersion ?? '无',
                  ),
                  if (state.manifestHost != null) ...[
                    BeeTokens.cardDivider(context),
                    _statusRow(context, '更新来源', state.manifestHost!),
                  ],
                ],
              ),
            ),
            if (state.disabledReason != null) ...[
              const SizedBox(height: 12),
              _messageCard(
                context,
                icon: Icons.info_outline,
                text: state.disabledReason!,
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _messageCard(
                context,
                icon: Icons.error_outline,
                text: state.error!,
                isError: true,
              ),
            ],
            if (state.lastResult != null) ...[
              const SizedBox(height: 12),
              _messageCard(
                context,
                icon: _isFailure(state.lastResult!.status)
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                text: _resultText(state.lastResult!),
                isError: _isFailure(state.lastResult!.status),
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListTile(
                    leading: Icons.sync,
                    title: '立即检查更新',
                    subtitle: state.updateEnabled
                        ? '下载后先通过结构、黄金样本和本机个人样本回归'
                        : '需要在构建时配置可信 HTTPS manifest',
                    enabled: !state.busy && state.updateEnabled,
                    onTap: () => ref
                        .read(billingRuleUpdateControllerProvider.notifier)
                        .checkNow(),
                  ),
                  BeeTokens.cardDivider(context),
                  AppListTile(
                    leading: Icons.restore,
                    title: '回滚到上一版',
                    subtitle: diagnostics?.canRollback == true
                        ? '上一版也会重新通过完整安全门禁后才启用'
                        : '没有可验证的上一版规则',
                    enabled: !state.busy && diagnostics?.canRollback == true,
                    onTap: () => _confirmRollback(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _statusRow(
                    context,
                    '最近操作',
                    _operationText(diagnostics?.operation),
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '状态机阶段',
                    diagnostics?.journalState?.name ?? '无记录',
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '磁盘状态',
                    diagnostics?.diskStateVerified == false
                        ? '验证失败，已禁止回滚'
                        : '已验证',
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '最近尝试',
                    _timeText(diagnostics?.lastAttemptAt),
                  ),
                  BeeTokens.cardDivider(context),
                  _statusRow(
                    context,
                    '最近成功',
                    _timeText(diagnostics?.lastSuccessAt),
                  ),
                  if (diagnostics?.lastCheckStatus != null) ...[
                    BeeTokens.cardDivider(context),
                    _statusRow(
                      context,
                      '最近结果',
                      diagnostics!.lastCheckStatus!.name,
                    ),
                  ],
                  if (diagnostics?.lastCheckVersion != null) ...[
                    BeeTokens.cardDivider(context),
                    _statusRow(
                      context,
                      '检查版本',
                      diagnostics!.lastCheckVersion!,
                    ),
                  ],
                  if (diagnostics?.lastCheckAt != null) ...[
                    BeeTokens.cardDivider(context),
                    _statusRow(
                      context,
                      '结果时间',
                      _timeText(diagnostics!.lastCheckAt),
                    ),
                  ],
                  if (diagnostics?.stableDiagnostic != null) ...[
                    BeeTokens.cardDivider(context),
                    _statusRow(
                      context,
                      '持久诊断',
                      diagnostics!.stableDiagnostic!,
                    ),
                  ],
                ],
              ),
            ),
            if (state.busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(child: Text(_actionText(state.action))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRollback(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认回滚公共规则？'),
        content: const Text('只影响之后处理的图片，不会修改已经创建的账单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('安全回滚'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(billingRuleUpdateControllerProvider.notifier).rollback();
    }
  }
}

Widget _statusRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(color: BeeTokens.textSecondary(context)),
          ),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

Widget _messageCard(
  BuildContext context, {
  required IconData icon,
  required String text,
  bool isError = false,
}) {
  final color = isError
      ? Theme.of(context).colorScheme.error
      : Theme.of(context).colorScheme.primary;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String _timeText(DateTime? value) {
  if (value == null) return '无';
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _operationText(BillingRuleActivationOperation? operation) {
  switch (operation) {
    case BillingRuleActivationOperation.update:
      return '规则更新';
    case BillingRuleActivationOperation.rollback:
      return '安全回滚';
    case null:
      return '无记录';
  }
}

String _actionText(BillingRuleUpdateAction? action) {
  switch (action) {
    case BillingRuleUpdateAction.automaticCheck:
      return '正在执行每日安全检查';
    case BillingRuleUpdateAction.manualCheck:
      return '正在检查并验证候选规则';
    case BillingRuleUpdateAction.rollback:
      return '正在验证并回滚';
    case BillingRuleUpdateAction.initialize:
    case null:
      return '正在读取规则状态';
  }
}

bool _isFailure(BillingRuleUpdateStatus status) {
  return switch (status) {
    BillingRuleUpdateStatus.hashMismatch ||
    BillingRuleUpdateStatus.invalidManifest ||
    BillingRuleUpdateStatus.invalidRulePackage ||
    BillingRuleUpdateStatus.smokeTestFailed ||
    BillingRuleUpdateStatus.goldenEvaluationFailed ||
    BillingRuleUpdateStatus.personalRegressionFailed ||
    BillingRuleUpdateStatus.securityPolicyRejected ||
    BillingRuleUpdateStatus.incompatibleAppVersion ||
    BillingRuleUpdateStatus.responseTooLarge ||
    BillingRuleUpdateStatus.timedOut ||
    BillingRuleUpdateStatus.rollbackUnavailable ||
    BillingRuleUpdateStatus.failed =>
      true,
    _ => false,
  };
}

String _resultText(BillingRuleUpdateResult result) {
  final base = switch (result.status) {
    BillingRuleUpdateStatus.disabled => '远程规则更新未启用',
    BillingRuleUpdateStatus.activated => '新规则已安全启用，下一张图片立即生效',
    BillingRuleUpdateStatus.alreadyLatest => '当前已经是最新规则',
    BillingRuleUpdateStatus.notDue => '尚未到下一次自动检查时间',
    BillingRuleUpdateStatus.securityPolicyRejected => '更新来源未通过安全策略',
    BillingRuleUpdateStatus.incompatibleAppVersion => '规则需要更高版本的 App',
    BillingRuleUpdateStatus.responseTooLarge => '下载内容超过安全上限',
    BillingRuleUpdateStatus.timedOut => '规则更新请求超时',
    BillingRuleUpdateStatus.hashMismatch => '规则包校验失败，已继续使用旧版',
    BillingRuleUpdateStatus.invalidManifest => '更新清单无效，已继续使用旧版',
    BillingRuleUpdateStatus.invalidRulePackage => '规则包无效，已继续使用旧版',
    BillingRuleUpdateStatus.smokeTestFailed => '规则基础验证失败，已继续使用旧版',
    BillingRuleUpdateStatus.goldenEvaluationFailed => '黄金样本回归失败，已继续使用旧版',
    BillingRuleUpdateStatus.personalRegressionFailed => '本机个人样本回归失败，已继续使用旧版',
    BillingRuleUpdateStatus.rolledBack => '已安全回滚，下一张图片立即使用上一版',
    BillingRuleUpdateStatus.rollbackUnavailable => '没有可安全回滚的上一版',
    BillingRuleUpdateStatus.recovered => '已恢复上次中断的规则操作',
    BillingRuleUpdateStatus.failed => '规则操作失败，已继续使用安全快照',
  };
  return base;
}
