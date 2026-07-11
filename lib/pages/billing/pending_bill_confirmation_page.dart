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
  bool _remember = false;
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
                const SizedBox(height: 20),
                Text(l10n.pendingBillSupplementSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _supplement,
                  decoration: InputDecoration(
                    hintText: l10n.pendingBillSupplementHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<bool>(
                  groupValue: _remember,
                  onChanged: (value) {
                    if (value != null) setState(() => _remember = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: false,
                        title: Text(l10n.pendingBillCurrentOnly),
                      ),
                      RadioListTile<bool>(
                        value: true,
                        title: Text(l10n.pendingBillRemember),
                      ),
                    ],
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
    setState(() => _saving = true);
    try {
      final result = await widget.service.confirm(
        jobId: widget.jobId,
        amount: amount,
        time: time,
        supplementalNote: _supplement.text,
        rememberForSimilarBills: _remember,
      );
      if (!mounted) return;
      final enabled = result.ruleResults
          .where((item) => item.status == PersonalRuleLifecycleStatus.enabled)
          .length;
      final l10n = AppLocalizations.of(context);
      final message = enabled > 0
          ? l10n.pendingBillRuleEnabled(enabled)
          : result.ruleResults.any(
                  (item) => item.status == PersonalRuleLifecycleStatus.conflict)
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _formatTime(DateTime? value) => value == null
    ? ''
    : '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

DateTime? _parseTime(String value) =>
    DateTime.tryParse(value.replaceFirst(' ', 'T'));
