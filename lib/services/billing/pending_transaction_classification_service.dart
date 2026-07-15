import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import 'personal_category_rule_store.dart';

enum ClassificationMemoryScope {
  currentTransaction,
  currentLedger,
  global,
}

class PendingTransactionClassificationDraft {
  final Transaction transaction;
  final List<Category> categories;
  final List<TransactionAttachment> attachments;

  const PendingTransactionClassificationDraft({
    required this.transaction,
    required this.categories,
    required this.attachments,
  });

  String? get structuredSummary => transaction.note;
}

/// 已创建交易的待分类补正边界。
class PendingTransactionClassificationService {
  final LocalRepository repository;
  final SqlitePersonalCategoryRuleStore categoryRuleStore;

  PendingTransactionClassificationService(
    this.repository, {
    SqlitePersonalCategoryRuleStore? categoryRuleStore,
  }) : categoryRuleStore = categoryRuleStore ??
            SqlitePersonalCategoryRuleStore(repository.db) {
    if (!identical(this.categoryRuleStore.db, repository.db)) {
      throw ArgumentError('category_rule_store_must_share_repository_database');
    }
  }

  Future<List<PendingTransactionClassificationDraft>> listPending({
    required int ledgerId,
  }) async {
    final transactions = await repository.getPendingClassificationTransactions(
        ledgerId: ledgerId);
    return Future.wait(transactions.map(_draftFor));
  }

  Future<PendingTransactionClassificationDraft?> loadDraft({
    required int ledgerId,
    required int transactionId,
  }) async {
    final transaction = await repository.getTransactionById(transactionId);
    if (transaction == null ||
        transaction.ledgerId != ledgerId ||
        !transaction.needsClassification) {
      return null;
    }
    return _draftFor(transaction);
  }

  Future<void> confirmClassification({
    required int ledgerId,
    required int transactionId,
    required int categoryId,
    required ClassificationMemoryScope memoryScope,
  }) {
    return repository.db.transaction(() async {
      final transaction = await repository.getTransactionById(transactionId);
      if (transaction == null ||
          transaction.ledgerId != ledgerId ||
          !transaction.needsClassification) {
        throw StateError('transaction_not_pending_classification');
      }
      final availableCategories =
          await repository.getUsableCategories(transaction.type);
      Category? category;
      for (final candidate in availableCategories) {
        if (candidate.id == categoryId) {
          category = candidate;
          break;
        }
      }
      if (category == null) {
        throw StateError('classification_category_not_available');
      }

      String? matchText;
      if (memoryScope != ClassificationMemoryScope.currentTransaction) {
        matchText = _classificationMatchText(transaction);
        if (matchText == null) {
          throw StateError('classification_rule_evidence_missing');
        }
        if (category.syncId?.trim().isEmpty ?? true) {
          throw StateError('classification_category_sync_id_missing');
        }
      }

      await repository.updateTransaction(
        id: transaction.id,
        type: transaction.type,
        amount: transaction.amount,
        categoryId: category.id,
        note: transaction.note,
        needsClassification: false,
      );

      if (matchText != null) {
        await categoryRuleStore.remember(
          matchText: matchText,
          categorySyncId: category.syncId!,
          ledgerId: memoryScope == ClassificationMemoryScope.currentLedger
              ? transaction.ledgerId
              : null,
        );
      }
    });
  }

  Future<PendingTransactionClassificationDraft> _draftFor(
    Transaction transaction,
  ) async {
    final categories = await repository.getUsableCategories(transaction.type);
    final attachments =
        await repository.getAttachmentsByTransaction(transaction.id);
    return PendingTransactionClassificationDraft(
      transaction: transaction,
      categories: categories,
      attachments: attachments,
    );
  }
}

String? _classificationMatchText(Transaction transaction) {
  for (final candidate in <String?>[
    transaction.merchantFullName,
    transaction.counterparty,
    _merchantFromStructuredSummary(transaction.note),
  ]) {
    final normalized = candidate?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

String? _merchantFromStructuredSummary(String? summary) {
  if (summary == null || summary.trim().isEmpty) return null;
  final match = RegExp(r'(?:^|\n)\s*商户\s*[：:]\s*([^\n]+)').firstMatch(summary);
  return match?.group(1)?.trim();
}
