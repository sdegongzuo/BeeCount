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
  final Object? error;

  const AiAsyncEnhanceOutcome({
    required this.transactionId,
    required this.status,
    this.billInfo,
    this.error,
  });
}

class AiAsyncEnhanceService {
  static const _tag = 'AiAsyncEnhance';

  final BaseRepository repo;
  final AiBillInfoLoader loadBillInfo;
  final Duration timeout;

  AiAsyncEnhanceService({
    required this.repo,
    required this.loadBillInfo,
    this.timeout = const Duration(seconds: 90),
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

      await _applyBillInfo(tx, rawText, billInfo);
      return AiAsyncEnhanceOutcome(
        transactionId: transactionId,
        status: AiAsyncEnhanceStatus.succeeded,
        billInfo: billInfo,
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

  Future<void> _applyBillInfo(
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
        details[trimmed] = true;
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
