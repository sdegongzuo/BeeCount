import 'dart:collection';

import 'package:beecount/services/billing/billing_attachment_identity.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CountingSet extends SetBase<String> {
  final Set<String> _values;
  int containsCalls = 0;

  _CountingSet(Iterable<String> values) : _values = values.toSet();

  @override
  bool contains(Object? element) {
    containsCalls++;
    return _values.contains(element);
  }

  @override
  Iterator<String> get iterator =>
      throw StateError('recovery lookup must not iterate the file index');

  @override
  int get length => _values.length;

  @override
  String? lookup(Object? element) => _values.lookup(element);

  @override
  Set<String> toSet() => _values.toSet();

  @override
  bool add(String value) => _values.add(value);

  @override
  bool remove(Object? value) => _values.remove(value);
}

void main() {
  test('builds the stable origin key, base name, and file candidates', () {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );

    expect(identity.originKey, 'billing:9:0');
    expect(identity.baseName, 'tx_61_9_0');
    expect(
      identity.candidateFileNames,
      ['tx_61_9_0.avif', 'tx_61_9_0.webp', 'tx_61_9_0.jpg'],
    );
  });

  test('finds a candidate with fixed contains lookups and no iteration', () {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );
    final names = _CountingSet([
      for (var i = 0; i < 10000; i++) 'unrelated_$i.jpg',
      'tx_61_9_0.webp',
    ]);

    expect(identity.findExisting(names), 'tx_61_9_0.webp');
    expect(names.containsCalls, 2);
  });

  test('a miss performs at most one contains per supported extension', () {
    const identity = BillingAttachmentIdentity(
      transactionId: 61,
      billingJobId: 9,
      index: 0,
    );
    final names = _CountingSet(['other.jpg']);

    expect(identity.findExisting(names), isNull);
    expect(names.containsCalls, 3);
  });
}
