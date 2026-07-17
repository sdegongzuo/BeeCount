import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/billing/pending_transaction_classification_service.dart';

/// 把数据库附件文件名解析为设备上的可读取路径。
typedef AttachmentPathResolver = Future<String> Function(String fileName);

/// 对已成功创建、但分类证据不足的图片账单进行轻量补正。
class PendingTransactionClassificationPage extends StatefulWidget {
  /// 创建指定交易的待分类补正页面。
  const PendingTransactionClassificationPage({
    super.key,
    required this.ledgerId,
    required this.transactionId,
    required this.service,
    required this.resolveAttachmentPath,
  });

  /// 交易创建时所属的账本，不随当前账本切换而改变。
  final int ledgerId;

  /// 需要补正分类的交易 ID。
  final int transactionId;

  /// 读取证据并原子确认分类的领域服务。
  final PendingTransactionClassificationService service;

  /// 解析图片证据路径的设备边界。
  final AttachmentPathResolver resolveAttachmentPath;

  @override
  State<PendingTransactionClassificationPage> createState() =>
      _PendingTransactionClassificationPageState();
}

class _PendingTransactionClassificationPageState
    extends State<PendingTransactionClassificationPage> {
  PendingTransactionClassificationDraft? _draft;
  int? _categoryId;
  ClassificationMemoryScope? _scope;
  bool _saving = false;
  bool _missing = false;
  bool _loading = true;
  bool _loadFailed = false;
  final GlobalKey _scopeSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final draft = await widget.service.loadDraft(
        ledgerId: widget.ledgerId,
        transactionId: widget.transactionId,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _missing = draft == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待分类账单')),
      body: _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('账单加载失败，请稍后重试'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('retryClassificationLoad'),
                    onPressed: _load,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _missing
                  ? const Center(child: Text('此账单已完成分类或已不存在'))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_draft!.attachments.isNotEmpty) ...[
                              Text('图片证据',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: FutureBuilder<String>(
                                  future: widget.resolveAttachmentPath(
                                      _draft!.attachments.first.fileName),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError ||
                                        !snapshot.hasData) {
                                      return const _AttachmentPlaceholder();
                                    }
                                    return Image.file(
                                      File(snapshot.data!),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const _AttachmentPlaceholder(),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Text('结构化摘要',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_draft!.structuredSummary?.trim().isNotEmpty ==
                                    true
                                ? _draft!.structuredSummary!
                                : '暂无可验证的摘要'),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: _EvidenceTile(
                                      label: '金额',
                                      value:
                                          '¥${_draft!.transaction.amount.toStringAsFixed(2)}')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _EvidenceTile(
                                      label: '时间',
                                      value: _formatTime(
                                          _draft!.transaction.happenedAt))),
                            ]),
                            const SizedBox(height: 24),
                            Text('选择分类',
                                style: Theme.of(context).textTheme.titleMedium),
                            RadioGroup<int>(
                              groupValue: _categoryId,
                              onChanged: _selectCategory,
                              child: Column(
                                children: _draft!.categories
                                    .map((category) => RadioListTile<int>(
                                          value: category.id,
                                          title: Text(category.name),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('这次选择如何生效',
                                key: _scopeSectionKey,
                                style: Theme.of(context).textTheme.titleMedium),
                            RadioGroup<ClassificationMemoryScope>(
                              groupValue: _scope,
                              onChanged: (value) =>
                                  setState(() => _scope = value),
                              child: Column(
                                children: ClassificationMemoryScope.values
                                    .map((scope) => RadioListTile<
                                            ClassificationMemoryScope>(
                                          key: Key(
                                              'classificationScope-${scope.name}'),
                                          value: scope,
                                          title: Text(_scopeText(scope)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('confirmClassification'),
                              onPressed: _saving ? null : _confirm,
                              child: const Text('确认分类'),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  void _selectCategory(int? value) {
    setState(() => _categoryId = value);
    if (value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealScopeSection();
      });
    }
  }

  void _revealScopeSection() {
    if (!mounted) return;
    final scopeContext = _scopeSectionKey.currentContext;
    if (scopeContext != null) {
      Scrollable.ensureVisible(
        scopeContext,
        alignment: 0.05,
      );
    }
  }

  Future<void> _confirm() async {
    if (_categoryId == null) {
      _showMessage('请先选择分类');
      return;
    }
    if (_scope == null) {
      _showMessage('请选择这次分类是否需要记住');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.confirmClassification(
        ledgerId: widget.ledgerId,
        transactionId: widget.transactionId,
        categoryId: _categoryId!,
        memoryScope: _scope!,
      );
      if (!mounted) return;
      _showMessage('分类已更新');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(_classificationErrorText(error.message));
    } catch (_) {
      if (!mounted) return;
      _showMessage('分类更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0x11000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 48),
              SizedBox(height: 8),
              Text('图片暂时无法显示'),
            ],
          ),
        ),
      );
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label), const SizedBox(height: 4), Text(value)],
          ),
        ),
      );
}

String _scopeText(ClassificationMemoryScope scope) => switch (scope) {
      ClassificationMemoryScope.currentTransaction => '仅修正本次账单',
      ClassificationMemoryScope.currentLedger => '记住到当前账本',
      ClassificationMemoryScope.global => '记住到所有账本',
    };

String _classificationErrorText(String code) => switch (code) {
      'transaction_not_pending_classification' => '此账单已完成分类或已不存在',
      'classification_category_not_available' => '所选分类已不可用，请重新选择',
      'classification_rule_evidence_missing' => '缺少可验证的商户证据，无法记住规则',
      'classification_category_sync_id_missing' => '分类尚未同步完成，请稍后重试',
      _ => '分类更新失败，请稍后重试',
    };

String _formatTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
