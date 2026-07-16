import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 远程规则 HTTP 读取失败。
class BillingRuleHttpException implements Exception {
  final String message;

  const BillingRuleHttpException(this.message);

  @override
  String toString() => 'BillingRuleHttpException: $message';
}

/// 响应体超过可信配置上限。
class BillingRuleResponseTooLargeException extends BillingRuleHttpException {
  const BillingRuleResponseTooLargeException(super.message);
}

/// 服务端试图把请求重定向到未经重新授权的 URI。
class BillingRuleRedirectRejectedException extends BillingRuleHttpException {
  const BillingRuleRedirectRejectedException(super.message);
}

/// 为 manifest 与 TOML 包提供超时、禁重定向和流式字节上限的下载器。
class BillingRuleSecureHttpLoader {
  final http.Client Function() clientFactory;

  BillingRuleSecureHttpLoader({http.Client Function()? clientFactory})
      : clientFactory = clientFactory ?? http.Client.new;

  /// 读取 UTF-8 文本；任何重定向都拒绝，由上层重新校验新 URI 后再显式请求。
  Future<String> load(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    final client = clientFactory();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client.send(request).timeout(timeout);
      final finalUri = response.request?.url;
      if (finalUri != null && finalUri != uri) {
        throw BillingRuleRedirectRejectedException(
          '响应最终 URI 与请求 URI 不一致：$finalUri',
        );
      }
      if (response.isRedirect ||
          (response.statusCode >= 300 && response.statusCode < 400)) {
        throw const BillingRuleRedirectRejectedException('远程规则下载不允许 HTTP 重定向');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BillingRuleHttpException('HTTP ${response.statusCode}: $uri');
      }
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        throw BillingRuleResponseTooLargeException(
          '响应声明 $contentLength 字节，超过上限 $maxBytes',
        );
      }
      final bytes = <int>[];
      await response.stream.forEach((chunk) {
        if (bytes.length + chunk.length > maxBytes) {
          throw BillingRuleResponseTooLargeException(
            '响应体超过上限 $maxBytes 字节',
          );
        }
        bytes.addAll(chunk);
      }).timeout(timeout);
      return utf8.decode(bytes);
    } finally {
      client.close();
    }
  }
}
