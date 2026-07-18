import 'package:beecount/data/db.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/services/billing/personal_category_rule_store.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:beecount/services/platform/share_billing_c2_container.dart';
import 'package:beecount/services/platform/share_billing_c2_fixture.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('fixture container seeds an isolated ledger and attachment namespace',
      () async {
    final production = ProviderContainer();
    addTearDown(production.dispose);
    final fixture = ShareBillingC2Fixture.resolve(
      compileTimeId: 'issue6-c2-20260716',
      runtimeId: 'issue6-c2-20260716',
      isDebug: true,
    )!;

    final runtime = await ShareBillingC2Container.create(
      fixture,
      executor: NativeDatabase.memory(),
    );
    addTearDown(runtime.dispose);

    expect(production.read(attachmentStorageNamespaceProvider), isNull);
    expect(
      runtime.container.read(attachmentStorageNamespaceProvider),
      fixture.attachmentDirectoryName,
    );
    final ledgers =
        await runtime.container.read(repositoryProvider).getAllLedgers();
    expect(ledgers, hasLength(1));
    expect(ledgers.single.syncId?.trim(), isNotEmpty,
        reason: 'production 默认账本必须现场生成跨设备稳定身份');
    final categories =
        await runtime.container.read(repositoryProvider).getAllCategories();
    expect(
      categories.where((category) => category.name == '其他'),
      hasLength(1),
      reason: 'C2 必须复用 production 中文 fallback 分类，不能在测试中伪造规则',
    );
    expect(
      categories,
      everyElement(predicate<Category>(
        (category) => category.syncId?.trim().isNotEmpty == true,
        'production seed 分类具有稳定 syncId',
      )),
    );
    final food = categories.singleWhere((category) => category.name == '餐饮');
    await SqlitePersonalCategoryRuleStore(runtime.database).remember(
      matchText: '真机同步商户',
      categorySyncId: food.syncId!,
      ledgerId: ledgers.single.id,
    );
    final pending =
        await PersonalRuleSyncRepository(runtime.database).pendingUpload();
    expect(
      pending.where((revision) =>
          revision.kind == PersonalRuleSyncKind.category &&
          revision.conditionKey == '真机同步商户'),
      hasLength(1),
      reason: 'production 默认账本上的当前账本规则必须生成待上传同步修订',
    );
    expect(
      runtime.container.read(databaseProvider),
      same(runtime.database),
    );
  });
}
