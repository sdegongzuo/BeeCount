import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/billing/pending_bill_confirmation_page.dart';
import '../../pages/billing/pending_transaction_classification_page.dart';
import '../../providers/database_providers.dart';
import '../../providers/smart_billing_providers.dart';
import '../attachment_service.dart';
import '../platform/share_billing_confirmation_handoff.dart';
import '../system/logger_service.dart';
import 'pending_billing_navigation_coordinator.dart';

/// 在生产根导航器中串行承载待确认与待分类页面。
///
/// 它消费分享入口 provider、在冷启动和恢复前台时查询当前数据库，并把真实页面
/// 推入离它最近的 [Navigator]。应用根页面和集成测试使用同一个接线入口。
class PendingBillingNavigationHost extends ConsumerStatefulWidget {
  const PendingBillingNavigationHost({
    super.key,
    required this.child,
    this.onNavigationError,
  });

  /// 与导航监听共同挂载在根页面中的正常应用内容。
  final Widget child;

  /// 测试或宿主需要接管导航错误时使用；生产默认写入应用日志。
  final PendingBillingNavigationErrorHandler? onNavigationError;

  @override
  ConsumerState<PendingBillingNavigationHost> createState() =>
      _PendingBillingNavigationHostState();
}

class _PendingBillingNavigationHostState
    extends ConsumerState<PendingBillingNavigationHost> {
  ProviderSubscription<int?>? _criticalSubscription;
  ProviderSubscription<int?>? _classificationSubscription;
  PendingBillingForegroundObserver? _foregroundObserver;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _initialize() {
    if (!mounted || _initialized) return;
    _initialized = true;
    final coordinator = PendingBillingNavigationCoordinator(
      findOldestCritical: (excludedIds) async {
        final jobs = await ref
            .read(billingJobRepositoryProvider)
            .findAwaitingConfirmationJobs();
        for (final job in jobs) {
          if (!excludedIds.contains(job.id)) return job.id;
        }
        return null;
      },
      findOldestClassification: (excludedIds) async {
        final ledgerId = ref.read(currentLedgerIdProvider);
        final pending = await ref
            .read(pendingTransactionClassificationServiceProvider)
            .listPending(ledgerId: ledgerId);
        for (final draft in pending) {
          if (!excludedIds.contains(draft.transaction.id)) {
            return draft.transaction.id;
          }
        }
        return null;
      },
      openCritical: _openCritical,
      openClassification: _openClassification,
      onError: widget.onNavigationError ??
          (error, stackTrace) => logger.error(
                'PendingBilling',
                '打开待处理账单失败',
                error,
                stackTrace,
              ),
    );
    _foregroundObserver = PendingBillingForegroundObserver(coordinator)
      ..start();
    _criticalSubscription = ref.listenManual<int?>(
      pendingBillConfirmationJobIdProvider,
      (previous, jobId) {
        if (jobId == null) return;
        ref.read(pendingBillConfirmationJobIdProvider.notifier).state = null;
        coordinator.notifyCritical(jobId);
      },
      fireImmediately: true,
    );
    _classificationSubscription = ref.listenManual<int?>(
      pendingTransactionClassificationIdProvider,
      (previous, transactionId) {
        if (transactionId == null) return;
        ref.read(pendingTransactionClassificationIdProvider.notifier).state =
            null;
        coordinator.notifyClassificationCreated(transactionId);
      },
      fireImmediately: true,
    );
  }

  Future<void> _openCritical(int jobId) async {
    if (!mounted) return;
    final service =
        await ref.read(pendingBillConfirmationServiceProvider.future);
    if (!mounted) return;
    final confirmation = Navigator.of(context).push(MaterialPageRoute<Object?>(
      builder: (_) => PendingBillConfirmationPage(
        jobId: jobId,
        service: service,
      ),
    ));
    // 原生侧握手不应阻塞后续待处理页面；原生通道异常由 handoff 自身隔离。
    unawaited(
      ShareBillingConfirmationHandoff.acknowledgeOpened(jobId).catchError(
        (Object error, StackTrace stackTrace) => logger.error(
          'PendingBilling',
          '确认页原生握手失败',
          error,
          stackTrace,
        ),
      ),
    );
    await confirmation;
  }

  Future<void> _openClassification(int transactionId) async {
    if (!mounted) return;
    final transaction =
        await ref.read(repositoryProvider).getTransactionById(transactionId);
    if (!mounted || transaction == null) return;
    await Navigator.of(context).push(MaterialPageRoute<Object?>(
      builder: (_) => PendingTransactionClassificationPage(
        ledgerId: transaction.ledgerId,
        transactionId: transactionId,
        service: ref.read(pendingTransactionClassificationServiceProvider),
        resolveAttachmentPath:
            ref.read(attachmentServiceProvider).getAttachmentPath,
      ),
    ));
  }

  @override
  void dispose() {
    _criticalSubscription?.close();
    _classificationSubscription?.close();
    _foregroundObserver?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
