import 'package:beecount/data/db.dart';
import 'package:beecount/services/billing/rules/billing_rule_models.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生产组装默认使用真实黄金评测、加密样本回归和个人裁决落库', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = createProductionBillingRuleUpdateService(
      configuration: BillingRuleUpdateConfiguration.fromValues(
        manifestUrl: 'https://rules.test/manifest.json',
        currentAppVersion: '1.0.0',
      ),
      database: db,
    );
    const invalidCandidate = BillingRuleSet(
      schemaVersion: 1,
      rulesVersion: 'candidate',
      paymentChannels: [],
      templates: [],
    );

    expect(await service.upgradeEvaluation(invalidCandidate), isFalse);
    final regression = await service.personalRegression(invalidCandidate);
    expect(regression.isPassed, isFalse);
    expect(service.personalRuleReconciler, isNotNull);
  });
}
