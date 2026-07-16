import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/services/billing/fast_billing_rule_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/personal_note_preference_store.dart';
import 'package:beecount/services/billing/rules/billing_rule_engine_impl.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:beecount/services/data/seed_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'Bill Creation');
    final expenseFallbackId =
        await repo.createCategory(name: '其他', kind: 'expense');
    await (db.update(db.categories)
          ..where((category) => category.id.equals(expenseFallbackId)))
        .write(CategoriesCompanion(
      syncId: Value(SeedService.categorySyncId('expense', 'other')),
    ));
    await repo.createCategory(name: '其他退费', kind: 'income');
  });

  tearDown(() async {
    await db.close();
  });

  test('keeps negative OCR amount as expense when text has trailing plus noise',
      () async {
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '''
账单详情
支付宝
-3.75
自动扣款成功
支付时间
2026-07-03 23:30:20
更多
+++
0
<''',
        amount: -3.75,
        note: 'ETC服务',
        time: DateTime(2026, 7, 3, 23, 30, 20),
        paymentChannel: '支付宝',
        allNumbers: const ['3.75', '3'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    expect(transactionId, isNotNull);
    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.type, 'expense');
    expect(transaction?.amount, 3.75);
    expect(transaction?.note, isNull);
  });

  test('图片分享分类与备注不消费 AI 输出', () async {
    final foodId = await repo.createCategory(name: '餐饮', kind: 'expense');
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '天津海河测试餐厅甲 咖啡 支付成功',
        amount: 28,
        time: DateTime(2026, 7, 12),
        note: '天津海河测试餐厅甲',
        merchantFullName: '天津海河测试餐厅甲',
        details: const {'product_summary': '海河测试饮品甲', 'store_name': '天津和平测试门店甲'},
        aiCategoryName: '交通',
        allNumbers: const ['28'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, foodId);
    expect(transaction?.needsClassification, isFalse);
    expect(transaction?.note, '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲\n门店：天津和平测试门店甲');
  });

  test('图片分享优先使用图片中的商户字段做确定性分类', () async {
    final foodCategoryId =
        await repo.createCategory(name: '餐饮', kind: 'expense');
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '滴滴 支付成功',
        amount: 28,
        time: DateTime(2026, 7, 12),
        allNumbers: const ['28'],
        merchantFullName: '天津海河测试餐厅甲',
        aiCategoryName: '交通',
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, foodCategoryId);
  });

  test('TOML 页面规则分类进入图片生产创建链且优先于商户词典', () async {
    await repo.createCategory(name: '餐饮', kind: 'expense');
    final travelCategoryId =
        await repo.createCategory(name: '交通', kind: 'expense');
    final travelCategory = await repo.getCategoryById(travelCategoryId);
    final rules = TomlBillingRuleRepository(
      assetBundle: _StringAssetBundle({
        TomlBillingRuleRepository.defaultBuiltInAssetPath: '''
schemaVersion = 1
rulesVersion = "page-category-test"

[[templates]]
id = "page_category"
priority = 100
baseConfidence = 0.9

[templates.match]
keywordsAll = ["账单详情", "支付成功"]

[[templates.extract]]
field = "details.category_sync_id"
type = "constant"
value = "${travelCategory!.syncId}"
confidence = 0.9
''',
      }),
    );
    final evaluated = await FastBillingRuleService(
      ruleRepository: rules,
      ruleEngine: BillingRuleEngineImpl(),
    ).evaluate(
      baseResult: OcrResult(
        rawText: '账单详情\n天津海河测试餐厅甲\n支付成功',
        amount: -28,
        time: DateTime(2026, 7, 17),
        paymentChannel: '微信支付',
        allNumbers: const ['28'],
      ),
    );

    final transactionId = await BillCreationService(repo).createBillTransaction(
      result: evaluated.result,
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, travelCategoryId);
    expect(transaction?.needsClassification, isFalse);
  });

  test('图片自动分类不使用任意备注作为个人规则证据', () async {
    final foodCategoryId =
        await repo.createCategory(name: '餐饮', kind: 'expense');
    final foodCategory = await repo.getCategoryById(foodCategoryId);
    final rules = SqlitePersonalCategoryRuleStore(db);
    await rules.remember(
      matchText: '只在备注中的商户',
      categorySyncId: foodCategory!.syncId!,
      ledgerId: ledgerId,
    );

    final transactionId = await BillCreationService(
      repo,
      personalCategoryRules: rules,
    ).createBillTransaction(
      result: OcrResult(
        rawText: '支付成功 18.00',
        amount: -18,
        time: DateTime(2026, 7, 17),
        note: '只在备注中的商户',
        allNumbers: const ['18'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, isNot(foodCategoryId));
    expect(transaction?.needsClassification, isTrue);
  });

  test('图片自动分类可使用有页面规则来源的结构化摘要商户', () async {
    final foodCategoryId =
        await repo.createCategory(name: '餐饮', kind: 'expense');
    final foodCategory = await repo.getCategoryById(foodCategoryId);
    final rules = SqlitePersonalCategoryRuleStore(db);
    await rules.remember(
      matchText: '摘要商户',
      categorySyncId: foodCategory!.syncId!,
      ledgerId: ledgerId,
    );
    const structuredSummary = '商户：摘要商户\n商品：午餐';

    final transactionId = await BillCreationService(
      repo,
      personalCategoryRules: rules,
    ).createBillTransaction(
      result: OcrResult(
        rawText: '支付成功 18.00',
        amount: -18,
        time: DateTime(2026, 7, 17),
        note: structuredSummary,
        billingRuleResult: const BillingRuleResult(
          matchedTemplateId: 'structured_summary_rule',
          fields: {
            'note': BillingRuleFieldResult(
              field: 'note',
              value: structuredSummary,
              confidence: 0.9,
              extractorType: 'constant',
            ),
          },
        ),
        allNumbers: const ['18'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction?.categoryId, foodCategoryId);
    expect(transaction?.needsClassification, isFalse);
  });

  for (final scenario in const [
    ('英文支出', 'expense', 'Other', -18.0, '支付成功', false),
    ('中文收入', 'income', '其他收入', 18.0, '收款成功', true),
    ('英文收入', 'income', 'Other income', 18.0, '收款成功', true),
  ]) {
    test('${scenario.$1}稳定兜底身份不阻断图片个人分类', () async {
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: scenario.$3,
              kind: scenario.$2,
              syncId: Value(scenario.$6
                  ? SeedService.categorySyncId(scenario.$2, 'other')
                  : 'legacy-expense-fallback'),
            ),
          );
      final targetId = await repo.createCategory(
          name: '目标-${scenario.$1}', kind: scenario.$2);
      final target = await repo.getCategoryById(targetId);
      final rules = SqlitePersonalCategoryRuleStore(db);
      await rules.remember(
        matchText: '稳定商户',
        categorySyncId: target!.syncId!,
        ledgerId: ledgerId,
      );

      final transactionId = await BillCreationService(
        repo,
        personalCategoryRules: rules,
      ).createBillTransaction(
        result: OcrResult(
          rawText: '${scenario.$5} 18.00',
          amount: scenario.$4,
          merchantFullName: '稳定商户',
          time: DateTime(2026, 7, 17),
          allNumbers: const ['18'],
        ),
        ledgerId: ledgerId,
        billingTypes: const ['image'],
        autoAddTags: false,
      );

      final transaction = await repo.getTransactionById(transactionId!);
      expect(transaction?.categoryId, targetId);
      expect(transaction?.needsClassification, isFalse);
    });
  }

  test('图片分享无法可靠分类时仍创建到其他并记录待分类', () async {
    final service = BillCreationService(repo);
    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '未知服务 支付成功',
        amount: 12,
        time: DateTime(2026, 7, 12),
        allNumbers: const ['12'],
      ),
      ledgerId: ledgerId,
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction, isNotNull);
    expect(transaction?.needsClassification, isTrue);
    expect(transaction?.detailsText, isNot(contains('待分类：是')));
  });

  test('图片主备注只保留可验证字段，补充信息与已有明细显式合并', () async {
    final notePreferences = SqlitePersonalNotePreferenceStore(db);
    await notePreferences.remember(
      matchText: '天津海河测试餐厅甲',
      supplementalNote: '同一条补充',
    );
    final service = BillCreationService(
      repo,
      personalNotePreferences: notePreferences,
    );

    final transactionId = await service.createBillTransaction(
      result: OcrResult(
        rawText: '天津海河测试餐厅甲 支付成功 28.00',
        amount: 28,
        time: DateTime(2026, 7, 16),
        merchantFullName: '天津海河测试餐厅甲',
        note: '不可验证的 AI 备注',
        detailsText: '交易单号: OCR-123\n 补充信息 : 同一条补充 ',
        details: const {
          'product_summary': '海河测试饮品甲',
          'store_name': '天津和平测试门店甲',
          'supplemental_note': '同一条补充',
        },
        allNumbers: const ['28.00'],
      ),
      ledgerId: ledgerId,
      note: '同一条补充',
      billingTypes: const ['image'],
      autoAddTags: false,
    );

    final transaction = await repo.getTransactionById(transactionId!);
    expect(transaction!.note, '商户：天津海河测试餐厅甲\n商品：海河测试饮品甲\n门店：天津和平测试门店甲');
    expect(transaction.note, isNot(contains('AI 备注')));
    expect(transaction.note, isNot(contains('同一条补充')));
    expect(transaction.detailsText, contains('交易单号：OCR-123'));
    expect(
      RegExp('补充信息：同一条补充').allMatches(transaction.detailsText!).length,
      1,
    );
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _StringAssetBundle(this.assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) throw StateError('Missing test asset: $key');
    return value;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}
