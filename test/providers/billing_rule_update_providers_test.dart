import 'dart:async';

import 'package:beecount/providers/billing_rule_update_providers.dart';
import 'package:beecount/services/billing/rules/billing_rule_activation_journal.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('并发启动与 resume 只排队一次自动日检', () async {
    final gate = Completer<BillingRuleUpdateResult>();
    final gateway = _FakeGateway(onDue: () => gate.future);
    final controller = BillingRuleUpdateController(() async => gateway);

    final first = controller.checkIfDue();
    final second = controller.checkIfDue();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.dueCalls, 1);
    expect(controller.state.busy, isTrue);

    gate.complete(const BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.alreadyLatest,
    ));
    await Future.wait([first, second]);

    expect(gateway.dueCalls, 1);
    expect(controller.state.initialized, isTrue);
    expect(controller.state.diagnostics?.activeVersion, 'public-v2');
    controller.dispose();
  });

  test('手动检查和回滚严格串行且每次刷新持久诊断', () async {
    final events = <String>[];
    final manualGate = Completer<BillingRuleUpdateResult>();
    final gateway = _FakeGateway(
      onManual: () async {
        events.add('manual-start');
        final result = await manualGate.future;
        events.add('manual-end');
        return result;
      },
      onRollback: () async {
        events.add('rollback');
        return const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.rolledBack,
          rulesVersion: 'public-v1',
        );
      },
    );
    final controller = BillingRuleUpdateController(() async => gateway);

    final manual = controller.checkNow();
    final rollback = controller.rollback();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['manual-start']);

    manualGate.complete(const BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.activated,
      rulesVersion: 'public-v2',
    ));
    await Future.wait([manual, rollback]);

    expect(events, ['manual-start', 'manual-end', 'rollback']);
    expect(gateway.diagnosticCalls, 2);
    expect(
      controller.state.lastResult?.status,
      BillingRuleUpdateStatus.rolledBack,
    );
    controller.dispose();
  });

  test('启动恢复失败不缓存坏实例，下一次操作可重试恢复', () async {
    var attempts = 0;
    final gateway = _FakeGateway();
    final controller = BillingRuleUpdateController(
      () async {
        attempts++;
        if (attempts == 1) throw StateError('公共规则启动恢复失败');
        return gateway;
      },
      errorReporter: (_, __) {},
    );

    await controller.initialize();
    expect(controller.state.initialized, isFalse);
    expect(controller.state.error, '公共规则启动恢复失败');

    await controller.initialize();
    expect(attempts, 2);
    expect(controller.state.initialized, isTrue);
    expect(controller.state.error, isNull);
    controller.dispose();
  });

  test('禁用网络更新仍能读取当前版本和提供安全回滚', () async {
    final gateway = _FakeGateway(
      enabled: false,
      reason: '未配置远程规则 manifest URL',
    );
    final controller = BillingRuleUpdateController(() async => gateway);

    await controller.initialize();

    expect(controller.state.updateEnabled, isFalse);
    expect(controller.state.disabledReason, contains('未配置'));
    expect(controller.state.diagnostics?.canRollback, isTrue);
    controller.dispose();
  });
}

class _FakeGateway implements BillingRuleUpdateGateway {
  final bool enabled;
  final String? reason;
  final Future<BillingRuleUpdateResult> Function()? onDue;
  final Future<BillingRuleUpdateResult> Function()? onManual;
  final Future<BillingRuleUpdateResult> Function()? onRollback;
  int dueCalls = 0;
  int diagnosticCalls = 0;

  _FakeGateway({
    this.enabled = true,
    this.reason,
    this.onDue,
    this.onManual,
    this.onRollback,
  });

  @override
  String? get disabledReason => reason;

  @override
  String? get manifestHost => enabled ? 'rules.beecount.test' : null;

  @override
  bool get updateEnabled => enabled;

  @override
  Future<BillingRuleUpdateResult> checkIfDue() {
    dueCalls++;
    return onDue?.call() ??
        Future.value(const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
        ));
  }

  @override
  Future<BillingRuleUpdateResult> checkNow() =>
      onManual?.call() ??
      Future.value(const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.alreadyLatest,
      ));

  @override
  Future<BillingRuleUpdateDiagnosticsView> diagnostics() async {
    diagnosticCalls++;
    return BillingRuleUpdateDiagnosticsView(
      activeVersion: 'public-v2',
      previousVersion: 'public-v1',
      journalState: BillingRuleActivationState.committed,
      operation: BillingRuleActivationOperation.update,
      lastAttemptAt: DateTime.utc(2026, 7, 17),
      lastSuccessAt: DateTime.utc(2026, 7, 17),
    );
  }

  @override
  Future<BillingRuleUpdateResult> rollback() =>
      onRollback?.call() ??
      Future.value(const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.rolledBack,
      ));
}
