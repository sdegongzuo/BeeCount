import 'package:beecount/data/db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v32 到 v33 新增可空优惠金额并保留既有交易', () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        happened_at INTEGER NOT NULL
      );
      CREATE TABLE transaction_attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        origin_key TEXT
      );
      INSERT INTO transactions (
        ledger_id, type, amount, happened_at
      ) VALUES (7, 'expense', 8.9, 1);
      PRAGMA user_version = 32;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT ledger_id, amount, discount_amount FROM transactions WHERE id = 1',
        )
        .getSingle();
    expect(row.data['ledger_id'], 7);
    expect(row.data['amount'], 8.9);
    expect(row.data['discount_amount'], isNull);
  });
}
