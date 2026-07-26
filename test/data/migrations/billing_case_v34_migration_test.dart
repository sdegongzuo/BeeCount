import 'package:beecount/data/db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v34 migration creates the V2 billing workflow tables', () async {
    // 起点是一个旧数据库（schemaVersion 33），只含 billing_jobs。
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE billing_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        stage TEXT NOT NULL
      );
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        details_text TEXT
      );
      CREATE TABLE transaction_attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        origin_key TEXT
      );
      CREATE TABLE legacy_sentinel (
        id INTEGER NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );
      INSERT INTO legacy_sentinel (id, value) VALUES (1, 'preserved');
      PRAGMA user_version = 33;
    ''');

    final db = BeeDatabase.forTesting(
      NativeDatabase.opened(underlying, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);

    // 旧 Billing Job 数据保留。
    final sentinel = await db
        .customSelect('SELECT value FROM legacy_sentinel WHERE id = 1')
        .getSingle();
    expect(sentinel.read<String>('value'), 'preserved');

    // 新 V2 表全部创建。
    for (final table in [
      'billing_cases',
      'billing_automation_tasks',
      'billing_user_tasks',
      'billing_prepared_attachments',
      'billing_outbox',
      'billing_case_artifacts',
    ]) {
      final cols = await db
          .customSelect("PRAGMA table_info('$table')")
          .get();
      expect(cols, isNotEmpty, reason: '$table should exist');
    }

    // request_id 全局唯一。
    await expectUniqueIndex(db, 'billing_cases', 'ux_billing_cases_request_id');
    // 一个 Case 最多一笔交易。
    await expectUniqueIndex(
        db, 'billing_cases', 'ux_billing_cases_transaction_id');
    // 每类任务在同 Case 内唯一。
    await expectUniqueIndex(
        db, 'billing_automation_tasks', 'ux_billing_automation_case_kind');
    await expectUniqueIndex(
        db, 'billing_user_tasks', 'ux_billing_user_tasks_case_kind');

    underlying.close();
  });

  test('全新数据库创建 V2 表与索引', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    for (final table in [
      'billing_cases',
      'billing_automation_tasks',
      'billing_user_tasks',
      'billing_prepared_attachments',
      'billing_outbox',
      'billing_case_artifacts',
    ]) {
      final cols =
          await db.customSelect("PRAGMA table_info('$table')").get();
      expect(cols, isNotEmpty, reason: '$table should exist on fresh db');
    }
    await expectUniqueIndex(db, 'billing_cases', 'ux_billing_cases_request_id');
  });

  test('request_id 唯一约束阻止重复插入', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO billing_cases (request_id, source_image_path, state) "
      "VALUES ('dup', '/tmp/a.png', 'accepted');",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO billing_cases (request_id, source_image_path, state) "
        "VALUES ('dup', '/tmp/b.png', 'accepted');",
      ),
      throwsA(isA<Object>()),
    );
  });

  test('一个 Case 最多一笔交易约束', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO billing_cases (request_id, source_image_path, state, transaction_id) "
      "VALUES ('c1', '/tmp/a.png', 'completed', 100);",
    );
    // 第二个 Case 引用同一 transaction_id 必须失败：每个 Case 至多一笔交易，
    // 且一笔交易只能被一个 Case 引用。
    expect(
      () => db.customStatement(
        "INSERT INTO billing_cases (request_id, source_image_path, state, transaction_id) "
        "VALUES ('c2', '/tmp/b.png', 'completed', 100);",
      ),
      throwsA(isA<Object>()),
    );
    // transaction_id 为 NULL 的 Case 不受约束，可以多条。
    await db.customStatement(
      "INSERT INTO billing_cases (request_id, source_image_path, state) "
      "VALUES ('c3', '/tmp/c.png', 'accepted');",
    );
    await db.customStatement(
      "INSERT INTO billing_cases (request_id, source_image_path, state) "
      "VALUES ('c4', '/tmp/d.png', 'accepted');",
    );
  });
}

Future<void> expectUniqueIndex(
  BeeDatabase db,
  String table,
  String indexName,
) async {
  final indexes =
      await db.customSelect("PRAGMA index_list('$table')").get();
  final index = indexes.singleWhere(
    (row) => row.data['name'] == indexName,
    orElse: () => throw StateError(
        '$indexName should exist on $table'),
  );
  expect(index.data['unique'], 1,
      reason: '$indexName should be unique on $table');
}
