import 'package:beecount/cloud/sync/entity_serializer.dart';
import 'package:beecount/data/db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction sync payload preserves pending-classification state', () {
    final payload = EntitySerializer.serializeTransaction(
      Transaction(
        id: 1,
        ledgerId: 2,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime.utc(2026, 7, 16),
        needsClassification: true,
        syncId: 'tx-pending-1',
      ),
    );

    expect(payload['needsClassification'], isTrue);
  });
}
