import 'package:flutter/material.dart';

import '../../services/billing/rules/personal_rule_sync_repository.dart';
import '../../services/billing/rules/personal_rule_sync_service.dart';
import '../../styles/tokens.dart';

class PersonalRuleConflictsPage extends StatefulWidget {
  final PersonalRuleSyncRepository repository;

  const PersonalRuleConflictsPage({
    required this.repository,
    super.key,
  });

  @override
  State<PersonalRuleConflictsPage> createState() =>
      _PersonalRuleConflictsPageState();
}

class _PersonalRuleConflictsPageState extends State<PersonalRuleConflictsPage> {
  late Stream<List<PersonalRuleSyncConflict>> _conflicts;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _conflicts = widget.repository.watchConflicts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(title: const Text('个人规则冲突')),
      body: StreamBuilder<List<PersonalRuleSyncConflict>>(
        stream: _conflicts,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _centerMessage('读取冲突失败，请稍后重试');
          }
          final conflicts = snapshot.data ?? const [];
          if (conflicts.isEmpty) {
            return _centerMessage('当前没有待解决冲突');
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await widget.repository.listConflicts();
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conflicts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _conflictCard(conflicts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _conflictCard(PersonalRuleSyncConflict conflict) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _kindText(conflict.kind),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('匹配条件：${conflict.conditionKey}'),
            Text('作用范围：${_scopeText(conflict.scopeKey)}'),
            const SizedBox(height: 12),
            ...conflict.revisions.map(
              (revision) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text(_candidateText(conflict, revision))),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _resolving
                          ? null
                          : () => _confirmResolution(conflict, revision),
                      child: const Text('采用此版本'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResolution(
    PersonalRuleSyncConflict conflict,
    PersonalRuleRevision revision,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认采用这个版本？'),
        content: const Text('本机将立即恢复自动处理，并在下次同步时让其他设备采用同一结果。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认解决'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resolving = true);
    try {
      await widget.repository.resolveConflict(
        matchKey: conflict.matchKey,
        chosenRevisionId: revision.revisionId,
      );
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _reload();
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _resolving = false);
      final requiresRegression =
          error.message == 'personal_rule_extraction_regression_required' ||
              error.message == 'personal_rule_extraction_regression_not_passed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requiresRegression
              ? '本机回归样本不足或验证未通过，已继续暂停此提取规则'
              : '解决冲突失败，请稍后重试'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解决冲突失败，请稍后重试')),
      );
    }
  }

  Widget _centerMessage(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

String _kindText(PersonalRuleSyncKind kind) => switch (kind) {
      PersonalRuleSyncKind.extraction => '字段提取冲突',
      PersonalRuleSyncKind.category => '分类冲突',
      PersonalRuleSyncKind.notePreference => '备注偏好冲突',
    };

String _scopeText(String scope) {
  if (scope == 'global') return '全部账本';
  if (scope.startsWith('ledger:')) return '指定账本';
  if (scope.startsWith('local-ledger:')) return '本机账本';
  return scope;
}

String _candidateText(
  PersonalRuleSyncConflict conflict,
  PersonalRuleRevision revision,
) {
  switch (revision.kind) {
    case PersonalRuleSyncKind.category:
      final syncId = revision.payload['category_sync_id'] as String? ?? '';
      final name = conflict.categoryNamesBySyncId[syncId];
      return name == null ? '分类：未知分类（$syncId）' : '分类：$name';
    case PersonalRuleSyncKind.notePreference:
      return '备注：${revision.payload['suffix'] ?? revision.payload}';
    case PersonalRuleSyncKind.extraction:
      final template = revision.payload['template'];
      final id = template is Map ? template['id'] : revision.ruleId;
      return '提取规则：$id';
  }
}
