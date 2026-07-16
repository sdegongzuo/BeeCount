import 'package:beecount/cloud/sync/sync_providers.dart' as cloud_sync;
import 'package:beecount/data/db.dart';
import 'package:beecount/providers/sync_providers.dart' as app_sync;
import 'package:beecount/services/billing/billing_job_service.dart';
import 'package:beecount/services/billing/ocr_service.dart';
import 'package:beecount/services/billing/rules/billing_rule_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OCR、BillingJob 与两条同步生产装配共享同一个公共规则仓库', () async {
    final expected = productionBillingRuleRepository();
    final database = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final ocrRules = OcrService.createProductionRuleService().ruleRepository;
    final billingJobRules = BillingJobService.createProductionRuleService(
      database,
    ).ruleRepository as ActiveBillingRuleRepository;

    expect(identical(ocrRules, expected), isTrue);
    expect(identical(billingJobRules.publicRepository, expected), isTrue);
    expect(
      identical(cloud_sync.productionSyncPublicRuleRepository(), expected),
      isTrue,
    );
    expect(
      identical(app_sync.productionSyncPublicRuleRepository(), expected),
      isTrue,
    );
  });
}
