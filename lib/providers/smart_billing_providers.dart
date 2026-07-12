import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/billing/bill_creation_service.dart';
import '../services/billing/pending_bill_confirmation_service.dart';
import '../services/billing/personal_category_rule_store.dart';
import '../services/billing/personal_note_preference_store.dart';
import '../services/billing/regression_sample_store.dart';
import '../services/billing/rules/billing_rule_engine_impl.dart';
import '../services/billing/rules/billing_rule_repository.dart';
import '../services/billing/rules/personal_rule_lifecycle_service.dart';
import 'database_providers.dart';

/// Android 分享入口发现待确认账单后设置；根页面消费并打开校正界面。
final pendingBillConfirmationJobIdProvider = StateProvider<int?>((ref) => null);

final pendingBillConfirmationServiceProvider =
    FutureProvider<PendingBillConfirmationService>((ref) async {
  final repo = ref.watch(billingJobRepositoryProvider);
  final database = ref.watch(databaseProvider);
  final baseRepository = ref.watch(repositoryProvider);
  final publicRules = await TomlBillingRuleRepository().loadActiveRuleSet();
  final lifecycle = PersonalRuleLifecycleService(
    engine: BillingRuleEngineImpl(),
    revisionStore: SqlitePersonalRuleRevisionStore(database),
    regressionSamples: const PlatformPersonalRuleRegressionSampleSource(
      RegressionSampleStore(),
    ),
    publicRules: publicRules,
  );
  final categoryRuleStore = SqlitePersonalCategoryRuleStore(database);
  final notePreferenceStore = SqlitePersonalNotePreferenceStore(database);
  final ledgerId = ref.read(currentLedgerIdProvider);
  return PendingBillConfirmationService(
    repo: repo,
    createTransaction: (result) async {
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
    applyCorrection: lifecycle.applyCorrection,
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
        {required matchText, required categoryId, required global}) async {
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
