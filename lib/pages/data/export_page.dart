import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/db.dart';
import '../../widgets/ui/ui.dart';
import '../../utils/category_utils.dart';

enum ExportLimitMode { all, first, last }

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});
  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool exporting = false;
  double progress = 0;
  String? savedPath;
  bool useDateRange = false;
  DateTime? startDate;
  DateTime? endDate;
  ExportLimitMode limitMode = ExportLimitMode.all;
  final TextEditingController limitController = TextEditingController(
    text: '100',
  );

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).exportTitle,
            showBack: true,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).exportDescription),
                    const SizedBox(height: 12),
                    _buildDateRangeOptions(context),
                    const SizedBox(height: 12),
                    _buildLimitOptions(context),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          exporting ? null : () => _export(repo, ledgerId),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: Text(
                        Platform.isIOS
                            ? AppLocalizations.of(context).exportButtonIOS
                            : AppLocalizations.of(context).exportButtonAndroid,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (exporting)
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress == 0 ? null : progress,
                            ),
                          ),
                        ],
                      ),
                    if (savedPath != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).exportSavedTo(savedPath!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitOptions(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isZh ? '导出条数' : 'Export count',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ExportLimitMode>(
            segments: [
              ButtonSegment(
                value: ExportLimitMode.all,
                icon: const Icon(Icons.all_inclusive),
                label: Text(isZh ? '全部' : 'All'),
              ),
              ButtonSegment(
                value: ExportLimitMode.first,
                icon: const Icon(Icons.vertical_align_top),
                label: Text(isZh ? '前 N 条' : 'First N'),
              ),
              ButtonSegment(
                value: ExportLimitMode.last,
                icon: const Icon(Icons.vertical_align_bottom),
                label: Text(isZh ? '后 N 条' : 'Last N'),
              ),
            ],
            selected: {limitMode},
            onSelectionChanged: exporting
                ? null
                : (selection) {
                    setState(() {
                      limitMode = selection.first;
                    });
                  },
          ),
        ),
        if (limitMode != ExportLimitMode.all) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 180,
            child: TextField(
              controller: limitController,
              enabled: !exporting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: isZh ? '条数' : 'Count',
                isDense: true,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateRangeOptions(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startText = startDate == null
        ? (isZh ? '开始日期' : 'Start date')
        : dateFormat.format(startDate!);
    final endText = endDate == null
        ? (isZh ? '结束日期' : 'End date')
        : dateFormat.format(endDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(isZh ? '按时间段导出' : 'Export by date range'),
          subtitle: Text(
            isZh ? '关闭时导出当前账本全部数据' : 'Off exports all data in this ledger',
          ),
          value: useDateRange,
          onChanged: exporting
              ? null
              : (value) {
                  setState(() {
                    useDateRange = value;
                  });
                },
        ),
        if (useDateRange)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exporting ? null : () => _pickDate(isStart: true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(startText, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exporting ? null : () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(endText, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate =
        isStart ? (startDate ?? endDate ?? now) : (endDate ?? startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        startDate = DateTime(picked.year, picked.month, picked.day);
        if (endDate != null && startDate!.isAfter(endDate!)) {
          endDate = startDate;
        }
      } else {
        endDate = DateTime(picked.year, picked.month, picked.day);
        if (startDate != null && endDate!.isBefore(startDate!)) {
          startDate = endDate;
        }
      }
    });
  }

  Future<void> _export(BaseRepository repo, int ledgerId) async {
    try {
      setState(() {
        exporting = true;
        progress = 0;
        savedPath = null;
      });
      String directory;
      bool shareAfter = false;
      if (Platform.isIOS) {
        // iOS: 写入应用文档目录，然后使用系统分享
        final docDir = await getApplicationDocumentsDirectory();
        directory = docDir.path;
        shareAfter = true;
      } else {
        // Android: 直接保存到公共 Download/BeeCount 目录
        const downloadPath = '/storage/emulated/0/Download/BeeCount';
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        directory = downloadPath;
      }

      // 获取交易和分类数据
      var transactionsWithCategory =
          await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
      if (useDateRange) {
        final rangeStart = startDate == null
            ? null
            : DateTime(startDate!.year, startDate!.month, startDate!.day);
        final rangeEnd = endDate == null
            ? null
            : DateTime(endDate!.year, endDate!.month, endDate!.day + 1);
        transactionsWithCategory = transactionsWithCategory.where((txWithCat) {
          final happenedAt = txWithCat.t.happenedAt.toLocal();
          if (rangeStart != null && happenedAt.isBefore(rangeStart)) {
            return false;
          }
          if (rangeEnd != null && !happenedAt.isBefore(rangeEnd)) {
            return false;
          }
          return true;
        }).toList();
      }
      transactionsWithCategory = _applyLimit(transactionsWithCategory);
      final total = transactionsWithCategory.length;
      final rows = <List<dynamic>>[];
      final l10n = AppLocalizations.of(context);
      rows.add([
        l10n.exportCsvHeaderType,
        l10n.exportCsvHeaderCategory,
        l10n.exportCsvHeaderSubCategory, // 二级分类名称
        l10n.exportCsvHeaderAmount,
        l10n.exportCsvHeaderAccount,
        l10n.exportCsvHeaderFromAccount, // 转出账户
        l10n.exportCsvHeaderToAccount, // 转入账户
        l10n.exportCsvHeaderPaymentMethod,
        l10n.exportCsvHeaderCounterparty,
        l10n.exportCsvHeaderNote,
        l10n.exportCsvHeaderTime,
        l10n.exportCsvHeaderTags,
        l10n.exportCsvHeaderAttachments, // 附件文件名（逗号分隔）
      ]);

      // 批量获取所有交易的标签
      final transactionIds =
          transactionsWithCategory.map((tx) => tx.t.id).toList();
      final tagsMap = await repo.getTagsForTransactions(transactionIds);

      // 批量获取所有交易的附件
      final attachmentsMap = await repo.getAttachmentsForTransactions(
        transactionIds,
      );

      // 缓存所有账户信息，避免重复查询
      final allAccounts = await repo.getAllAccounts();
      final accountMap = {for (var acc in allAccounts) acc.id: acc};

      // 缓存所有分类信息（包括父分类）
      final incomeCategories = await repo.getTopLevelCategories('income');
      final expenseCategories = await repo.getTopLevelCategories('expense');
      final allCategories = <int, Category>{};
      for (final cat in [...incomeCategories, ...expenseCategories]) {
        allCategories[cat.id] = cat;
        // 获取子分类
        final subCategories = await repo.getSubCategories(cat.id);
        for (final subCat in subCategories) {
          allCategories[subCat.id] = subCat;
        }
      }

      for (int i = 0; i < transactionsWithCategory.length; i++) {
        final txWithCat = transactionsWithCategory[i];
        final t = txWithCat.t;
        final c = txWithCat.category;
        final a = t.accountId != null ? accountMap[t.accountId] : null;
        // 使用完整的时间格式，包含年份和秒，添加前导空格增加列宽
        final timeStr = () {
          try {
            final localTime = t.happenedAt.toLocal();
            // 完整时间格式: YYYY-MM-DD HH:mm:ss，前面添加空格增加列宽
            return '  ${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}  ';
          } catch (e) {
            return '';
          }
        }();
        final typeStr = _getTypeDisplayName(t.type);

        // 对于转账类型，需要特殊处理账户信息
        String accountName;
        String fromAccountName;
        String toAccountName;
        String categoryName;
        String subCategoryName;

        if (t.type == 'transfer') {
          // 转账记录：账户列留空，填充转出账户和转入账户
          accountName = '';
          final fromAccount = accountMap[t.accountId];
          final toAccount = accountMap[t.toAccountId];
          fromAccountName = fromAccount?.name ?? '';
          toAccountName = toAccount?.name ?? '';
          categoryName = ''; // 转账没有分类
          subCategoryName = '';
        } else {
          // 收入或支出：正常填充账户列，转出转入账户留空
          accountName = a?.name ?? '';
          fromAccountName = '';
          toAccountName = '';

          // 处理分类信息
          if (c != null) {
            if (c.level == 2 && c.parentId != null) {
              // 二级分类：分类列填一级分类名称，二级分类列填当前分类名称
              final parentCategory = allCategories[c.parentId];
              categoryName = CategoryUtils.getDisplayName(
                parentCategory?.name,
                context,
              );
              subCategoryName = CategoryUtils.getDisplayName(c.name, context);
            } else {
              // 一级分类：分类列填当前分类，二级分类列留空
              categoryName = CategoryUtils.getDisplayName(c.name, context);
              subCategoryName = '';
            }
          } else {
            categoryName = '';
            subCategoryName = '';
          }
        }

        // 获取该交易的标签，用逗号分隔
        final transactionTags = tagsMap[t.id] ?? [];
        final tagsStr = transactionTags.map((tag) => tag.name).join(',');

        // 获取该交易的附件，用逗号分隔文件名
        final transactionAttachments = attachmentsMap[t.id] ?? [];
        final attachmentsStr =
            transactionAttachments.map((a) => a.fileName).join(',');

        rows.add([
          typeStr,
          categoryName,
          subCategoryName,
          t.amount.toStringAsFixed(2),
          accountName,
          fromAccountName,
          toAccountName,
          t.paymentMethod ?? '',
          t.counterparty ?? '',
          t.note ?? '',
          timeStr,
          tagsStr,
          attachmentsStr,
        ]);
        if (i % 50 == 0) {
          setState(() => progress = (i + 1) / (total == 0 ? 1 : total));
        }
      }

      final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(directory, 'beecount_$ts.csv');

      // 添加UTF-8 BOM标记，确保Excel正确识别中文编码
      const utf8Bom = '\uFEFF';
      await File(
        path,
      ).writeAsString(utf8Bom + csvStr, encoding: Encoding.getByName('utf-8')!);
      setState(() {
        savedPath = path;
        exporting = false;
        progress = 1;
      });
      if (!mounted) return;
      final l10nDialog = AppLocalizations.of(context);
      if (shareAfter) {
        // 触发分享面板
        await Share.shareXFiles([
          XFile(path),
        ], text: l10nDialog.exportShareText);
        await AppDialog.info(
          context,
          title: l10nDialog.exportSuccessTitle,
          message: l10nDialog.exportSuccessMessageIOS(path),
        );
      } else {
        await AppDialog.info(
          context,
          title: l10nDialog.exportSuccessTitle,
          message: l10nDialog.exportSuccessMessageAndroid(path),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      final l10nError = AppLocalizations.of(context);
      await AppDialog.error(
        context,
        title: l10nError.exportFailedTitle,
        message: e.toString(),
      );
    }
  }

  List<({Transaction t, Category? category})> _applyLimit(
    List<({Transaction t, Category? category})> transactions,
  ) {
    if (limitMode == ExportLimitMode.all) {
      return transactions;
    }

    final limit = int.tryParse(limitController.text.trim());
    if (limit == null || limit <= 0) {
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      throw Exception(
        isZh ? '导出条数必须大于 0' : 'Export count must be greater than 0',
      );
    }

    if (transactions.length <= limit) {
      return transactions;
    }

    if (limitMode == ExportLimitMode.first) {
      return transactions.take(limit).toList();
    }
    return transactions.skip(transactions.length - limit).toList();
  }

  /// 将英文类型转换为中文显示名称
  String _getTypeDisplayName(String type) {
    final l10nType = AppLocalizations.of(context);
    switch (type) {
      case 'income':
        return l10nType.exportTypeIncome;
      case 'expense':
        return l10nType.exportTypeExpense;
      case 'transfer':
        return l10nType.exportTypeTransfer;
      default:
        return type; // 兜底返回原始值
    }
  }
}
