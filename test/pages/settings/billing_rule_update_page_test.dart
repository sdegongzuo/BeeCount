import 'package:beecount/pages/settings/billing_rule_update_page.dart';
import 'package:beecount/providers/billing_rule_update_providers.dart';
import 'package:beecount/services/billing/rules/billing_rule_activation_journal.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('诊断页展示活动/上一版本并可确认安全回滚', (tester) async {
    final gateway = _PageGateway();
    final controller = BillingRuleUpdateController(() async => gateway);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRuleUpdateControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: BillingRuleUpdatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('public-v2'), findsOneWidget);
    expect(find.text('public-v1'), findsOneWidget);
    expect(find.text('已验证'), findsOneWidget);

    await tester.tap(find.text('回滚到上一版'));
    await tester.pumpAndSettle();
    expect(find.text('确认回滚公共规则？'), findsOneWidget);
    await tester.tap(find.text('安全回滚'));
    await tester.pumpAndSettle();

    expect(gateway.rollbackCalls, 1);
    expect(find.textContaining('已安全回滚'), findsOneWidget);
  });

  testWidgets('未配置更新源时解释禁用原因且不允许网络检查', (tester) async {
    final gateway = _PageGateway(enabled: false);
    final controller = BillingRuleUpdateController(() async => gateway);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRuleUpdateControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: BillingRuleUpdatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未启用'), findsOneWidget);
    expect(find.textContaining('未配置远程规则 manifest URL'), findsOneWidget);
    await tester.tap(find.text('立即检查更新'), warnIfMissed: false);
    await tester.pump();
    expect(gateway.manualCalls, 0);
  });
}

class _PageGateway implements BillingRuleUpdateGateway {
  final bool enabled;
  int manualCalls = 0;
  int rollbackCalls = 0;

  _PageGateway({this.enabled = true});

  @override
  String? get disabledReason => enabled ? null : '未配置远程规则 manifest URL';

  @override
  String? get manifestHost => enabled ? 'rules.beecount.test' : null;

  @override
  bool get updateEnabled => enabled;

  @override
  Future<BillingRuleUpdateResult> checkIfDue() async =>
      const BillingRuleUpdateResult(status: BillingRuleUpdateStatus.notDue);

  @override
  Future<BillingRuleUpdateResult> checkNow() async {
    manualCalls++;
    return const BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.alreadyLatest,
    );
  }

  @override
  Future<BillingRuleUpdateDiagnosticsView> diagnostics() async =>
      BillingRuleUpdateDiagnosticsView(
        activeVersion: 'public-v2',
        previousVersion: 'public-v1',
        journalState: BillingRuleActivationState.committed,
        operation: BillingRuleActivationOperation.update,
        lastAttemptAt: DateTime.utc(2026, 7, 17),
        lastSuccessAt: DateTime.utc(2026, 7, 17),
      );

  @override
  Future<BillingRuleUpdateResult> rollback() async {
    rollbackCalls++;
    return const BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.rolledBack,
      rulesVersion: 'public-v1',
    );
  }
}
