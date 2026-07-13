import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/support/billing_job_v26_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '真实 v26 Billing Job 在 Android 升级到 v27 并幂等恢复',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final databaseFile = File(p.join(
        directory.path,
        'billing_job_v26_upgrade_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      ));

      await verifyHistoricalV26BillingJobUpgrade(databaseFile);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
