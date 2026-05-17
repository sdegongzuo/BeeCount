import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/db.dart';
import '../../styles/tokens.dart';
import '../../utils/lru_cache.dart';
import '../../utils/account_type_utils.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../ui/ui.dart';

/// 账户选择器组件
/// 横滑标签形式，支持 LRU 排序
class AccountSelector extends ConsumerStatefulWidget {
  final int? selectedAccountId;
  final ValueChanged<int?> onAccountSelected;
  final int ledgerId;
  final bool allowNull;
  final Set<int> excludedAccountIds;
  final bool allowCreate;
  final ValueChanged<int>? onCreateAccount;
  final int refreshToken;

  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    required this.ledgerId,
    this.allowNull = true,
    this.excludedAccountIds = const {},
    this.allowCreate = false,
    this.onCreateAccount,
    this.refreshToken = 0,
  });

  @override
  ConsumerState<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends ConsumerState<AccountSelector> {
  List<Account> _accounts = [];
  List<int> _lruOrder = [];
  late LRUCache _lruCache;
  bool _isLoading = true;

  // 记录初始选中的账户ID，用于排序（不随点击变化）
  int? _initialSelectedAccountId;

  @override
  void initState() {
    super.initState();
    _initialSelectedAccountId = widget.selectedAccountId;
    _lruCache = LRUCache(key: 'account_lru_${widget.ledgerId}', maxSize: 20);
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant AccountSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    const setEquality = SetEquality<int>();
    if (oldWidget.ledgerId != widget.ledgerId ||
        oldWidget.refreshToken != widget.refreshToken ||
        !setEquality.equals(
          oldWidget.excludedAccountIds,
          widget.excludedAccountIds,
        )) {
      _initialSelectedAccountId = widget.selectedAccountId;
      _lruCache = LRUCache(key: 'account_lru_${widget.ledgerId}', maxSize: 20);
      _isLoading = true;
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final repo = ref.read(repositoryProvider);

      // 使用 provider 查询账本信息
      final ledger = await ref.read(ledgerByIdProvider(widget.ledgerId).future);
      if (ledger == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // 获取所有账户，然后过滤与当前账本币种相同的可交易账户
      final allAccounts = await repo.getAllAccounts();
      final accounts = allAccounts
          .where((a) =>
              a.currency == ledger.currency &&
              isTradableType(a.type) &&
              !widget.excludedAccountIds.contains(a.id))
          .toList();

      // 获取 LRU 排序
      final lruOrder = await _lruCache.getOrderedIds();

      logger.debug('AccountSelector', '加载账户完成，初始选中: $_initialSelectedAccountId, LRU顺序: $lruOrder');

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _lruOrder = lruOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 根据 LRU 排序账户
  /// 使用初始选中的账户ID进行排序，避免点击时立即重排
  List<Account> _getSortedAccounts() {
    if (_accounts.isEmpty) return [];

    final List<Account> sorted = [];

    // 将初始选中的账户放在第一个（如果存在）
    if (_initialSelectedAccountId != null) {
      final selected = _accounts.where((a) => a.id == _initialSelectedAccountId).firstOrNull;
      if (selected != null) {
        sorted.add(selected);
      }
    }

    // 按 LRU 顺序添加其他账户
    for (final id in _lruOrder) {
      final account = _accounts.where((a) => a.id == id && a.id != _initialSelectedAccountId).firstOrNull;
      if (account != null && !sorted.contains(account)) {
        sorted.add(account);
      }
    }

    // 添加未在 LRU 中的账户（按创建顺序）
    for (final account in _accounts) {
      if (!sorted.contains(account)) {
        sorted.add(account);
      }
    }

    return sorted;
  }

  void _onAccountTap(int? accountId) {
    logger.debug('AccountSelector', '点击账户: $accountId, 当前LRU顺序: $_lruOrder');
    widget.onAccountSelected(accountId);

    // 只记录使用，不立即更新排序（下次加载时才生效）
    if (accountId != null) {
      _lruCache.recordUsage(accountId);
      logger.debug('AccountSelector', '已记录使用，但不更新当前排序');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final sortedAccounts = _getSortedAccounts();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: sortedAccounts.length +
            (widget.allowNull ? 1 : 0) +
            (widget.allowCreate ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          // "无账户"永远在第一位
          if (widget.allowNull && index == 0) {
            final isSelected = widget.selectedAccountId == null;
            return _buildAccountChip(
              label: AppLocalizations.of(context).accountNone,
              isSelected: isSelected,
              onTap: () => _onAccountTap(null),
            );
          }

          // 其他账户从索引 1 开始
          final accountIndex = widget.allowNull ? index - 1 : index;
          if (accountIndex >= sortedAccounts.length) {
            return _buildAccountChip(
              label: '+ ${AppLocalizations.of(context).accountNewTitle}',
              isSelected: false,
              onTap: () async {
                final createdId = await _showQuickCreateAccountDialog();
                if (createdId != null) {
                  await _loadAccounts();
                  widget.onCreateAccount?.call(createdId);
                  widget.onAccountSelected(createdId);
                }
              },
            );
          }
          final account = sortedAccounts[accountIndex];
          final isSelected = widget.selectedAccountId == account.id;

          return _buildAccountChip(
            label: account.name,
            isSelected: isSelected,
            onTap: () => _onAccountTap(account.id),
          );
        },
      ),
    );
  }

  Future<int?> _showQuickCreateAccountDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.accountNewTitle),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.accountNameHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.accountNameRequired;
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          final ledger =
                              await ref.read(ledgerByIdProvider(widget.ledgerId).future);
                          final id = await ref.read(repositoryProvider).createAccount(
                                ledgerId: widget.ledgerId,
                                name: controller.text.trim(),
                                type: 'cash',
                                currency: ledger?.currency ?? 'CNY',
                              );
                          PostProcessor.sync(ref, ledgerId: widget.ledgerId);
                          if (context.mounted) {
                            Navigator.pop(context, id);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setDialogState(() => saving = false);
                            showToast(context, '${l10n.commonError}: $e');
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = ref.watch(primaryColorProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : BeeTokens.surfaceChip(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : BeeTokens.textSecondary(context),
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
