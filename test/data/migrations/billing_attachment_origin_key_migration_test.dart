import 'package:beecount/data/db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
      'v26 without attachment table creates the complete v28 attachment schema',
      () async {
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
      CREATE TABLE legacy_sentinel (
        id INTEGER NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );
      INSERT INTO legacy_sentinel (id, value) VALUES (1, 'preserved');
      PRAGMA user_version = 26;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final columns = await db
        .customSelect("PRAGMA table_info('transaction_attachments')")
        .get();
    expect(
      columns.map((row) => row.data['name']).toSet(),
      {
        'id',
        'transaction_id',
        'file_name',
        'origin_key',
        'original_name',
        'file_size',
        'width',
        'height',
        'sort_order',
        'cloud_file_id',
        'cloud_sha256',
        'created_at',
      },
    );
    final sentinel = await db
        .customSelect('SELECT value FROM legacy_sentinel WHERE id = 1')
        .getSingle();
    expect(sentinel.read<String>('value'), 'preserved');
    await _expectOriginKeyUniqueIndex(db);
  });

  test('v27 to v28 preserves attachments and adds the origin key index',
      () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE transaction_attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        original_name TEXT,
        file_size INTEGER,
        width INTEGER,
        height INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        cloud_file_id TEXT,
        cloud_sha256 TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE billing_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
      );
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        details_text TEXT
      );
    ''');
    underlying.execute('''
      INSERT INTO transaction_attachments (transaction_id, file_name)
      VALUES (61, 'legacy.avif');
    ''');
    underlying.execute('PRAGMA user_version = 27;');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT transaction_id, file_name, origin_key '
          'FROM transaction_attachments',
        )
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.data['transaction_id'], 61);
    expect(rows.single.data['file_name'], 'legacy.avif');
    expect(rows.single.data['origin_key'], isNull);
    await _expectOriginKeyUniqueIndex(db);
  });

  test('new v28 database creates the origin key unique index', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    await _expectOriginKeyUniqueIndex(db);
  });
}

Future<void> _expectOriginKeyUniqueIndex(BeeDatabase db) async {
  final indexes = await db
      .customSelect("PRAGMA index_list('transaction_attachments')")
      .get();
  final index = indexes.singleWhere(
    (row) => row.data['name'] == 'ux_transaction_attachments_origin_key',
  );
  expect(index.data['unique'], 1);
  expect(index.data['partial'], 1);

  final columns = await db
      .customSelect(
        "PRAGMA index_info('ux_transaction_attachments_origin_key')",
      )
      .get();
  expect(columns.map((row) => row.data['name']), ['origin_key']);
}
