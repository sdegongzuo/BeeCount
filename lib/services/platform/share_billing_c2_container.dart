import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db.dart';
import '../../providers/database_providers.dart';
import '../attachment_service.dart';
import 'share_billing_c2_fixture.dart';

class ShareBillingC2Container {
  final ShareBillingC2Fixture fixture;
  final BeeDatabase database;
  final ProviderContainer container;

  const ShareBillingC2Container._({
    required this.fixture,
    required this.database,
    required this.container,
  });

  static Future<ShareBillingC2Container> create(
    ShareBillingC2Fixture fixture, {
    QueryExecutor? executor,
  }) async {
    final database = BeeDatabase.forTesting(
      executor ?? _openFixtureDatabase(fixture),
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      attachmentStorageNamespaceProvider
          .overrideWithValue(fixture.attachmentDirectoryName),
    ]);
    await database.ensureSeed();
    return ShareBillingC2Container._(
      fixture: fixture,
      database: database,
      container: container,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

LazyDatabase _openFixtureDatabase(ShareBillingC2Fixture fixture) {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, fixture.databaseFileName));
    return NativeDatabase.createInBackground(
      file,
      setup: configureBeeDatabaseConnection,
    );
  });
}
