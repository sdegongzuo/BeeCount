import 'package:flutter/material.dart';

class PersonalRuleUpdateDecision {
  const PersonalRuleUpdateDecision({
    required this.remember,
    this.categoryGlobal = false,
  });

  final bool remember;
  final bool categoryGlobal;
}

/// Asks how evidence-backed edits should affect future similar image bills.
Future<PersonalRuleUpdateDecision?> showPersonalRuleUpdatePrompt(
  BuildContext context, {
  required List<String> changedLabels,
  required bool categoryChanged,
  bool allowCancel = true,
}) {
  var categoryGlobal = false;
  return showDialog<PersonalRuleUpdateDecision>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: allowCancel,
      child: StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('是否更新个人规则？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('你修改了${changedLabels.join('、')}。'),
              const SizedBox(height: 12),
              const Text(
                '“仅本次”不会影响其他账单；记住后，'
                '新规则会先通过本机回归验证。',
              ),
              if (categoryChanged) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: categoryGlobal,
                  title: const Text('分类规则应用到所有账本'),
                  subtitle: const Text('默认只记住到当前账本'),
                  onChanged: (value) => setDialogState(
                    () => categoryGlobal = value ?? false,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (allowCancel)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                const PersonalRuleUpdateDecision(remember: false),
              ),
              child: const Text('仅本次'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                PersonalRuleUpdateDecision(
                  remember: true,
                  categoryGlobal: categoryGlobal,
                ),
              ),
              child: const Text('对类似账单记住'),
            ),
          ],
        ),
      ),
    ),
  );
}
