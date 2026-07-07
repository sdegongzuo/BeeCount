import 'dart:async';
import 'dart:io';

import '../../ai/tasks/bill_extraction_task.dart';
import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../system/logger_service.dart';
import 'bill_creation_service.dart';
import 'details_text_helper.dart';
import 'ocr_service.dart';

typedef AiBillInfoLoader = Future<BillInfo?> Function(
  AiAsyncEnhanceRequest request,
);

typedef AiRuleAuditLoader = Future<AiRuleAuditResult?> Function(
  AiAsyncEnhanceRequest request,
);

enum AiAsyncEnhanceStatus {
  succeeded,
  failed,
  timeout,
  skipped,
}

class AiAsyncEnhanceRequest {
  final int transactionId;
  final Transaction baseTransaction;
  final String rawText;
  final File? imageFile;

  const AiAsyncEnhanceRequest({
    required this.transactionId,
    required this.baseTransaction,
    required this.rawText,
    this.imageFile,
  });
}

class AiAsyncEnhanceOutcome {
  final int transactionId;
  final AiAsyncEnhanceStatus status;
  final BillInfo? billInfo;
  final AiRuleAuditResult? ruleAudit;
  final Object? error;

  const AiAsyncEnhanceOutcome({
    required this.transactionId,
    required this.status,
    this.billInfo,
    this.ruleAudit,
    this.error,
  });
}

class AiRuleAuditResult {
  final double ruleScore;
  final bool accepted;
  final List<String> issues;
  final Map<String, dynamic> raw;

  const AiRuleAuditResult({
    required this.ruleScore,
    required this.accepted,
    this.issues = const [],
    this.raw = const {},
  });

  factory AiRuleAuditResult.fromJson(Map<String, dynamic> json) {
    final scoreValue = json['rule_score'] ?? json['score'];
    final issuesValue = json['issues'];
    return AiRuleAuditResult(
      ruleScore: scoreValue is num ? scoreValue.toDouble() : 0,
      accepted: json['accepted'] == true,
      issues: issuesValue is List
          ? issuesValue.map((item) => item.toString()).toList()
          : const [],
      raw: json,
    );
  }
}

class AiAsyncEnhanceService {
  static const _tag = 'AiAsyncEnhance';
  static const double defaultAuditPassScore = 0.82;

  final BaseRepository repo;
  final AiBillInfoLoader loadBillInfo;
  final AiRuleAuditLoader? auditRuleResult;
  final bool enableRuleAudit;
  final Duration timeout;
  final Duration auditTimeout;
  final double auditPassScore;

  AiAsyncEnhanceService({
    required this.repo,
    required this.loadBillInfo,
    this.auditRuleResult,
    this.enableRuleAudit = false,
    this.timeout = const Duration(seconds: 90),
    this.auditTimeout = const Duration(seconds: 60),
    this.auditPassScore = defaultAuditPassScore,
  });

  Future<AiAsyncEnhanceOutcome> enhanceTransaction({
    required int transactionId,
    required String rawText,
    File? imageFile,
  }) async {
    final tx = await repo.getTransactionById(transactionId);
    if (tx == null) {
      logger.warning(_tag, '交易不存在，跳过AI增强', 'transactionId=$transactionId');
      return AiAsyncEnhanceOutcome(
        transactionId: transactionId,
        status: AiAsyncEnhanceStatus.skipped,
      );
    }

    try {
      logger.info(
        _tag,
        'AI增强开始',
        'transactionId=$transactionId, timeout=${timeout.inSeconds}s, hasImage=${imageFile != null}',
      );

      final billInfo = await loadBillInfo(
        AiAsyncEnhanceRequest(
          transactionId: transactionId,
          baseTransaction: tx,
          rawText: rawText,
          imageFile: imageFile,
        ),
      ).timeout(timeout);

      if (billInfo == null) {
        await _writeStatus(tx, AiAsyncEnhanceStatus.failed,
            error: 'empty_ai_result');
        return AiAsyncEnhanceOutcome(
          transactionId: transactionId,
          status: AiAsyncEnhanceStatus.failed,
          error: 'empty_ai_result',
        );
      }

      final updatedTx = await _applyBillInfo(tx, rawText, billInfo);
      final audit = await _runRuleAudit(updatedTx ?? tx, rawText, imageFile);
      return AiAsyncEnhanceOutcome(
        transactionId: transactionId,
        status: AiAsyncEnhanceStatus.succeeded,
        billInfo: billInfo,
        ruleAudit: audit,
      );
    } on TimeoutException catch (e) {
      await _writeStatus(tx, AiAsyncEnhanceStatus.timeout);
      logger.warning(_tag, 'AI增强超时', 'transactionId=$transactionId');
      return AiAsyncEnhanceOutcome(
        transactionId: transactionId,
        status: AiAsyncEnhanceStatus.timeout,
        error: e,
      );
    } catch (e, st) {
      await _writeStatus(tx, AiAsyncEnhanceStatus.failed, error: e);
      logger.error(_tag, 'AI增强失败', e, st);
      return AiAsyncEnhanceOutcome(
        transactionId: transactionId,
        status: AiAsyncEnhanceStatus.failed,
        error: e,
      );
    }
  }

