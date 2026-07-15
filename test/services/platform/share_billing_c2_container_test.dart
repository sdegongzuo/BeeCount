import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/attachment_service.dart';
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
    expect(await runtime.container.read(repositoryProvider).getAllLedgers(),
        hasLength(1));
    expect(
      runtime.container.read(databaseProvider),
      same(runtime.database),
    );
  });
}
