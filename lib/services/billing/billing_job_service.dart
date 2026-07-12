import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/tasks/bill_extraction_task.dart';
import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';
import '../../providers/database_providers.dart';
import '../ai/ai_bill_service.dart';
import '../attachment_service.dart';
import 'bill_creation_service.dart';
import 'ai_async_enhance_service.dart';
import 'billing_job_runner.dart';
import 'ocr_service.dart';
import 'personal_category_rule_store.dart';
import 'personal_note_preference_store.dart';
import 'regression_sample_store.dart';
import 'successful_regression_sample_recorder.dart';
import 'stages/ai_stage_processor.dart';
import 'stages/attachment_stage_processor.dart';
import 'stages/ocr_stage_processor.dart';
import 'stages/rule_stage_processor.dart';
import 'stages/transaction_stage_processor.dart';
import 'fast_billing_rule_service.dart';
import 'rules/billing_rule_engine_impl.dart';
import 'rules/billing_rule_engine.dart';
import 'rules/billing_rule_repository.dart';
import 'rules/personal_rule_lifecycle_service.dart';
import '../platform/screenshot_source_info.dart';
import '../system/logger_service.dart';

/// 胶水层：组装 BillingJobRunner + concrete processors + repository。
/// 接入真实生产依赖（AIBillService、AttachmentService）。
class BillingJobService {
  final BillingJobRepository _repo;
  final BillingJobRunner _runner;
  final OcrService _ocrService;
  final SuccessfulRegressionSampleRecorder _regressionSampleRecorder;

  BillingJobService._({
    required BillingJobRepository repo,
    required BillingJobRunner runner,
    required OcrService ocrService,
    required SuccessfulRegressionSampleRecorder regressionSampleRecorder,
  })  : _repo = repo,
        _runner = runner,
        _ocrService = ocrService,
        _regressionSampleRecorder = regressionSampleRecorder;

  /// 创建 BillingJobService，接入真实生产依赖。
  factory BillingJobService.create({
    required BillingJobRepository repo,
    required ProviderContainer container,
    BillingJobStatusReporter? statusReporter,
  }) {
    final database = container.read(databaseProvider);
    final ocrService = OcrService(
      fastBillingRuleService: createProductionRuleService(database),
    );
    final ocrProcessor = OcrStageProcessor(
      ocrService: _OcrServiceAdapter(ocrService),
      repo: repo,
    );
    const ruleProcessor = RuleStageProcessor();

    // ledgerId 从 provider 读取，fallback 到 SharedPreferences
    final ledgerId = _resolveLedgerId(container);

    final baseRepo = container.read(repositoryProvider);
    final billCreation = BillCreationService(
      baseRepo,
      personalCategoryRules: SqlitePersonalCategoryRuleStore(
        container.read(databaseProvider),
      ),
      personalNotePreferences: SqlitePersonalNotePreferenceStore(
        container.read(databaseProvider),
      ),
    );
    final txProcessor = TransactionStageProcessor(
      txService: _BillCreationAdapter(billCreation, ledgerId),
      repo: repo,
    );

    // 图片分享主链以确定性结果完成；保留其他入口的 AI 功能，但不在这里调用。
    final aiProcessor = _DeterministicCompletionProcessor();

    // 附件保存：接入真实 AttachmentService
    final attachmentProc = AttachmentStageProcessor(
      attachmentService: _RealAttachmentService(container),
      repo: repo,
    );

    final runner = BillingJobRunner(
      repo: repo,
      ocrProcessor: ocrProcessor,
      ruleProcessor: ruleProcessor,
      txProcessor: txProcessor,
      aiProcessor: aiProcessor,
      attachmentProcessor: attachmentProc,
      statusReporter: statusReporter,
    );

    return BillingJobService._(
      repo: repo,
      runner: runner,
      ocrService: ocrService,
      regressionSampleRecorder: SuccessfulRegressionSampleRecorder(
        saveSample: const RegressionSampleStore().save,
        loadExpectedFields: (transactionId) async {
          final transaction = await baseRepo.getTransactionById(transactionId);
          if (transaction == null) return const {};
          return {
            'type': transaction.type,
            'amount': transaction.amount,
            'categoryId': transaction.categoryId,
            'accountId': transaction.accountId,
            'toAccountId': transaction.toAccountId,
            'happenedAt': transaction.happenedAt.toIso8601String(),
            'note': transaction.note,
            'paymentMethod': transaction.paymentMethod,
            'counterparty': transaction.counterparty,
            'paymentChannel': transaction.paymentChannel,
            'merchantFullName': transaction.merchantFullName,
            'acquirer': transaction.acquirer,
            'detailsText': transaction.detailsText,
          };
        },
      ),
    );
  }

