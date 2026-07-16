import 'package:beecount/data/db.dart';
import 'package:beecount/services/data/seed_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v30 到 v31 回填空 syncId 并为已有中文库补齐两个稳定兜底分类', () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        level INTEGER NOT NULL DEFAULT 1,
        icon_type TEXT NOT NULL DEFAULT 'material',
        custom_icon_path TEXT,
        community_icon_id TEXT,
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
      INSERT INTO categories (name, kind, sync_id)
      VALUES ('餐饮', 'expense', NULL),
             ('工资', 'income', 'existing-income'),
             ('其他', 'expense', NULL),
             ('其他收入', 'income', NULL);
      PRAGMA user_version = 30;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final categories = await db.select(db.categories).get();
    expect(
      categories.singleWhere((category) => category.name == '餐饮').syncId,
      isNotEmpty,
    );
    expect(
      categories.singleWhere((category) => category.name == '工资').syncId,
      'existing-income',
    );
    expect(
      categories.singleWhere((category) => category.name == '其他').syncId,
      SeedService.categorySyncId('expense', 'other'),
    );
    expect(
      categories.singleWhere((category) => category.name == '其他收入').syncId,
      SeedService.categorySyncId('income', 'other'),
    );
  });

  test('v31 为已有英文支出与收入兜底赋确定性标识而非随机值', () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        level INTEGER NOT NULL DEFAULT 1,
        icon_type TEXT NOT NULL DEFAULT 'material',
        custom_icon_path TEXT,
        community_icon_id TEXT,
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
      INSERT INTO categories (name, kind, sync_id)
      VALUES ('Dining', 'expense', NULL),
             ('Salary', 'income', NULL),
             ('Other', 'expense', NULL),
             ('Misc', 'expense', NULL),
             ('Other income', 'income', NULL);
      PRAGMA user_version = 30;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final categories = await db.select(db.categories).get();
    expect(
      categories.singleWhere((category) => category.name == 'Other').syncId,
      SeedService.categorySyncId('expense', 'other'),
    );
    expect(
      categories
          .singleWhere((category) => category.name == 'Other income')
          .syncId,
      SeedService.categorySyncId('income', 'other'),
    );
    expect(
      categories.singleWhere((category) => category.name == 'Misc').syncId,
      isNot(SeedService.categorySyncId('expense', 'other')),
    );
  });

  test('v31 保留既有 fallback 云身份及个人规则和待上传修订引用', () async {
    final underlying = sqlite.sqlite3.openInMemory();
    underlying.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        level INTEGER NOT NULL DEFAULT 1,
        icon_type TEXT NOT NULL DEFAULT 'material',
        custom_icon_path TEXT,
        community_icon_id TEXT,
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
      CREATE TABLE personal_category_rules (
        match_text TEXT NOT NULL,
        category_sync_id TEXT NOT NULL,
        ledger_id INTEGER,
        scope_key TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE personal_rule_sync_revisions (
        revision_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        sync_state TEXT NOT NULL
      );
      INSERT INTO categories (name, kind, sync_id)
      VALUES ('Other', 'expense', 'legacy-expense'),
             ('Misc', 'expense', 'legacy-misc'),
             ('Other income', 'income', 'legacy-income');
      INSERT INTO personal_category_rules
        (match_text, category_sync_id, scope_key, updated_at)
      VALUES ('coffee', 'legacy-expense', 'global', 1);
      INSERT INTO personal_rule_sync_revisions
        (revision_id, payload_json, sync_state)
      VALUES ('r1', '{"category_sync_id":"legacy-income"}', 'pending_upload');
      PRAGMA user_version = 30;
    ''');

    final db = BeeDatabase.forTesting(NativeDatabase.opened(underlying));
    addTearDown(db.close);

    final categories = await db.select(db.categories).get();
    expect(
      categories.singleWhere((category) => category.name == 'Other').syncId,
      'legacy-expense',
    );
    expect(
      categories.singleWhere((category) => category.name == 'Misc').syncId,
      'legacy-misc',
    );
    expect(
      categories
          .singleWhere((category) => category.name == 'Other income')
          .syncId,
      'legacy-income',
    );
    final rule = await db
        .customSelect(
          'SELECT category_sync_id FROM personal_category_rules',
        )
        .getSingle();
    expect(rule.read<String>('category_sync_id'), 'legacy-expense');
    final queued = await db
        .customSelect(
          'SELECT payload_json FROM personal_rule_sync_revisions',
        )
        .getSingle();
    expect(queued.read<String>('payload_json'), contains('legacy-income'));
  });
}
