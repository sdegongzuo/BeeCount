import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'billing_rule_network_policy.dart';

/// 使用一次已验证的 DNS 结果创建传输客户端的边界。
typedef BillingRulePinnedClientFactory = http.Client Function(
  Uri uri,
  List<InternetAddress> addresses,
);

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

/// 目标 host 或其任一解析地址不满足公网访问策略。
class BillingRuleNetworkPolicyException extends BillingRuleHttpException {
  const BillingRuleNetworkPolicyException(super.message);
}

/// 为 manifest 与 TOML 包提供超时、禁重定向和流式字节上限的下载器。
class BillingRuleSecureHttpLoader {
  final http.Client? _sharedClient;
  final http.Client Function()? _clientFactory;
  final BillingRuleAddressResolver addressResolver;
  final BillingRulePinnedClientFactory pinnedClientFactory;

  BillingRuleSecureHttpLoader({
    http.Client? client,
    http.Client Function()? clientFactory,
    BillingRuleAddressResolver? addressResolver,
    BillingRulePinnedClientFactory? pinnedClientFactory,
  })  : assert(client == null || clientFactory == null),
        assert(clientFactory == null || pinnedClientFactory == null),
        _sharedClient = client,
        _clientFactory = clientFactory,
        addressResolver = addressResolver ?? resolveBillingRuleHost,
        pinnedClientFactory = pinnedClientFactory ?? _createPinnedClient;

  /// 读取 UTF-8 文本；任何重定向都拒绝，由上层重新校验新 URI 后再显式请求。
  Future<String> load(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    http.Client? client;
    final ownsClient = _sharedClient == null;
    final abort = Completer<void>();
    final deadline = Completer<Never>();
    StreamSubscription<List<int>>? subscription;
    late final Timer timer;
    timer = Timer(timeout, () async {
      if (!abort.isCompleted) abort.complete();
      await subscription?.cancel();
      if (ownsClient) client?.close();
      if (!deadline.isCompleted) {
        deadline.completeError(
          TimeoutException('远程规则下载超过墙钟期限', timeout),
        );
      }
    });
    try {
      if (!isSafeBillingRuleHostSyntax(uri.host)) {
        throw BillingRuleNetworkPolicyException('远程规则 host 不安全：${uri.host}');
      }
      final literal = InternetAddress.tryParse(uri.host);
      final addresses = literal == null
          ? await Future.any<List<InternetAddress>>([
              addressResolver(uri.host),
              deadline.future,
            ])
          : [literal];
      if (addresses.isEmpty ||
          addresses.any((address) => !isPublicBillingRuleAddress(address))) {
        throw BillingRuleNetworkPolicyException(
          '远程规则 host 解析到非公网地址：${uri.host}',
        );
      }
      final pinnedAddresses = List<InternetAddress>.unmodifiable(addresses);
      client = _sharedClient ??
          _clientFactory?.call() ??
          pinnedClientFactory(uri, pinnedAddresses);
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abort.future,
      )..followRedirects = false;
      final response = await Future.any<http.StreamedResponse>([
        client.send(request),
        deadline.future,
      ]);
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
      final body = Completer<void>();
      subscription = response.stream.listen(
        (chunk) {
          if (bytes.length + chunk.length > maxBytes) {
            if (!body.isCompleted) {
              body.completeError(
                BillingRuleResponseTooLargeException(
                  '响应体超过上限 $maxBytes 字节',
                ),
              );
            }
            unawaited(subscription?.cancel());
            if (!abort.isCompleted) abort.complete();
            return;
          }
          bytes.addAll(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!body.isCompleted) body.completeError(error, stackTrace);
        },
        onDone: () {
          if (!body.isCompleted) body.complete();
        },
        cancelOnError: true,
      );
      await Future.any<void>([body.future, deadline.future]);
      return utf8.decode(bytes);
    } finally {
      timer.cancel();
      await subscription?.cancel();
      if (!abort.isCompleted) abort.complete();
      if (ownsClient) client?.close();
    }
  }
}

http.Client _createPinnedClient(
    Uri expectedUri, List<InternetAddress> addresses) {
  final ioClient = HttpClient();
  ioClient.findProxy = (_) => 'DIRECT';
  ioClient.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxyHost != null ||
        proxyPort != null ||
        uri.host.toLowerCase() != expectedUri.host.toLowerCase() ||
        _effectivePort(uri) != _effectivePort(expectedUri)) {
      throw BillingRuleNetworkPolicyException('连接目标偏离已验证的远程规则地址');
    }
    final rawTask = await Socket.startConnect(
      addresses.first,
      _effectivePort(uri),
    );
    Socket? rawSocket;
    final secureSocket = rawTask.socket.then<Socket>((socket) async {
      rawSocket = socket;
      return SecureSocket.secure(socket, host: uri.host);
    });
    return ConnectionTask.fromSocket(secureSocket, () {
      rawSocket?.destroy();
      rawTask.cancel();
    });
  };
  return IOClient(ioClient);
}

int _effectivePort(Uri uri) => uri.hasPort ? uri.port : 443;
