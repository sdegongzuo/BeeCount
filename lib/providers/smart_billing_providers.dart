import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/local/local_repository.dart';
import '../services/billing/bill_creation_service.dart';
import '../services/billing/billing_job_service.dart';
import '../services/billing/pending_bill_confirmation_service.dart';
import '../services/billing/pending_transaction_classification_service.dart';
import '../services/billing/personal_category_rule_store.dart';
import '../services/billing/personal_note_preference_store.dart';
import '../services/billing/rules/personal_rule_lifecycle_service.dart';
import 'database_providers.dart';

/// Android 分享入口发现待确认账单后设置；根页面消费并打开校正界面。
final pendingBillConfirmationJobIdProvider = StateProvider<int?>((ref) => null);

/// 主 Flutter engine 创建待分类交易后设置；根页面消费并打开补正界面。
final pendingTransactionClassificationIdProvider =
    StateProvider<int?>((ref) => null);

/// 待分类查询与原子补正的生产服务。
final pendingTransactionClassificationServiceProvider =
    Provider<PendingTransactionClassificationService>((ref) {
  final repository = ref.watch(repositoryProvider);
  if (repository is! LocalRepository) {
    throw StateError('pending_classification_requires_local_repository');
  }
  return PendingTransactionClassificationService(repository);
});

final pendingBillConfirmationServiceProvider =
    FutureProvider<PendingBillConfirmationService>((ref) async {
  final repo = ref.watch(billingJobRepositoryProvider);
  final database = ref.watch(databaseProvider);
  final baseRepository = ref.watch(repositoryProvider);
  Future<PersonalRuleLifecycleService>? lifecycle;
  final categoryRuleStore = SqlitePersonalCategoryRuleStore(database);
  final notePreferenceStore = SqlitePersonalNotePreferenceStore(database);
  return PendingBillConfirmationService(
    repo: repo,
    createTransaction: (result, {required ledgerId}) async {
      final id = await BillCreationService(
        baseRepository,
        personalCategoryRules: categoryRuleStore,
        personalNotePreferences: notePreferenceStore,
      ).createBillTransaction(
        result: result,
        ledgerId: ledgerId,
        billingTypes: const ['image'],
      );
      if (id == null) throw StateError('confirmed_bill_not_created');
      return id;
    },
    // 打开确认页、只确认当前账单或只记住分类/备注时不需要加载 TOML
    // 与平台路径。仅在用户明确选择“记住提取修正”时延迟构造门禁。
    applyCorrection: (correction) async {
      lifecycle ??=
          BillingJobService.createProductionPersonalRuleLifecycle(database);
      return (await lifecycle!).applyCorrection(correction);
    },
    loadCategories: () async {
      final top = await baseRepository.getTopLevelCategories('expense');
      final all = <ConfirmableCategory>[];
      for (final category in top) {
        final children = await baseRepository.getSubCategories(category.id);
        if (children.isEmpty) {
          all.add(ConfirmableCategory(category.id, category.name));
        } else {
          all.addAll(children.map((child) => ConfirmableCategory(
              child.id, '${category.name} / ${child.name}')));
        }
      }
      return all;
    },
    rememberCategory: (
        {required matchText,
        required categoryId,
        required global,
        required ledgerId}) async {
      final category = await baseRepository.getCategoryById(categoryId);
      final syncId = category?.syncId;
      if (syncId == null || syncId.isEmpty) {
        throw StateError('category_sync_id_missing');
      }
      await categoryRuleStore.remember(
        matchText: matchText,
        categorySyncId: syncId,
        ledgerId: global ? null : ledgerId,
      );
    },
    rememberNotePreference: (
        {required matchText, required supplementalNote}) async {
      await notePreferenceStore.remember(
        matchText: matchText,
        supplementalNote: supplementalNote,
      );
    },
  );
});

enum SmartBillingAttachmentFormat {
  jpeg('jpeg'),
  webp('webp'),
  avif('avif');

  const SmartBillingAttachmentFormat(this.storageKey);

  final String storageKey;

  static SmartBillingAttachmentFormat fromStorageKey(String? value) {
    return SmartBillingAttachmentFormat.values.firstWhere(
      (format) => format.storageKey == value,
      orElse: () => SmartBillingAttachmentFormat.jpeg,
    );
  }
}

/// 智能记账自动关联标签开关（默认开启）
final smartBillingAutoTagsProvider = StateProvider<bool>((ref) => true);

/// 智能记账自动添加附件开关（默认开启）
final smartBillingAutoAttachmentProvider = StateProvider<bool>((ref) => true);

/// 智能记账自动附件保存格式（默认沿用 JPEG 压缩）
final smartBillingAttachmentFormatProvider =
    StateProvider<SmartBillingAttachmentFormat>(
        (ref) => SmartBillingAttachmentFormat.jpeg);

/// 智能记账自动附件图片质量（默认 80）
final smartBillingAttachmentQualityProvider = StateProvider<int>((ref) => 80);

/// 智能记账自动关联标签持久化初始化
final smartBillingAutoTagsInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('smartBillingAutoTags');
  if (saved != null) {
    ref.read(smartBillingAutoTagsProvider.notifier).state = saved;
  }
  ref.listen<bool>(smartBillingAutoTagsProvider, (prev, next) async {
    await prefs.setBool('smartBillingAutoTags', next);
  });
});

/// 智能记账自动添加附件持久化初始化
final smartBillingAutoAttachmentInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('smartBillingAutoAttachment');
  if (saved != null) {
    ref.read(smartBillingAutoAttachmentProvider.notifier).state = saved;
  }
  ref.listen<bool>(smartBillingAutoAttachmentProvider, (prev, next) async {
    await prefs.setBool('smartBillingAutoAttachment', next);
  });
});

/// 智能记账自动附件保存格式持久化初始化
final smartBillingAttachmentFormatInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('smartBillingAttachmentFormat');
  ref.read(smartBillingAttachmentFormatProvider.notifier).state =
      SmartBillingAttachmentFormat.fromStorageKey(saved);
  ref.listen<SmartBillingAttachmentFormat>(smartBillingAttachmentFormatProvider,
      (prev, next) async {
    await prefs.setString('smartBillingAttachmentFormat', next.storageKey);
  });
});

/// 智能记账自动附件图片质量持久化初始化
final smartBillingAttachmentQualityInitProvider =
    FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('smartBillingAttachmentQuality');
  if (saved != null) {
    ref.read(smartBillingAttachmentQualityProvider.notifier).state =
        saved.clamp(5, 100);
  }
  ref.listen<int>(smartBillingAttachmentQualityProvider, (prev, next) async {
    await prefs.setInt('smartBillingAttachmentQuality', next.clamp(5, 100));
  });
});
