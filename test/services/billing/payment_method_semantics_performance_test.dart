import 'package:beecount/services/billing/payment_method_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('500 payment method operations stay within the latency budget', () {
    const semantics = PaymentMethodSemantics();
    final inputs = List<String>.generate(
      500,
      (index) => '中国银行银联信用卡[${(1000 + index).toString()}]',
    );

    for (var index = 0; index < 5; index++) {
      for (final input in inputs) {
        semantics.canonicalize(input);
      }
    }

    final canonicalizeDurations = _measureRounds(
      () {
        for (final input in inputs) {
          semantics.canonicalize(input);
        }
      },
    );
    final canonical = inputs
        .map((input) => semantics.canonicalize(input).value!)
        .toList(growable: false);
    final formatDurations = _measureRounds(
      () {
        for (final value in canonical) {
          semantics.formatForHome(value);
        }
      },
    );

    final canonicalP95 = _percentile(canonicalizeDurations, 0.95);
    final formatP95 = _percentile(formatDurations, 0.95);
    // ignore: avoid_print
    print(
      'payment semantics 500-sample batches: '
      'canonical p50=${_percentile(canonicalizeDurations, 0.50)}ms '
      'p95=${canonicalP95}ms worst=${canonicalizeDurations.last}ms; '
      'home p50=${_percentile(formatDurations, 0.50)}ms '
      'p95=${formatP95}ms worst=${formatDurations.last}ms',
    );
    expect(canonicalP95, lessThanOrEqualTo(25));
    expect(formatP95, lessThanOrEqualTo(25));
  });
}

List<int> _measureRounds(void Function() operation) {
  final durations = <int>[];
  for (var index = 0; index < 30; index++) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    durations.add(stopwatch.elapsedMilliseconds);
  }
  durations.sort();
  return durations;
}

int _percentile(List<int> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}
