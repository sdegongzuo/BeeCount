import 'dart:convert';

import '../../../data/db.dart';
import '../../../data/repositories/billing_job_repository.dart';
import '../../../data/repositories/local/local_billing_job_repository.dart';
import '../billing_job_runner.dart';
import '../ocr_service.dart';

/// 交易创建服务抽象。
/// 接收 OcrResult（由 OcrStageProcessor 通过 PipelineContext 或 ruleResultJson 传递），返回交易 ID。
abstract class TransactionCreationService {
  Future<int> createTransaction(OcrResult ocrResult);
}

/// Transaction creation capability that requires an explicit immutable ledger.
abstract class LedgerScopedTransactionCreationService
    implements TransactionCreationService {
  /// Creates [ocrResult] in [ledgerId], never from mutable app selection state.
  Future<int> createTransactionInLedger(OcrResult ocrResult, int ledgerId);
}

abstract class BillingJobAtomicTransactionCreationService
    implements TransactionCreationService {
  Future<int> createTransactionForJob({
    required int jobId,
    required BillingJobLease lease,
    required OcrResult ocrResult,
  });
}

/// Production transaction boundary for image billing.
///
/// The bill, its tags/change-tracking rows, and Billing Job transactionId are
/// committed by one SQLite transaction. If ownership expires before the final
/// CAS, throwing rolls every write back and leaves no orphan bill for a later
/// runner to duplicate.
class AtomicBillingJobTransactionCreationService
    implements BillingJobAtomicTransactionCreationService {
  AtomicBillingJobTransactionCreationService({
    required this.database,
    required this.delegate,
  });

  final BeeDatabase database;
  final TransactionCreationService delegate;

  @override
  Future<int> createTransaction(OcrResult ocrResult) =>
      delegate.createTransaction(ocrResult);

  @override
  Future<int> createTransactionForJob({
    required int jobId,
    required BillingJobLease lease,
    required OcrResult ocrResult,
  }) {
    return database.transaction(() async {
      final jobRepository = LocalBillingJobRepository(database);
      final current = await jobRepository.findById(jobId);
      if (current == null) {
        throw StateError('billing_job_not_found');
      }
      if (current.transactionId case final transactionId?) {
        return transactionId;
      }
      if (!await jobRepository.isLeaseOwner(lease)) {
        throw const BillingJobExecutionCancelled('billing_job_lease_lost');
      }

      final ledgerId = current.ledgerId;
      if (ledgerId == null) {
        throw StateError('billing_job_ledger_missing');
      }
      final transactionId = delegate is LedgerScopedTransactionCreationService
          ? await (delegate as LedgerScopedTransactionCreationService)
              .createTransactionInLedger(ocrResult, ledgerId)
          : await delegate.createTransaction(ocrResult);
      final committed = await jobRepository.updateTransactionId(
        jobId,
        transactionId,
        lease: lease,
      );
      if (!committed) {
        throw const BillingJobExecutionCancelled('billing_job_cas_rejected');
      }
      return transactionId;
    });
  }
}

/// 交易创建阶段处理器。
/// 如果 transactionId 已存在（幂等），跳过创建。
class TransactionStageProcessor implements StageProcessor {
  final TransactionCreationService txService;
  final BillingJobRepository repo;

  TransactionStageProcessor({required this.txService, required this.repo});

  @override
  String get stageName => BillingJobStage.transactionCreated;

  @override
  Future<StageResult> process(
      BillingJob job, DateTime deadline, PipelineContext ctx) async {
    if (job.transactionId != null) {
      ctx.completeTransactionId(job.transactionId!);
      return const StageResult.success();
    }

    try {
      // 从 PipelineContext 获取 OcrResult，或从 ruleResultJson 解析
      OcrResult ocrResult;
      if (ctx.ocrFields != null) {
        ocrResult = OcrResult.fromJson(ctx.ocrFields!);
      } else if (job.ruleResultJson != null && job.ruleResultJson!.isNotEmpty) {
        final json = jsonDecode(job.ruleResultJson!) as Map<String, dynamic>;
        ocrResult = OcrResult.fromJson(json);
      } else {
        return const StageResult.failure('no_ocr_result');
      }

      if (ocrResult.amount == null ||
          ocrResult.amount!.abs() <= 0 ||
          ocrResult.time == null) {
        await ctx.requireOwnedWrite(
          (lease) => repo.updateFinalResultJson(
            job.id,
            jsonEncode(ocrResult.toJson()),
            lease: lease,
          ),
        );
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStatus(
            job.id,
            BillingJobStatus.awaitingConfirmation,
            lease: lease,
            releaseLease: true,
          ),
        );
        return const StageResult.awaitingConfirmation();
      }

      if (txService is BillingJobAtomicTransactionCreationService &&
          job.ledgerId == null) {
        await ctx.requireOwnedWrite(
          (lease) => repo.updateFinalResultJson(
            job.id,
            jsonEncode(ocrResult.toJson()),
            lease: lease,
          ),
        );
        await ctx.requireOwnedWrite(
          (lease) => repo.updateStatus(
            job.id,
            BillingJobStatus.awaitingConfirmation,
            lastError: 'billing_job_ledger_missing',
            lease: lease,
            releaseLease: true,
          ),
        );
        return const StageResult.awaitingConfirmation();
      }

      ctx.ensureCanStartSideEffect();
      await ctx.ensureJobOwned();
      final atomicService =
          txService is BillingJobAtomicTransactionCreationService
              ? txService as BillingJobAtomicTransactionCreationService
              : null;
      final lease = ctx.lease;
      final int txId;
      if (atomicService != null && lease != null) {
        txId = await atomicService.createTransactionForJob(
          jobId: job.id,
          lease: lease,
          ocrResult: ocrResult,
        );
      } else {
        // Test/legacy seam. Production always uses the atomic capability above.
        txId = await txService.createTransaction(ocrResult);
        await ctx.requireOwnedWrite(
          (lease) => repo.updateTransactionId(
            job.id,
            txId,
            lease: lease,
          ),
        );
      }
      ctx.completeTransactionId(txId); // 写入 PipelineContext，供后续阶段使用
      return const StageResult.success();
    } on BillingJobExecutionCancelled {
      rethrow;
    } catch (e) {
      return StageResult.failure(e.toString());
    }
  }
}
