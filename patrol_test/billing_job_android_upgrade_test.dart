import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

import '../test/support/billing_job_v26_fixture.dart';

void main() {
  patrolTest('schema 26 Billing Job upgrades and resumes on Android',
      ($) async {
    await $.pumpWidget(const SizedBox.shrink());

    final directory = await getTemporaryDirectory();
    final databaseFile = File(p.join(
      directory.path,
      'billing_job_schema_26_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ));

    await verifyHistoricalV26BillingJobUpgrade(databaseFile);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
