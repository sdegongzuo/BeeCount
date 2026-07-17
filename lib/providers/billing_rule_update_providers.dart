import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../services/billing/rules/billing_rule_activation_journal.dart';
import '../services/billing/rules/billing_rule_repository.dart';
import '../services/billing/rules/billing_rule_update_configuration.dart';
import '../services/billing/rules/billing_rule_update_runtime.dart';
import '../services/billing/rules/billing_rule_update_service.dart';
import '../services/billing/rules/billing_rule_models.dart';
import '../services/billing/rules/billing_rule_storage.dart';
import '../services/system/logger_service.dart';
import 'database_providers.dart';

enum BillingRuleUpdateAction {
  initialize,
  automaticCheck,
  manualCheck,
  rollback,
}

class BillingRuleUpdateDiagnosticsView {
  final String activeVersion;
  final String? previousVersion;
  final String? candidateVersion;
  final BillingRuleActivationState? journalState;
  final BillingRuleActivationOperation? operation;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final BillingRuleUpdateStatus? lastCheckStatus;
  final String? lastCheckVersion;
  final DateTime? lastCheckAt;
  final String? stableDiagnostic;
  final bool diskStateVerified;

  const BillingRuleUpdateDiagnosticsView({
    required this.activeVersion,
    this.previousVersion,
    this.candidateVersion,
    this.journalState,
    this.operation,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastCheckStatus,
    this.lastCheckVersion,
    this.lastCheckAt,
    this.stableDiagnostic,
    this.diskStateVerified = true,
  });

  bool get canRollback => previousVersion != null && diskStateVerified;
}

class BillingRuleUpdateViewState {
  final bool initialized;
  final bool busy;
  final bool updateEnabled;
  final String? disabledReason;
  final String? manifestHost;
  final BillingRuleUpdateAction? action;
  final BillingRuleUpdateResult? lastResult;
  final BillingRuleUpdateDiagnosticsView? diagnostics;
  final String? error;

  const BillingRuleUpdateViewState({
    this.initialized = false,
    this.busy = false,
    this.updateEnabled = false,
    this.disabledReason,
    this.manifestHost,
    this.action,
    this.lastResult,
    this.diagnostics,
    this.error,
  });

