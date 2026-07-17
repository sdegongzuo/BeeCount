import 'package:beecount/data/db.dart';
import 'package:beecount/pages/settings/personal_rule_conflicts_page.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_repository.dart';
import 'package:beecount/services/billing/rules/personal_rule_sync_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('普通用户可查看分类冲突并选择一个版本立即恢复', (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '餐饮',
          kind: 'expense',
          syncId: const Value('category-food'),
        ));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '交通',
          kind: 'expense',
          syncId: const Value('category-travel'),
        ));
    final repository = PersonalRuleSyncRepository(db);
    PersonalRuleRevision revision(String id, String device, String target) =>
        PersonalRuleRevision(
          revisionId: id,
          ruleId: 'category:global:天津海河测试餐厅甲',
          originDeviceId: device,
          originVersion: 1,
          kind: PersonalRuleSyncKind.category,
          scopeKey: 'global',
          conditionKey: '天津海河测试餐厅甲',
          payload: {
            'match_text': '天津海河测试餐厅甲',
            'category_sync_id': target,
          },
        );
    await repository.mergeRemote(
      [
        revision('food', 'device-a', 'category-food'),
        revision('travel', 'device-b', 'category-travel'),
      ],
      localDeviceId: 'local-device',
    );

    await tester.pumpWidget(MaterialApp(
      home: PersonalRuleConflictsPage(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('个人规则冲突'), findsOneWidget);
    expect(find.textContaining('天津海河测试餐厅甲'), findsWidgets);
    expect(find.text('分类：餐饮'), findsOneWidget);
    expect(find.text('分类：交通'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '采用此版本').first);
    await tester.pumpAndSettle();
    expect(find.text('确认采用这个版本？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认解决'));
    await tester.pumpAndSettle();

    expect(find.text('当前没有待解决冲突'), findsOneWidget);
    expect(await repository.listConflicts(), isEmpty);
    expect((await repository.pendingUpload()), hasLength(1));
  });
}