  Future<Transaction?> _applyBillInfo(
    Transaction tx,
    String rawText,
    BillInfo billInfo,
  ) async {
    final details = _parseDetailsText(tx.detailsText);
    _mergeAiDetails(details, billInfo);
    _recordConflicts(details, tx, billInfo);
    details['ai_enhance_status'] = AiAsyncEnhanceStatus.succeeded.name;

    final categoryId = await _resolveCategoryId(tx, rawText, billInfo);
    final note = _nonBlank(billInfo.note) ?? tx.note;
    final paymentMethod = _nonBlank(billInfo.paymentMethod) ?? tx.paymentMethod;
    final counterparty = _nonBlank(billInfo.counterparty) ?? tx.counterparty;
    final merchantFullName =
        _nonBlank(billInfo.merchantFullName) ?? tx.merchantFullName;
    final acquirer = _nonBlank(billInfo.acquirer) ?? tx.acquirer;

    await repo.updateTransaction(
      id: tx.id,
      type: tx.type,
      amount: tx.amount,
      categoryId: categoryId,
      note: note,
      paymentMethod: paymentMethod,
      counterparty: counterparty,
      paymentChannel: tx.paymentChannel,
      merchantFullName: merchantFullName,
      acquirer: acquirer,
      detailsText: detailsMapToText(details),
      happenedAt: tx.happenedAt,
      accountId: tx.accountId,
    );

    logger.info(
      _tag,
      'AI增强已合并',
      'transactionId=${tx.id}, categoryId=$categoryId',
    );

    return repo.getTransactionById(tx.id);
  }

  Future<AiRuleAuditResult?> _runRuleAudit(
    Transaction tx,
    String rawText,
    File? imageFile,
  ) async {
    final loader = auditRuleResult;
    if (!enableRuleAudit || loader == null || imageFile == null) return null;

    try {
      logger.info(_tag, '视觉规则审计开始', 'transactionId=${tx.id}');
      final audit = await loader(
        AiAsyncEnhanceRequest(
          transactionId: tx.id,
          baseTransaction: tx,
          rawText: rawText,
          imageFile: imageFile,
        ),
      ).timeout(auditTimeout);
      if (audit == null) {
        logger.warning(_tag, '视觉规则审计无结果', 'transactionId=${tx.id}');
        return null;
      }

      final effectiveAudit = audit.normalized(auditPassScore);
      await _writeAudit(tx, effectiveAudit);
      logger.info(
        _tag,
        '视觉规则审计结束',
        'transactionId=${tx.id}, score=${effectiveAudit.ruleScore}, accepted=${effectiveAudit.accepted}',
      );
      return effectiveAudit;
    } on TimeoutException catch (e) {
      logger.warning(
        _tag,
        '视觉规则审计超时',
        'transactionId=${tx.id}, timeout=${auditTimeout.inSeconds}s',
      );
      await _writeAuditError(tx, e);
      return null;
    } catch (e, st) {
      logger.error(_tag, '视觉规则审计失败', e, st);
      await _writeAuditError(tx, e);
      return null;
    }
  }

  Future<void> _writeAudit(Transaction tx, AiRuleAuditResult audit) async {
    final details = _parseDetailsText(tx.detailsText);
    details['ai_rule_audit_score'] = audit.ruleScore;
    details['ai_rule_audit_accepted'] = audit.accepted;
    if (audit.issues.isNotEmpty) {
      details['ai_rule_audit_issues'] = audit.issues;
    }
    if (!audit.accepted || audit.ruleScore < auditPassScore) {
      details['ai_rule_review_default_enabled'] = true;
      details['ai_rule_review_status'] = 'active_suggestion';
    }

    await repo.updateTransaction(
      id: tx.id,
      type: tx.type,
      amount: tx.amount,
      categoryId: tx.categoryId,
      note: tx.note,
      paymentMethod: tx.paymentMethod,
      counterparty: tx.counterparty,
      paymentChannel: tx.paymentChannel,
      merchantFullName: tx.merchantFullName,
      acquirer: tx.acquirer,
      detailsText: detailsMapToText(details),
      happenedAt: tx.happenedAt,
      accountId: tx.accountId,
    );
  }

