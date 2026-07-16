import 'dart:io';

/// 可替换的 DNS 解析边界；生产实现使用系统解析器。
typedef BillingRuleAddressResolver = Future<List<InternetAddress>> Function(
  String host,
);

/// 解析远程规则 host，供下载器在连接前完成地址策略检查。
Future<List<InternetAddress>> resolveBillingRuleHost(String host) =>
    InternetAddress.lookup(host);

/// URL host 是否是规范公网 IP，或不会被解释为非标准 IP 的普通 DNS 名称。
bool isSafeBillingRuleHostSyntax(String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.') ||
      normalized.contains('%')) {
    return false;
  }

  final address = InternetAddress.tryParse(normalized);
  if (address != null) return isPublicBillingRuleAddress(address);

  // 拒绝整数、十六进制、八进制、缩写 IPv4 等平台可能以 IP 解释的写法。
  if (RegExp(r'^[0-9a-fx.:]+$', caseSensitive: false).hasMatch(normalized)) {
    return false;
  }
  if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(normalized)) return false;
  final labels = normalized.split('.');
  return labels.length >= 2 &&
      labels.every(
        (label) =>
            label.isNotEmpty &&
            label.length <= 63 &&
            !label.startsWith('-') &&
            !label.endsWith('-'),
      );
}

/// 地址是否属于可直接访问的公网单播范围。
bool isPublicBillingRuleAddress(InternetAddress address) {
  final bytes = address.rawAddress;
  if (bytes.length == 4) return _isPublicIpv4(bytes);
  if (bytes.length != 16) return false;

  if (_isIpv4Mapped(bytes)) return _isPublicIpv4(bytes.sublist(12));

  // 公网 IPv6 单播首先必须属于 2000::/3。
  if ((bytes[0] & 0xe0) != 0x20) return false;
  // IETF special-purpose block、benchmark 与 documentation。
  if (bytes[0] == 0x20 &&
      bytes[1] == 0x01 &&
      (bytes[2] < 0x02 ||
          (bytes[2] == 0x00 && bytes[3] == 0x02) ||
          (bytes[2] == 0x0d && bytes[3] == 0xb8))) {
    return false;
  }
  // 6to4 可把非公网 IPv4 藏在 IPv6 literal 中，统一禁止。
  if (bytes[0] == 0x20 && bytes[1] == 0x02) return false;
  // 3fff::/20 documentation。
  if (bytes[0] == 0x3f && bytes[1] == 0xff && (bytes[2] & 0xf0) == 0) {
    return false;
  }
  return true;
}

bool _isPublicIpv4(List<int> bytes) {
  final a = bytes[0];
  final b = bytes[1];
  final c = bytes[2];
  if (a == 0 || a == 10 || a == 127 || a >= 224) return false;
  if (a == 100 && b >= 64 && b <= 127) return false;
  if (a == 169 && b == 254) return false;
  if (a == 172 && b >= 16 && b <= 31) return false;
  if (a == 192 && b == 168) return false;
  if (a == 192 && b == 0 && c == 0) return false;
  if (a == 192 && b == 0 && c == 2) return false;
  if (a == 192 && b == 88 && c == 99) return false;
  if (a == 198 && (b == 18 || b == 19)) return false;
  if (a == 198 && b == 51 && c == 100) return false;
  if (a == 203 && b == 0 && c == 113) return false;
  return true;
}

bool _isIpv4Mapped(List<int> bytes) {
  for (var index = 0; index < 10; index++) {
    if (bytes[index] != 0) return false;
  }
  return bytes[10] == 0xff && bytes[11] == 0xff;
}
