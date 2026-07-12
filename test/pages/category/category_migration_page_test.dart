import 'package:beecount/data/repositories/category_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/category/category_migration_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('迁移影响预览展示全部五类引用数量', (tester) async {
    const preview = CategoryReferenceSummary(
      transactionCount: 1,
      budgetCount: 2,
      recurringTransactionCount: 3,
      subCategoryCount: 4,
      personalCategoryRuleCount: 5,
    );
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CategoryMigrationImpactSummary(preview: preview)),
    ));

    final finder = find.byKey(const Key('categoryMigrationImpactSummary'));
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder).data!;
    for (final count in ['1', '2', '3', '4', '5']) {
      expect(text, contains(count));
    }
  });
}