  /// 处理一张分享图片。创建 job 并在 90s 窗口内执行。
  /// 返回创建的交易 ID，失败返回 null。
  Future<int?> processImage(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  }) async {
    logger.info('BillingJobService', '开始处理图片', imagePath);

    final existing = await _repo.findByImagePath(imagePath);
    if (existing != null &&
        (existing.status == BillingJobStatus.pending ||
            existing.status == BillingJobStatus.awaitingConfirmation ||
            existing.status == BillingJobStatus.succeeded)) {
      logger.warning('BillingJobService', '图片已处理过，跳过', imagePath);
      return existing.transactionId;
    }

    final job = await _repo.createJob(imagePath: imagePath);
    if (sourceInfo != null) {
      await _repo.updateSourceInfoJson(job.id, jsonEncode(sourceInfo.toJson()));
    }
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    await _runner.runJob(
      job,
      deadline,
      initialContext: PipelineContext()..sourceInfo = sourceInfo,
    );

    final updated = await _repo.findById(job.id);
    if (updated != null) {
      await _captureRegressionSample(updated);
    }
    logger.info(
        'BillingJobService',
        '处理完成',
        'stage=${updated?.stage}, status=${updated?.status}, '
            'txId=${updated?.transactionId}, attachmentDone=${updated?.attachmentDone}');
    return updated?.transactionId;
  }

  /// 恢复所有 pending/retryable_failed 的 job。
  Future<void> resumePendingJobs() async {
    final jobs = await _repo.findPendingJobs();
    if (jobs.isEmpty) return;
    logger.info('BillingJobService', '恢复待处理任务', '${jobs.length} 个 job');
    for (final job in jobs) {
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        await _runner.resumeJob(
          job,
          deadline,
          initialContext: PipelineContext()
            ..sourceInfo = _sourceInfoFromJob(job.sourceInfoJson),
        );
        final updated = await _repo.findById(job.id);
        if (updated != null) {
          await _captureRegressionSample(updated);
        }
      } catch (e, st) {
        logger.error('BillingJobService', '恢复任务失败', e, st);
      }
    }
  }

  /// 释放资源
  void dispose() {
    _ocrService.dispose();
  }

  Future<void> _captureRegressionSample(BillingJob job) async {
    try {
      await _regressionSampleRecorder.capture(job);
    } catch (error, stackTrace) {
      logger.error('BillingJobService', '保存个人规则回归样本失败', error, stackTrace);
    }
  }

  static int _resolveLedgerId(ProviderContainer container) {
    try {
      return container.read(currentLedgerIdProvider);
    } catch (_) {
      return 1;
    }
  }

  /// 构造 Android 图片分享链使用的真实活动规则服务。
  ///
  /// [publicRuleRepository] 仅用于以确定性公共规则验证生产组装接缝。
  static FastBillingRuleService createProductionRuleService(
    BeeDatabase database, {
    BillingRuleRepository? publicRuleRepository,
  }) =>
      FastBillingRuleService(
        ruleRepository: ActiveBillingRuleRepository(
          publicRepository: publicRuleRepository ?? TomlBillingRuleRepository(),
          loadActivePersonalRules:
              SqlitePersonalRuleRevisionStore(database).loadActiveRuleSet,
        ),
        ruleEngine: BillingRuleEngineImpl(),
      );

  static ScreenshotSourceInfo? _sourceInfoFromJob(String? jsonText) {
    if (jsonText == null || jsonText.isEmpty) return null;
    try {
      final value = jsonDecode(jsonText);
      if (value is Map<String, dynamic>) {
        return ScreenshotSourceInfo.fromMap(value);
      }
      if (value is Map) {
        return ScreenshotSourceInfo.fromMap(Map<String, dynamic>.from(value));
      }
    } catch (_) {}
    return null;
  }
}

class _DeterministicCompletionProcessor implements StageProcessor {
  @override
  String get stageName => BillingJobStage.completed;

  @override
  Future<StageResult> process(
    BillingJob job,
    DateTime deadline,
    PipelineContext ctx,
  ) async =>
      const StageResult.success();
}

// ── Adapters ──

/// 包装 OcrService：调用 OCR + 规则提取（一次），返回 OcrResult。
class _OcrServiceAdapter implements OcrServiceInterface {
  final OcrService _ocr;
  _OcrServiceAdapter(this._ocr);

  @override
  Future<OcrResult> recognize(
    String imagePath, {
    ScreenshotSourceInfo? sourceInfo,
  }) async {
    return _ocr.recognizePaymentImage(
      File(imagePath),
      sourceInfo: sourceInfo,
      enableAiEnhancement: false,
    );
  }
}

