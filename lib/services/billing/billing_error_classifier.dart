import 'dart:async';
import 'dart:io';

import '../ai/ai_provider_factory.dart';

class ErrorClassification {
  final bool retryable;
  final String errorCode;

  const ErrorClassification.retryable(this.errorCode) : retryable = true;
  const ErrorClassification.nonRetryable(this.errorCode) : retryable = false;
}

class BillingErrorClassifier {
  ErrorClassification classify(Object error) {
    if (error is SocketException) {
      return const ErrorClassification.retryable('network_unavailable');
    }
    if (error is TimeoutException) {
      return const ErrorClassification.retryable('timeout');
    }
    if (error is HttpException) {
      final code = _extractStatusCode(error.message);
      if (code == 429) return const ErrorClassification.retryable('rate_limited');
      if (code != null && code >= 500) return const ErrorClassification.retryable('server_error');
      if (code == 401 || code == 403) return const ErrorClassification.nonRetryable('auth_error');
    }
    if (error is AIException) {
      return _classifyMessage(error.message, fallback: 'AIException');
    }
    return ErrorClassification.nonRetryable(error.runtimeType.toString());
  }

  int? _extractStatusCode(String message) {
    final match = RegExp(r'\[?(\d{3})\]?').firstMatch(message);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  ErrorClassification _classifyMessage(String message, {required String fallback}) {
    final lower = message.toLowerCase();
    final code = _extractStatusCode(message);
    if (code == 401 || code == 403) {
      return const ErrorClassification.nonRetryable('auth_error');
    }
    if (code == 429) {
      return const ErrorClassification.retryable('rate_limited');
    }
    if (code != null && code >= 500) {
      return const ErrorClassification.retryable('server_error');
    }
    if (lower.contains('software caused connection abort') ||
        lower.contains('connection abort') ||
        lower.contains('connection reset') ||
        lower.contains('[null]') ||
        lower.contains('network is unreachable') ||
        lower.contains('network unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return const ErrorClassification.retryable('network_unavailable');
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return const ErrorClassification.retryable('timeout');
    }
    return ErrorClassification.nonRetryable(fallback);
  }
}
