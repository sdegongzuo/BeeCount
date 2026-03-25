import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../providers.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../widgets/category_icon.dart';
import '../../utils/account_type_utils.dart';
import '../../providers/credit_card_providers.dart';
import '../../widgets/charts/balance_trend_chart.dart';
import '../../widgets/charts/account_category_pie_chart.dart';

// ============================================
// Providers
// ============================================

/// 分页交易状态
class AccountTransactionsPaginationState {
  final List<db.Transaction> transactions;
  final bool isLoading;
  final bool hasMore;

  const AccountTransactionsPaginationState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  AccountTransactionsPaginationState copyWith({
    List<db.Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
  }) {
    return AccountTransactionsPaginationState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class AccountTransactionsPaginationNotifier
    extends StateNotifier<AccountTransactionsPaginationState> {
  final Ref ref;
  final int accountId;
  static const _pageSize = 50;

  AccountTransactionsPaginationNotifier(this.ref, this.accountId)
      : super(const AccountTransactionsPaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions =
          await repo.getAccountTransactions(accountId, limit: _pageSize, offset: 0);
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions = await repo.getAccountTransactions(
        accountId,
        limit: _pageSize,
        offset: state.transactions.length,
      );
      state = state.copyWith(
        transactions: [...state.transactions, ...transactions],
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = const AccountTransactionsPaginationState(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions =
          await repo.getAccountTransactions(accountId, limit: _pageSize, offset: 0);
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final accountTransactionsPaginatedProvider = StateNotifierProvider.family
    .autoDispose<AccountTransactionsPaginationNotifier,
        AccountTransactionsPaginationState, int>(
  (ref, accountId) => AccountTransactionsPaginationNotifier(ref, accountId),
);

/// 余额趋势 Provider
final accountBalanceTrendProvider = FutureProvider.family
    .autoDispose<List<({DateTime date, double balance})>,
        ({int accountId, int days})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);
  final endDate = DateTime.now();
  final startDate = endDate.subtract(Duration(days: params.days));
  return repo.getAccountDailyBalances(
    params.accountId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// 分类统计 Provider
final accountCategoryStatsProvider = FutureProvider.family
    .autoDispose<List<({int? id, String name, String? icon, double total})>,
        ({int accountId, String type})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAccountCategoryStats(params.accountId, type: params.type);
});

// ============================================
// Page
// ============================================

/// 账户详情页面
class AccountDetailPage extends ConsumerStatefulWidget {
  final db.Account account;

  const AccountDetailPage({
    super.key,
    required this.account,
  });

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  final ScrollController _scrollController = ScrollController();
  int _trendDays = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(accountTransactionsPaginatedProvider(widget.account.id).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final statsAsync = ref.watch(accountStatsProvider(widget.account.id));
    final paginationState =
        ref.watch(accountTransactionsPaginatedProvider(widget.account.id));
    final currentLedgerAsync = ref.watch(currentLedgerProvider);
    final currencyCode = currentLedgerAsync.asData?.value?.currency ?? 'CNY';
    final categoriesAsync = ref.watch(categoriesProvider);

    // 趋势图数据
    final trendAsync = ref.watch(accountBalanceTrendProvider(
        (accountId: widget.account.id, days: _trendDays)));

    // 分类统计数据
    final expenseStatsAsync = ref.watch(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'expense')));
    final incomeStatsAsync = ref.watch(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'income')));

    final account = widget.account;
    final isDark = BeeTokens.isDark(context);
    final typeColor = getColorForAccountType(account.type, primaryColor);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // ======== Hero 渐变头部 ========
          PrimaryHeader(
            title: account.name,
            subtitle: getAccountTypeLabel(context, account.type),
            showBack: true,
            statusBarIconBrightness: Brightness.light,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        typeColor.withValues(alpha: 0.25),
                        typeColor.withValues(alpha: 0.1),
                      ]
                    : [typeColor, typeColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            content: ClipRect(
              child: Stack(
                children: [
                  // 装饰圆圈
                  Positioned(
                    right: -20,
                    top: -30,
                    child: Container(
                      width: 80.0.scaled(context, ref),
                      height: 80.0.scaled(context, ref),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? typeColor.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  // 统计行
                  statsAsync.when(
                    data: (stats) => Padding(
                      padding: EdgeInsets.only(
                        top: 4.0.scaled(context, ref),
                        bottom: 8.0.scaled(context, ref),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStatCell(
                              label: account.type == 'credit_card'
                                  ? l10n.creditCardOwed
                                  : l10n.accountBalance,
                              value: stats.balance,
                              currencyCode: currencyCode,
                              isDark: isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36.0.scaled(context, ref),
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: _HeroStatCell(
                              label: l10n.homeIncome,
                              value: stats.income,
                              currencyCode: currencyCode,
                              isDark: isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36.0.scaled(context, ref),
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: _HeroStatCell(
                              label: l10n.homeExpense,
                              value: stats.expense,
                              currencyCode: currencyCode,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 16.0.scaled(context, ref)),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 12.0.scaled(context, ref),
              ),
              children: [
                // 1. 元信息卡片（有值时显示）
                if (_hasMetadata(account)) ...[
                  _MetadataCard(account: account, typeColor: typeColor),
                  SizedBox(height: 8.0.scaled(context, ref)),
                ],

                // 2. 信用卡额度信息（仅信用卡显示）
                if (account.type == 'credit_card' &&
                    account.creditLimit != null) ...[
                  _CreditCardInfoCard(
                    account: account,
                    currencyCode: currencyCode,
                    primaryColor: primaryColor,
                    typeColor: typeColor,
                  ),
                  SizedBox(height: 8.0.scaled(context, ref)),
                ],

                // 3. 余额趋势图
                trendAsync.when(
                  data: (data) {
                    if (data.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        // 时段切换
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.0.scaled(context, ref)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _PeriodChip(
                                label: l10n.periodDays7,
                                isSelected: _trendDays == 7,
                                primaryColor: typeColor,
                                onTap: () => setState(() => _trendDays = 7),
                              ),
                              SizedBox(width: 8.0.scaled(context, ref)),
                              _PeriodChip(
                                label: l10n.periodDays30,
                                isSelected: _trendDays == 30,
                                primaryColor: typeColor,
                                onTap: () => setState(() => _trendDays = 30),
                              ),
                              SizedBox(width: 8.0.scaled(context, ref)),
                              _PeriodChip(
                                label: l10n.periodDays90,
                                isSelected: _trendDays == 90,
                                primaryColor: typeColor,
                                onTap: () => setState(() => _trendDays = 90),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4.0.scaled(context, ref)),
                        BalanceTrendChart(data: data),
                        SizedBox(height: 8.0.scaled(context, ref)),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // 4. 分类饼图
                expenseStatsAsync.when(
                  data: (expenseData) {
                    final incomeData =
                        incomeStatsAsync.asData?.value ?? [];
                    if (expenseData.isEmpty && incomeData.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        AccountCategoryPieChart(
                          expenseData: expenseData,
                          incomeData: incomeData,
                          accentColor: typeColor,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // 5. 交易列表（分页）
                _buildTransactionList(
                  context,
                  paginationState,
                  currencyCode,
                  primaryColor,
                  categoriesAsync.asData?.value ?? [],
                  l10n,
                  typeColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMetadata(db.Account account) {
    return (account.bankName != null && account.bankName!.isNotEmpty) ||
        (account.cardLastFour != null && account.cardLastFour!.isNotEmpty) ||
        (account.note != null && account.note!.isNotEmpty);
  }

  Widget _buildTransactionList(
    BuildContext context,
    AccountTransactionsPaginationState state,
    String currencyCode,
    Color primaryColor,
    List<db.Category> categories,
    AppLocalizations l10n,
    Color typeColor,
  ) {
    final transactions = state.transactions;

    if (transactions.isEmpty && !state.isLoading) {
      return SectionCard(
        child: Padding(
          padding: EdgeInsets.all(32.0.scaled(context, ref)),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48.0.scaled(context, ref),
                  color: BeeTokens.textTertiary(context),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                Text(
                  l10n.accountNoTransactions,
                  style: TextStyle(
                    fontSize: 14,
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12.0.scaled(context, ref)),
            child: Row(
              children: [
                Container(
                  width: 6.0.scaled(context, ref),
                  height: 6.0.scaled(context, ref),
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.0.scaled(context, ref)),
                Text(
                  l10n.accountTransactionHistory,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (transactions.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0.scaled(context, ref),
                      vertical: 2.0.scaled(context, ref),
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(10.0.scaled(context, ref)),
                    ),
                    child: Text(
                      '${transactions.length}${state.hasMore ? '+' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;

            return Column(
              children: [
                if (index > 0) BeeTokens.cardDivider(context),
                _TransactionTile(
                  transaction: tx,
                  currencyCode: currencyCode,
                  primaryColor: primaryColor,
                  ledgers:
                      ref.watch(ledgersStreamProvider).asData?.value ?? [],
                  categories: categories,
                  currentAccountId: widget.account.id,
                  onTap: () => _editTransaction(context, ref, tx),
                ),
              ],
            );
          }),
          // 加载指示器
          if (state.isLoading)
            Padding(
              padding: EdgeInsets.all(16.0.scaled(context, ref)),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!state.hasMore && transactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12.0.scaled(context, ref)),
              child: Center(
                child: Text(
                  l10n.accountNoMoreData,
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editTransaction(
      BuildContext context, WidgetRef ref, db.Transaction tx) async {
    final categoryAsync = tx.categoryId != null
        ? await ref.read(categoriesProvider.future)
        : null;
    final category = categoryAsync?.cast<db.Category?>().firstWhere(
          (c) => c?.id == tx.categoryId,
          orElse: () => null,
        );

    if (!context.mounted) return;
    await TransactionEditUtils.editTransaction(context, ref, tx, category);

    // 刷新数据
    ref.invalidate(accountStatsProvider(widget.account.id));
    ref
        .read(
            accountTransactionsPaginatedProvider(widget.account.id).notifier)
        .refresh();
    ref.invalidate(accountBalanceTrendProvider(
        (accountId: widget.account.id, days: _trendDays)));
    ref.invalidate(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'expense')));
    ref.invalidate(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'income')));
  }
}

// ============================================
// 元信息卡片
// ============================================

class _MetadataCard extends ConsumerWidget {
  final db.Account account;
  final Color typeColor;

  const _MetadataCard({required this.account, required this.typeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = BeeTokens.isDark(context);
    final accentColor =
        isDark ? typeColor.withValues(alpha: 0.6) : typeColor;

    return SectionCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BeeDimens.radius12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 3.0.scaled(context, ref),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12.0.scaled(context, ref)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountMetaInfo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                if (account.bankName != null && account.bankName!.isNotEmpty)
                  _MetadataRow(
                    icon: Icons.account_balance_outlined,
                    label: l10n.accountBankName,
                    value: account.bankName!,
                  ),
                if (account.cardLastFour != null &&
                    account.cardLastFour!.isNotEmpty)
                  _MetadataRow(
                    icon: Icons.credit_card_outlined,
                    label: l10n.accountCardLastFour,
                    value: '**** **** **** ${account.cardLastFour!}',
                    isCardNumber: true,
                  ),
                if (account.note != null && account.note!.isNotEmpty)
                  _MetadataRow(
                    icon: Icons.notes_outlined,
                    label: l10n.accountNote,
                    value: account.note!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCardNumber;

  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isCardNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: BeeTokens.iconSecondary(context)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: BeeTokens.textPrimary(context),
                fontFeatures: isCardNumber
                    ? const [FontFeature.tabularFigures()]
                    : null,
                letterSpacing: isCardNumber ? 1.5 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// 时段切换芯片
// ============================================

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : BeeTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                isSelected ? primaryColor : BeeTokens.textSecondary(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ============================================
// 信用卡额度信息卡片
// ============================================

class _CreditCardInfoCard extends ConsumerWidget {
  final db.Account account;
  final String currencyCode;
  final Color primaryColor;
  final Color typeColor;

  const _CreditCardInfoCard({
    required this.account,
    required this.currencyCode,
    required this.primaryColor,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usedAsync = ref.watch(creditCardUsedAmountProvider(account.id));
    final creditLimit = account.creditLimit ?? 0.0;
    final isDark = BeeTokens.isDark(context);
    final accentColor =
        isDark ? typeColor.withValues(alpha: 0.6) : typeColor;

    return SectionCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BeeDimens.radius12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 3.0.scaled(context, ref),
              ),
            ),
          ),
          child: usedAsync.when(
        data: (usedAmount) {
          final available = creditLimit - usedAmount;
          final usageRate = creditLimit > 0
              ? (usedAmount / creditLimit).clamp(0.0, 1.0)
              : 0.0;

          Color progressColor;
          if (usageRate < 0.5) {
            progressColor = Colors.green;
          } else if (usageRate < 0.8) {
            progressColor = Colors.orange;
          } else {
            progressColor = Colors.red;
          }

          return Padding(
            padding: EdgeInsets.all(12.0.scaled(context, ref)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(4.0.scaled(context, ref)),
                  child: LinearProgressIndicator(
                    value: usageRate,
                    backgroundColor: BeeTokens.border(context),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6.0.scaled(context, ref),
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: l10n.creditLimit,
                        value: creditLimit,
                        currencyCode: currencyCode,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40.0.scaled(context, ref),
                      color: BeeTokens.border(context),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: l10n.creditUsed,
                        value: usedAmount,
                        currencyCode: currencyCode,
                        color: progressColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40.0.scaled(context, ref),
                      color: BeeTokens.border(context),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: l10n.creditAvailable,
                        value: available,
                        currencyCode: currencyCode,
                        color: available >= 0
                            ? BeeTokens.incomeColor(context, ref)
                            : BeeTokens.error(context),
                      ),
                    ),
                  ],
                ),
                if (account.billingDay != null ||
                    account.paymentDueDay != null) ...[
                  SizedBox(height: 8.0.scaled(context, ref)),
                  Divider(color: BeeTokens.divider(context)),
                  SizedBox(height: 4.0.scaled(context, ref)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (account.billingDay != null)
                        Text(
                          '${l10n.billingDay}: ${l10n.dayOfMonth(account.billingDay!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                      if (account.paymentDueDay != null)
                        Text(
                          '${l10n.paymentDueDay}: ${l10n.dayOfMonth(account.paymentDueDay!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => Padding(
          padding: EdgeInsets.all(16.0.scaled(context, ref)),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
        ),
      ),
    );
  }
}

// ============================================
// Hero 统计单元格（头部用，白色文字）
// ============================================

class _HeroStatCell extends ConsumerWidget {
  final String label;
  final double value;
  final String currencyCode;
  final bool isDark;

  const _HeroStatCell({
    required this.label,
    required this.value,
    required this.currencyCode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8);

    return Column(
      children: [
        AmountText(
          value: value,
          signed: false,
          showCurrency: true,
          useCompactFormat: ref.watch(compactAmountProvider),
          currencyCode: currencyCode,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 4.0.scaled(context, ref)),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ============================================
// 统计单元格
// ============================================

class _StatCell extends ConsumerWidget {
  final String label;
  final double value;
  final String currencyCode;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.currencyCode,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        AmountText(
          value: value,
          signed: false,
          showCurrency: true,
          useCompactFormat: ref.watch(compactAmountProvider),
          currencyCode: currencyCode,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4.0.scaled(context, ref)),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: BeeTokens.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ============================================
// 交易列表项
// ============================================

class _TransactionTile extends ConsumerWidget {
  final db.Transaction transaction;
  final String currencyCode;
  final Color primaryColor;
  final List<db.Ledger> ledgers;
  final List<db.Category> categories;
  final VoidCallback onTap;
  final int? currentAccountId;

  const _TransactionTile({
    required this.transaction,
    required this.currencyCode,
    required this.primaryColor,
    required this.ledgers,
    required this.categories,
    required this.onTap,
    this.currentAccountId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color amountColor;
    final l10n = AppLocalizations.of(context);
    final transferCategory = ref.watch(transferCategoryProvider).valueOrNull;

    bool isTransferOut = false;
    bool isTransferIn = false;
    if (transaction.type == 'transfer' && currentAccountId != null) {
      isTransferOut = transaction.accountId == currentAccountId;
      isTransferIn = transaction.toAccountId == currentAccountId;
    }

    switch (transaction.type) {
      case 'income':
        amountColor = BeeTokens.incomeColor(context, ref);
        break;
      case 'expense':
        amountColor = BeeTokens.expenseColor(context, ref);
        break;
      case 'transfer':
        amountColor = isTransferOut
            ? BeeTokens.expenseColor(context, ref)
            : BeeTokens.incomeColor(context, ref);
        break;
      default:
        amountColor = BeeTokens.textPrimary(context);
    }

    final category = transaction.type == 'transfer'
        ? transferCategory
        : (transaction.categoryId != null
            ? categories.cast<db.Category?>().firstWhere(
                  (c) => c?.id == transaction.categoryId,
                  orElse: () => null,
                )
            : null);

    String displayTitle;
    String? displaySubtitle;

    if (transaction.type == 'transfer') {
      if (transaction.note?.isNotEmpty == true) {
        displayTitle = transaction.note!;
      } else {
        displayTitle = l10n.transferTitle;
      }

      if (isTransferOut && transaction.toAccountId != null) {
        final toAccountAsync =
            ref.watch(accountByIdProvider(transaction.toAccountId!));
        final toAccountName = toAccountAsync.value?.name;
        if (toAccountName != null) {
          displaySubtitle = '${l10n.transferToPrefix} $toAccountName';
        }
      } else if (isTransferIn && transaction.accountId != null) {
        final fromAccountAsync =
            ref.watch(accountByIdProvider(transaction.accountId!));
        final fromAccountName = fromAccountAsync.value?.name;
        if (fromAccountName != null) {
          displaySubtitle = '${l10n.transferFromPrefix} $fromAccountName';
        }
      }
    } else {
      if (transaction.note?.isNotEmpty == true) {
        displayTitle = transaction.note!;
      } else if (category != null) {
        displayTitle = category.name;
      } else {
        displayTitle = transaction.type == 'income'
            ? l10n.homeIncome
            : l10n.homeExpense;
      }
    }

    final ledger = ledgers.cast<db.Ledger?>().firstWhere(
          (l) => l?.id == transaction.ledgerId,
          orElse: () => null,
        );
    String ledgerName = ledger?.name ?? '';
    if (ledgerName == 'Default Ledger') {
      ledgerName = l10n.ledgersDefaultLedgerName;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12.0.scaled(context, ref),
          vertical: 12.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: CategoryIconWidget(
                category: category,
                size: 18,
              ),
            ),
            SizedBox(width: 12.0.scaled(context, ref)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: BeeTokens.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ledgerName.isNotEmpty) ...[
                        SizedBox(width: 6.0.scaled(context, ref)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.0.scaled(context, ref),
                            vertical: 2.0.scaled(context, ref),
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                4.0.scaled(context, ref)),
                          ),
                          child: Text(
                            ledgerName,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (displaySubtitle != null)
                    Padding(
                      padding:
                          EdgeInsets.only(top: 2.0.scaled(context, ref)),
                      child: Text(
                        displaySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        EdgeInsets.only(top: 2.0.scaled(context, ref)),
                    child: Text(
                      _formatDate(transaction.happenedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AmountText(
              value: transaction.type == 'expense'
                  ? -transaction.amount
                  : transaction.type == 'transfer'
                      ? (isTransferOut
                          ? -transaction.amount
                          : transaction.amount)
                      : transaction.amount,
              signed: true,
              showCurrency: false,
              currencyCode: currencyCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