/// 包装 BillCreationService：接收 OcrResult，创建交易。
class _BillCreationAdapter implements TransactionCreationService {
  final BillCreationService _billCreation;
  final int _ledgerId;

  _BillCreationAdapter(this._billCreation, this._ledgerId);

  @override
  Future<int> createTransaction(OcrResult ocrResult) async {
    final txId = await _billCreation.createBillTransaction(
      result: ocrResult,
      ledgerId: _ledgerId,
      billingTypes: const ['image'],
    );
    if (txId == null) {
      throw StateError('创建交易失败：金额为空或为零');
    }
    return txId;
  }
}

/// 接入真实 AI 异步增强服务，并让它负责把 AI 字段合并回交易。
// 保留给非图片分享入口复用；图片分享主链不再实例化它。
// ignore: unused_element
class _RealAiEnhancementService implements AiEnhancementService {
  final ProviderContainer _container;

  _RealAiEnhancementService(this._container);

  @override
  Future<Map<String, dynamic>> enhanceTransaction(
    int transactionId,
    String rawText,
  ) async {
    // 检查 AI 是否启用
    final prefs = await SharedPreferences.getInstance();
    final aiEnabled = prefs.getBool('ai_bill_extraction_enabled') ?? true;
    if (!aiEnabled) return {};

    final repo = _container.read(repositoryProvider);
    final context = await _loadAiContext(repo);
    final service = AiAsyncEnhanceService(
      repo: repo,
      loadBillInfo: (request) async {
        final aiService = AIBillService();
        await aiService.initialize(
          expenseCategories: context.expenseCategories,
          incomeCategories: context.incomeCategories,
          accounts: context.accounts,
          imageFile: request.imageFile,
        );
        return aiService.extractLightweightEnhancement(
          ocrText: request.rawText,
          ruleBillInfo: _billInfoFromTransaction(request.baseTransaction),
          expenseCategories: context.expenseCategories,
          incomeCategories: context.incomeCategories,
          accounts: context.accounts,
        );
      },
    );
    final outcome = await service.enhanceTransaction(
      transactionId: transactionId,
      rawText: rawText,
    );
    if (outcome.status == AiAsyncEnhanceStatus.timeout) {
      throw TimeoutException('ai_enhance_timeout');
    }
    if (outcome.status == AiAsyncEnhanceStatus.failed) {
      final error = outcome.error;
      if (error != null) throw error;
      throw StateError('ai_enhance_failed');
    }

    return {
      'status': outcome.status.name,
      if (outcome.error != null) 'error': outcome.error.toString(),
    };
  }

  Future<_AiContext> _loadAiContext(dynamic repo) async {
    return _AiContext(
      expenseCategories: await _getCategoryNames(repo, 'expense'),
      incomeCategories: await _getCategoryNames(repo, 'income'),
      accounts: await _getAccountNames(repo),
    );
  }

  BillInfo _billInfoFromTransaction(dynamic tx) {
    return BillInfo(
      amount: tx.amount as double?,
      note: tx.note as String?,
      time: tx.happenedAt as DateTime?,
      paymentMethod: tx.paymentMethod as String?,
      paymentChannel: tx.paymentChannel as String?,
      counterparty: tx.counterparty as String?,
      merchantFullName: tx.merchantFullName as String?,
      acquirer: tx.acquirer as String?,
      detailsText: tx.detailsText as String?,
    );
  }

  Future<List<String>> _getCategoryNames(dynamic repo, String type) async {
    try {
      final categories = await repo.getTopLevelCategories(type);
      return categories.map<String>((c) => c.name as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _getAccountNames(dynamic repo) async {
    try {
      final accounts = await repo.getAllAccounts();
      return accounts.map<String>((a) => a.name as String).toList();
    } catch (_) {
      return [];
    }
  }
}

class _AiContext {
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final List<String> accounts;

  const _AiContext({
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
  });
}

/// 接入真实 AttachmentService。
/// 从 ProviderContainer 获取 AttachmentService（通过 Ref）。
class _RealAttachmentService implements AttachmentSaveServiceInterface {
  final ProviderContainer _container;

  _RealAttachmentService(this._container);

  @override
  Future<void> saveAttachment(
      String imagePath, Future<int> transactionId) async {
    // AttachmentService 需要 Ref，通过 container 获取 provider 值
    final attachmentService = _container.read(attachmentServiceProvider);
    await attachmentService.saveAttachmentWhenTransactionReady(
      transactionId: transactionId,
      sourceFile: File(imagePath),
      index: 0,
    );
  }
}
