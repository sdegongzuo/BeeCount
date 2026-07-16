import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/billing/pending_bill_confirmation_service.dart';
import '../../services/billing/rules/personal_rule_lifecycle_service.dart';

class PendingBillConfirmationPage extends StatefulWidget {
  final int jobId;
  final PendingBillConfirmationService service;

  const PendingBillConfirmationPage({
    super.key,
    required this.jobId,
    required this.service,
  });

  @override
  State<PendingBillConfirmationPage> createState() =>
      _PendingBillConfirmationPageState();
}

class _PendingBillConfirmationPageState
    extends State<PendingBillConfirmationPage> {
  final _amount = TextEditingController();
  final _time = TextEditingController();
  final _supplement = TextEditingController();
  PendingBillDraft? _draft;
  bool _rememberExtractionCorrections = false;
  bool _rememberCategoryRule = false;
  bool _rememberNotePreference = false;
  int? _categoryId;
  bool _categoryRuleGlobal = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final draft = await widget.service.loadDraft(widget.jobId);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _amount.text = draft?.candidate.amount?.toStringAsFixed(2) ?? '';
      _time.text = _formatTime(draft?.candidate.time);
      _categoryId = draft?.candidate.suggestedCategoryId;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _time.dispose();
    _supplement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pendingBillTitle)),
      body: _draft == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 180,
                    child: Image.file(
                      File(_draft!.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0x11000000),
                        child:
                            Center(child: Icon(Icons.receipt_long, size: 48)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l10n.pendingBillEvidenceSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('amountField'),
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.pendingBillAmount,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('timeField'),
                  controller: _time,
                  decoration: InputDecoration(
                    labelText: l10n.pendingBillTime,
                    hintText: '2026-07-12 10:30',
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  key: const Key('rememberExtractionCorrections'),
                  value: _rememberExtractionCorrections,
                  title: const Text('记住金额和时间修正'),
                  onChanged: (value) => setState(
                    () => _rememberExtractionCorrections = value,
                  ),
                ),
                const SizedBox(height: 20),
                if (_draft!.categories.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    key: const Key('categoryField'),
                    initialValue: _draft!.categories
                            .any((category) => category.id == _categoryId)
                        ? _categoryId
                        : null,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                    ),
                    items: _draft!.categories
                        .map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  SwitchListTile(
                    key: const Key('rememberCategoryRule'),
                    value: _rememberCategoryRule,
                    title: const Text('记住分类'),
                    onChanged: (value) => setState(() {
                      _rememberCategoryRule = value;
                      if (!value) _categoryRuleGlobal = false;
                    }),
                  ),
                  if (_rememberCategoryRule && _categoryId != null)
                    SwitchListTile(
                      key: const Key('globalCategoryRule'),
                      value: _categoryRuleGlobal,
                      title: const Text('应用到所有账本'),
                      subtitle: const Text('关闭时只记住当前账本'),
                      onChanged: (value) =>
                          setState(() => _categoryRuleGlobal = value),
                    ),
                  const SizedBox(height: 12),
                ],
                Text(l10n.pendingBillSupplementSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('supplementField'),
                  controller: _supplement,
                  decoration: InputDecoration(
                    hintText: l10n.pendingBillSupplementHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  key: const Key('rememberNotePreference'),
                  value: _rememberNotePreference,
                  title: const Text('记住补充备注'),
                  onChanged: (value) => setState(
                    () => _rememberNotePreference = value,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _confirm,
                  child: Text(l10n.pendingBillConfirm),
                ),
              ],
            ),
    );
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amount.text.trim());
    final time = _parseTime(_time.text.trim());
    if (amount == null || amount <= 0 || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).pendingBillInvalid)),
      );
      return;
    }
    if (_rememberCategoryRule && _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择分类，再开启“记住分类”')),
      );
      return;
    }
    if (_draft?.ledgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此历史账单缺少账本信息，无法安全创建')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await widget.service.confirm(
        jobId: widget.jobId,
        amount: amount,
        time: time,
        supplementalNote: _supplement.text,
        rememberExtractionCorrections: _rememberExtractionCorrections,
        rememberCategoryRule: _rememberCategoryRule,
        rememberNotePreference: _rememberNotePreference,
        categoryId: _categoryId,
        categoryRuleGlobal: _categoryRuleGlobal,
      );
      if (!mounted) return;
      final enabled = result.ruleResults
          .where((item) => item.status == PersonalRuleLifecycleStatus.enabled)
          .length;
      final l10n = AppLocalizations.of(context);
      final message = result.learningErrors.isNotEmpty
          ? '账单已创建，但部分记忆未完成：${result.learningErrors.map(_learningErrorText).join('；')}'
          : enabled > 0
              ? l10n.pendingBillRuleEnabled(enabled)
              : result.ruleResults.any((item) =>
                      item.status == PersonalRuleLifecycleStatus.conflict)
                  ? l10n.pendingBillRuleConflict
                  : result.ruleResults.any((item) =>
                          item.status ==
                          PersonalRuleLifecycleStatus.regressionRejected)
                      ? l10n.pendingBillRuleRejected
                      : result.ruleResults.isNotEmpty
                          ? l10n.pendingBillRulePending
                          : l10n.pendingBillCreated;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(result);
    } on PendingBillConfirmationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_confirmationErrorText(error.code))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _learningErrorText(PendingBillLearningError error) =>
    switch (error.reason) {
      PendingBillLearningReason.sourceInfoInvalid => '图片来源信息已损坏，未学习提取修正',
      PendingBillLearningReason.extractionCorrectionFailed => '提取修正保存失败',
      PendingBillLearningReason.categoryRuleFailed => '分类规则保存失败',
      PendingBillLearningReason.notePreferenceFailed => '备注偏好保存失败',
    };

String _confirmationErrorText(PendingBillConfirmationErrorCode code) =>
    switch (code) {
      PendingBillConfirmationErrorCode.billingJobNotAwaitingConfirmation =>
        '此账单已处理或不再等待确认',
      PendingBillConfirmationErrorCode.billingJobResultMissing =>
        '账单识别结果缺失，请重新分享图片',
      PendingBillConfirmationErrorCode.billingJobLedgerMissing =>
        '此历史账单缺少账本信息，无法安全创建',
      PendingBillConfirmationErrorCode.rememberedCategoryRequired =>
        '请先选择分类，再开启“记住分类”',
    };

String _formatTime(DateTime? value) => value == null
    ? ''
    : '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

DateTime? _parseTime(String value) =>
    DateTime.tryParse(value.replaceFirst(' ', 'T'));