  BillingRuleUpdateViewState copyWith({
    bool? initialized,
    bool? busy,
    bool? updateEnabled,
    String? disabledReason,
    bool clearDisabledReason = false,
    String? manifestHost,
    bool clearManifestHost = false,
    BillingRuleUpdateAction? action,
    bool clearAction = false,
    BillingRuleUpdateResult? lastResult,
    bool clearLastResult = false,
    BillingRuleUpdateDiagnosticsView? diagnostics,
    bool clearDiagnostics = false,
    String? error,
    bool clearError = false,
  }) {
    return BillingRuleUpdateViewState(
      initialized: initialized ?? this.initialized,
      busy: busy ?? this.busy,
      updateEnabled: updateEnabled ?? this.updateEnabled,
      disabledReason:
          clearDisabledReason ? null : (disabledReason ?? this.disabledReason),
      manifestHost:
          clearManifestHost ? null : (manifestHost ?? this.manifestHost),
      action: clearAction ? null : (action ?? this.action),
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      diagnostics: clearDiagnostics ? null : (diagnostics ?? this.diagnostics),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

abstract interface class BillingRuleUpdateGateway {
  bool get updateEnabled;

  String? get disabledReason;

  String? get manifestHost;

  Future<BillingRuleUpdateResult> checkIfDue();

  Future<BillingRuleUpdateResult> checkNow();

  Future<BillingRuleUpdateResult> rollback();

  Future<BillingRuleUpdateDiagnosticsView> diagnostics();
}

typedef BillingRuleUpdateGatewayLoader = Future<BillingRuleUpdateGateway>
    Function();
typedef BillingRuleUpdateErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

class BillingRuleUpdateController
    extends StateNotifier<BillingRuleUpdateViewState> {
  final BillingRuleUpdateGatewayLoader _loadGateway;
  final BillingRuleUpdateErrorReporter _reportError;
  Future<BillingRuleUpdateGateway>? _gatewayFuture;
  Future<void> _tail = Future<void>.value();
  bool _automaticCheckQueued = false;

  BillingRuleUpdateController(
    this._loadGateway, {
    BillingRuleUpdateErrorReporter? errorReporter,
  })  : _reportError = errorReporter ?? _reportProductionError,
        super(const BillingRuleUpdateViewState());

  Future<void> initialize() => _enqueue(
        BillingRuleUpdateAction.initialize,
        (gateway) async => null,
      );

  Future<void> checkIfDue() {
    if (_automaticCheckQueued) return Future<void>.value();
    _automaticCheckQueued = true;
    return _enqueue(
      BillingRuleUpdateAction.automaticCheck,
      (gateway) => gateway.checkIfDue(),
    ).whenComplete(() => _automaticCheckQueued = false);
  }

  Future<void> checkNow() => _enqueue(
        BillingRuleUpdateAction.manualCheck,
        (gateway) => gateway.checkNow(),
      );

  Future<void> rollback() => _enqueue(
        BillingRuleUpdateAction.rollback,
        (gateway) => gateway.rollback(),
      );

  Future<void> refreshDiagnostics() => _enqueue(
        BillingRuleUpdateAction.initialize,
        (gateway) async => null,
      );

  Future<void> _enqueue(
    BillingRuleUpdateAction action,
    Future<BillingRuleUpdateResult?> Function(BillingRuleUpdateGateway gateway)
        operation,
  ) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      if (!mounted) {
        completer.complete();
        return;
      }
      state = state.copyWith(
        busy: true,
        action: action,
        clearError: true,
      );
      try {
        final gateway = await _gateway();
        final result = await operation(gateway);
        final diagnostics = await gateway.diagnostics();
        if (!mounted) return;
        state = state.copyWith(
          initialized: true,
          busy: false,
          updateEnabled: gateway.updateEnabled,
          disabledReason: gateway.disabledReason,
          clearDisabledReason: gateway.disabledReason == null,
          manifestHost: gateway.manifestHost,
          clearManifestHost: gateway.manifestHost == null,
          lastResult: result,
          diagnostics: diagnostics,
          clearError: true,
        );
      } catch (error, stackTrace) {
        _gatewayFuture = null;
        _reportError(error, stackTrace);
        if (mounted) {
          state = state.copyWith(
            initialized: false,
            busy: false,
            error: _stableError(error),
          );
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  Future<BillingRuleUpdateGateway> _gateway() =>
      _gatewayFuture ??= _loadGateway();
}

String _stableError(Object error) {
  return '公共规则操作失败，请稍后重试';
}

void _reportProductionError(Object error, StackTrace stackTrace) {
  logger.error('BillingRuleUpdate', '公共规则操作失败', error, stackTrace);
}

class ProductionBillingRuleUpdateGateway implements BillingRuleUpdateGateway {
  final BillingRuleUpdateConfiguration configuration;
  final BillingRuleUpdateService service;
  final RuntimeBillingRuleRepository publicRepository;
  final BillingRuleStorage storage;

  const ProductionBillingRuleUpdateGateway({
    required this.configuration,
    required this.service,
    required this.publicRepository,
    required this.storage,
  });

  @override
  bool get updateEnabled => configuration.isEnabled;

  @override
  String? get disabledReason => configuration.disabledReason;

  @override
  String? get manifestHost => configuration.manifestUri?.host;

  @override
  Future<BillingRuleUpdateResult> checkIfDue() => service.checkForUpdateIfDue();

  @override
  Future<BillingRuleUpdateResult> checkNow() => service.checkForUpdate();

  @override
  Future<BillingRuleUpdateResult> rollback() => service.rollback();

  @override
  Future<BillingRuleUpdateDiagnosticsView> diagnostics() async {
    final journal = await service.activationDiagnostics();
    final check = await service.checkDiagnostics();
    final active = await publicRepository.loadActiveRuleSet();
    final previousExists = await storage.previousFile.exists();
    final previous = await _loadPrevious();
    if (journal?.lastError != null) {
      logger.warning(
        'BillingRuleUpdate',
        '规则激活诊断存在未完成状态: ${journal!.lastError}',
      );
    }
    return BillingRuleUpdateDiagnosticsView(
      activeVersion: active.rulesVersion,
      previousVersion: previous?.rulesVersion,
      candidateVersion: journal?.candidateVersion,
      journalState: journal?.state,
      operation: journal?.operation,
      lastAttemptAt: check?.lastAttemptAt ?? journal?.lastAttemptAt,
      lastSuccessAt: check?.lastSuccessAt ?? journal?.lastSuccessAt,
      lastCheckStatus: check?.status,
      lastCheckVersion: check?.rulesVersion,
      lastCheckAt: check?.resultAt,
      stableDiagnostic: check?.reason ??
          (journal?.lastError == null ? null : '上次规则操作未完成，已保留安全快照'),
      diskStateVerified: (journal?.diskStateVerified ?? true) &&
          (!previousExists || previous != null),
    );
  }

  Future<BillingRuleSet?> _loadPrevious() async {
    if (!await storage.previousFile.exists()) return null;
    try {
      final rules = await TomlBillingRuleRepository(
        activeRuleFile: storage.previousFile,
      ).loadActiveRuleSet();
      return rules.source == storage.previousFile.path ? rules : null;
    } catch (_) {
      return null;
    }
  }
}

Future<BillingRuleUpdateGateway> loadProductionBillingRuleUpdateGateway(
    BeeDatabase database) async {
  final configuration = await BillingRuleUpdateConfiguration.loadProduction();
  final service = await productionBillingRuleUpdateRuntime.prepare(
    configuration: configuration,
    database: database,
  );
  return ProductionBillingRuleUpdateGateway(
    configuration: configuration,
    service: service,
    publicRepository: productionBillingRuleRepository(),
    storage: await productionBillingRuleStorage(),
  );
}

final billingRuleUpdateControllerProvider = StateNotifierProvider<
    BillingRuleUpdateController, BillingRuleUpdateViewState>((ref) {
  final database = ref.watch(databaseProvider);
  return BillingRuleUpdateController(
    () => loadProductionBillingRuleUpdateGateway(database),
  );
});

/// 在首帧绘制完成后触发且仅触发一次公共规则自动检查。
///
/// 把启动时机集中在这个边界，避免 `main()` 和业务首页各自发起检查，亦避免
/// 联网下载与候选回归阻塞首帧。磁盘 journal 恢复仍由生产 runtime 在任何
/// 规则消费者启动前完成。
class BillingRuleUpdateStartupCheck extends ConsumerStatefulWidget {
  final Widget child;

  const BillingRuleUpdateStartupCheck({
    required this.child,
    super.key,
  });

  @override
  ConsumerState<BillingRuleUpdateStartupCheck> createState() =>
      _BillingRuleUpdateStartupCheckState();
}

class _BillingRuleUpdateStartupCheckState
    extends ConsumerState<BillingRuleUpdateStartupCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(billingRuleUpdateControllerProvider.notifier).checkIfDue(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