  Future<void> _writeAuditError(Transaction tx, Object error) async {
    final details = _parseDetailsText(tx.detailsText);
    details['ai_rule_audit_error'] = error.toString();

    await repo.updateTransaction(
      id: tx.id,
      type: tx.type,
      amount: tx.amount,
      categoryId: tx.categoryId,
      note: tx.note,
      paymentMethod: tx.paymentMethod,
      counterparty: tx.counterparty,
      paymentChannel: tx.paymentChannel,
      merchantFullName: tx.merchantFullName,
      acquirer: tx.acquirer,
      detailsText: detailsMapToText(details),
      happenedAt: tx.happenedAt,
      accountId: tx.accountId,
    );
  }

  Future<int?> _resolveCategoryId(
    Transaction tx,
    String rawText,
    BillInfo billInfo,
  ) async {
    final categoryName = _nonBlank(billInfo.category);
    if (categoryName == null || tx.type == 'transfer') {
      return tx.categoryId;
    }

    final categories = await repo.getUsableCategories(tx.type);
    if (categories.isEmpty) return tx.categoryId;

    final ocrResult = OcrResult(
      amount: tx.amount,
      note: _nonBlank(billInfo.note) ?? tx.note,
      time: tx.happenedAt,
      rawText: rawText,
      allNumbers: const [],
      aiCategoryName: categoryName,
      aiType: tx.type,
      paymentMethod: _nonBlank(billInfo.paymentMethod) ?? tx.paymentMethod,
      paymentChannel: tx.paymentChannel,
      counterparty: _nonBlank(billInfo.counterparty) ?? tx.counterparty,
      merchantFullName:
          _nonBlank(billInfo.merchantFullName) ?? tx.merchantFullName,
      acquirer: _nonBlank(billInfo.acquirer) ?? tx.acquirer,
    );

    return await BillCreationService(repo)
            .matchCategory(ocrResult, categories) ??
        tx.categoryId;
  }

  Future<void> _writeStatus(
    Transaction tx,
    AiAsyncEnhanceStatus status, {
    Object? error,
  }) async {
    final details = _parseDetailsText(tx.detailsText);
    details['ai_enhance_status'] = status.name;
    if (error != null) {
      details['ai_enhance_error'] = error.toString();
    }

    await repo.updateTransaction(
      id: tx.id,
      type: tx.type,
      amount: tx.amount,
      categoryId: tx.categoryId,
      note: tx.note,
      paymentMethod: tx.paymentMethod,
      counterparty: tx.counterparty,
      paymentChannel: tx.paymentChannel,
      merchantFullName: tx.merchantFullName,
      acquirer: tx.acquirer,
      detailsText: detailsMapToText(details),
      happenedAt: tx.happenedAt,
      accountId: tx.accountId,
    );
  }

  void _mergeAiDetails(Map<String, dynamic> details, BillInfo billInfo) {
    final aiDetails = billInfo.details;
    if (aiDetails != null) {
      for (final entry in aiDetails.entries) {
        if (entry.value != null) {
          details[entry.key] = entry.value;
        }
      }
    }

    final detailsText = _nonBlank(billInfo.detailsText);
    if (detailsText != null) {
      details['ai_details_text'] = detailsText;
    }
  }

  void _recordConflicts(
    Map<String, dynamic> details,
    Transaction tx,
    BillInfo billInfo,
  ) {
    final aiAmount = billInfo.amount;
    if (aiAmount != null && (aiAmount.abs() - tx.amount).abs() > 0.005) {
      details['ai_conflict_amount'] = aiAmount;
      logger.info(_tag, '保留规则金额，记录AI冲突',
          'transactionId=${tx.id}, rule=${tx.amount}, ai=$aiAmount');
    }

    final aiTime = billInfo.time;
    if (aiTime != null && aiTime != tx.happenedAt) {
      details['ai_conflict_time'] = aiTime.toIso8601String();
      logger.info(_tag, '保留规则时间，记录AI冲突',
          'transactionId=${tx.id}, rule=${tx.happenedAt}, ai=$aiTime');
    }

    final aiPaymentChannel = _nonBlank(billInfo.paymentChannel);
    if (aiPaymentChannel != null && aiPaymentChannel != tx.paymentChannel) {
      details['ai_conflict_payment_channel'] = aiPaymentChannel;
      logger.info(_tag, '保留规则支付通道，记录AI冲突',
          'transactionId=${tx.id}, rule=${tx.paymentChannel}, ai=$aiPaymentChannel');
    }
  }

  Map<String, dynamic> _parseDetailsText(String? text) {
    final details = <String, dynamic>{};
    if (text == null || text.trim().isEmpty) return details;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final separator = trimmed.indexOf(':');
      if (separator <= 0) {
        continue;
      }

      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        details[key] = value;
      }
    }

    return details;
  }

  String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension on AiRuleAuditResult {
  AiRuleAuditResult normalized(double passScore) {
    if (accepted || ruleScore < passScore) return this;
    return AiRuleAuditResult(
      ruleScore: ruleScore,
      accepted: true,
      issues: issues,
      raw: raw,
    );
  }
}
