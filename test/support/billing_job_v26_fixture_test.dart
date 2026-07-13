import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'billing_job_v26_fixture.dart';

void main() {
  test('historical v26 fixture covers terminal, pending and failed recovery',
      () async {
    final file = File(
      '${Directory.systemTemp.path}/billing_job_v26_host_'
      '${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );

    await verifyHistoricalV26BillingJobUpgrade(file);
  });
}
