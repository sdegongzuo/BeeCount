import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/analytics/analytics_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays cumulative discount amount', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnalyticsSummary(
              scope: 'month',
              isExpense: true,
              total: 8.9,
              avg: 8.9,
              discountTotal: 1.23,
            ),
          ),
        ),
      ),
    );

    expect(find.text('累计优惠： '), findsOneWidget);
    expect(find.text('1.23'), findsOneWidget);
  });
}
