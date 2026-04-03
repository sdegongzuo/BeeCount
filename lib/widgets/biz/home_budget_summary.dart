import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/budget_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/budget_providers.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../pages/budget/budget_page.dart';

/// 首页预算进度摘要
/// - 开关关闭：不显示
/// - 有预算：图标 + "本月预算" + 进度条 + 百分比 + 箭头
/// - 无预算：图标 + "设置预算，掌控开支" + 关闭按钮 + 箭头
class HomeBudgetSummary extends ConsumerWidget {
  const HomeBudgetSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(homeBudgetCardEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final overviewAsync = ref.watch(budgetOverviewProvider);

    return overviewAsync.when(
      data: (overview) {
        if (overview == null || overview.totalBudget == null) {
          return const _BudgetSetupHint();
        }
        return _BudgetBar(usage: overview.totalBudget!);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 无预算时的设置提示（带关闭按钮）
class _BudgetSetupHint extends ConsumerWidget {
  const _BudgetSetupHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = BeeTokens.isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.pie_chart_outline_rounded,
                  size: 18, color: primaryColor),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetPage()),
                );
              },
              child: Text(
                l10n.homeBudgetSetup,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ),
          // 关闭按钮 — 关闭后不再显示预算卡片
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(homeBudgetCardEnabledProvider.notifier).toggle(false);
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 有预算时的进度条
class _BudgetBar extends ConsumerWidget {
  final BudgetUsage usage;
  const _BudgetBar({required this.usage});

  Color _progressColor(double rate) {
    if (rate >= 1.0) return const Color(0xFFB71C1C);
    if (rate >= 0.9) return const Color(0xFFD32F2F);
    if (rate >= 0.7) return const Color(0xFFF57C00);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = BeeTokens.isDark(context);
    final rate = usage.rate.clamp(0.0, 1.5);
    final displayRate = (usage.rate * 100).toInt();
    final color = _progressColor(usage.rate);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              l10n.homeBudgetMonthly,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$displayRate%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
