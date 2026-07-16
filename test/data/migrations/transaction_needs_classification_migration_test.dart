import 'package:beecount/data/db.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v29 to v30 leaves legacy billing jobs unscoped instead of guessing',
      () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE billing_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL DEFAULT 'image_share',
        status TEXT NOT NULL DEFAULT 'pending',
        stage TEXT NOT NULL DEFAULT 'received',
        transaction_id INTEGER,
        image_path TEXT NOT NULL,
        raw_text TEXT,
        ocr_engine TEXT,
        source_info_json TEXT,
        rule_result_json TEXT,
        final_result_json TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        lease_until INTEGER,
        attachment_done INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        completed_at INTEGER
      );
      CREATE TABLE transaction_attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        origin_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      INSERT INTO billing_jobs (image_path) VALUES ('/tmp/legacy.png');
      PRAGMA user_version = 29;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT ledger_id FROM billing_jobs WHERE id = 1',
        )
        .getSingle();
    expect(row.data['ledger_id'], null);
  });

  test('v28 to v29 backfills the legacy pending-classification marker',
      () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER,
        account_id INTEGER,
        to_account_id INTEGER,
        happened_at INTEGER NOT NULL,
        note TEXT,
        payment_method TEXT,
        counterparty TEXT,
        payment_channel TEXT,
        merchant_full_name TEXT,
        acquirer TEXT,
        details_text TEXT,
        recurring_id INTEGER,
        sync_id TEXT
      );
      CREATE TABLE transaction_attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        origin_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      INSERT INTO transactions (
        ledger_id, type, amount, happened_at, details_text
      ) VALUES
        (1, 'expense', 12.0, 1, '商户：未知\n待分类：是'),
        (1, 'expense', 20.0, 2, '普通补充信息');
      PRAGMA user_version = 28;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final rows = await (db.select(db.transactions)
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    expect(rows.map((row) => row.needsClassification), [true, false]);
    expect(rows.first.detailsText, '商户：未知\n待分类：是');
  });

  test('new transactions default to not needing classification', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 8,
          ),
        );

    final transaction = await (db.select(db.transactions)
          ..where((row) => row.id.equals(id)))
        .getSingle();
    expect(transaction.needsClassification, isFalse);
  });
}
