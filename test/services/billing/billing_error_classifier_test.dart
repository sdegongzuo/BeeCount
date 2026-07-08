import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/services/billing/billing_error_classifier.dart';

void main() {
  group('BillingErrorClassifier', () {
    late BillingErrorClassifier classifier;

    setUp(() {
      classifier = BillingErrorClassifier();
    });

    test('connection abort is retryable', () {
      final error = SocketException('Connection reset by peer');
      final result = classifier.classify(error);
      expect(result.retryable, isTrue);
      expect(result.errorCode, 'network_unavailable');
    });

    test('timeout is retryable', () {
      final result = classifier.classify(TimeoutException('Request timed out'));
      expect(result.retryable, isTrue);
      expect(result.errorCode, 'timeout');
    });

    test('5xx server error is retryable', () {
      final result = classifier.classify(HttpException('500 Internal Server Error'));
      expect(result.retryable, isTrue);
      expect(result.errorCode, 'server_error');
    });

    test('429 rate limit is retryable', () {
      final result = classifier.classify(HttpException('429 Too Many Requests'));
      expect(result.retryable, isTrue);
      expect(result.errorCode, 'rate_limited');
    });

    test('network unavailable is retryable', () {
      final result = classifier.classify(SocketException('Network unreachable'));
      expect(result.retryable, isTrue);
      expect(result.errorCode, 'network_unavailable');
    });

    test('401 unauthorized is non-retryable', () {
      final result = classifier.classify(HttpException('401 Unauthorized'));
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'auth_error');
    });

    test('403 forbidden is non-retryable', () {
      final result = classifier.classify(HttpException('403 Forbidden'));
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'auth_error');
    });

    test('missing API key is non-retryable', () {
      final result = classifier.classify(Exception('api_key_missing'));
      expect(result.retryable, isFalse);
      expect(result.errorCode, '_Exception');
    });

    test('corrupted image file is non-retryable', () {
      final result = classifier.classify(FileSystemException('Corrupted file'));
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'FileSystemException');
    });

    test('OOM during OCR is non-retryable', () {
      final result = classifier.classify(OutOfMemoryError());
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'OutOfMemoryError');
    });

    test('disk full during DB write is non-retryable', () {
      final result = classifier.classify(
        FileSystemException('No space left on device'),
      );
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'FileSystemException');
    });

    test('default category not found allows continuation', () {
      final result = classifier.classify(
        StateError('Default category not found'),
      );
      expect(result.retryable, isFalse);
      expect(result.errorCode, 'StateError');
    });
  });
}
