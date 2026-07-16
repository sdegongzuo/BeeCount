import 'package:package_info_plus/package_info_plus.dart';

/// 加载当前安装包版本的可替换边界。
typedef BillingRuleAppVersionLoader = Future<String> Function();

/// 远程公共规则更新的可信运行时配置。
///
/// 生产构建只从显式 dart-define 读取入口；缺失或不安全时保持禁用，而不是
/// 回退到占位域名。规则包默认必须与 manifest 同源，也可额外放行明确 host。
class BillingRuleUpdateConfiguration {
  static const manifestUrlDefine = 'BEECOUNT_BILLING_RULE_MANIFEST_URL';
  static const trustedHostsDefine = 'BEECOUNT_BILLING_RULE_TRUSTED_HOSTS';
  static const sameOriginDefine = 'BEECOUNT_BILLING_RULE_SAME_ORIGIN';

  final Uri? manifestUri;
  final SemanticVersion? currentAppVersion;
  final Set<String> trustedPackageHosts;
  final bool requireSameOrigin;
  final Duration requestTimeout;
  final int maxManifestBytes;
  final int maxRulePackageBytes;
  final Duration failureRetryInterval;
  final String? disabledReason;

  const BillingRuleUpdateConfiguration._({
    required this.manifestUri,
    required this.currentAppVersion,
    required this.trustedPackageHosts,
    required this.requireSameOrigin,
    required this.requestTimeout,
    required this.maxManifestBytes,
    required this.maxRulePackageBytes,
    required this.failureRetryInterval,
    required this.disabledReason,
  });

  /// 当前配置是否足以安全启动网络更新。
  bool get isEnabled => disabledReason == null;

  /// 用显式值构造配置；测试、flavor 装配也应经过同一安全校验。
  factory BillingRuleUpdateConfiguration.fromValues({
    required String manifestUrl,
    required String currentAppVersion,
    Set<String> trustedPackageHosts = const {},
    bool requireSameOrigin = true,
    Duration requestTimeout = const Duration(seconds: 15),
    int maxManifestBytes = 64 * 1024,
    int maxRulePackageBytes = 2 * 1024 * 1024,
    Duration failureRetryInterval = const Duration(minutes: 15),
  }) {
    final trimmedUrl = manifestUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    final version = SemanticVersion.tryParse(currentAppVersion.trim());
    final normalizedHosts = trustedPackageHosts
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet();

    String? reason;
    if (trimmedUrl.isEmpty) {
      reason = '未配置远程规则 manifest URL（$manifestUrlDefine）';
    } else if (!_isTrustedHttpsUri(uri)) {
      reason = '远程规则 manifest URL 必须是非占位域名的 HTTPS 绝对地址';
    } else if (version == null) {
      reason = '当前 App 版本不是有效的语义版本：$currentAppVersion';
    } else if (!requireSameOrigin && normalizedHosts.isEmpty) {
      reason = '关闭同源限制时必须显式配置可信规则包 host';
    } else if (requestTimeout <= Duration.zero ||
        maxManifestBytes <= 0 ||
        maxRulePackageBytes <= 0 ||
        failureRetryInterval < Duration.zero) {
      reason = '远程规则网络边界配置无效';
    }

    return BillingRuleUpdateConfiguration._(
      manifestUri: uri,
      currentAppVersion: version,
      trustedPackageHosts: Set.unmodifiable(normalizedHosts),
      requireSameOrigin: requireSameOrigin,
      requestTimeout: requestTimeout,
      maxManifestBytes: maxManifestBytes,
      maxRulePackageBytes: maxRulePackageBytes,
      failureRetryInterval: failureRetryInterval,
      disabledReason: reason,
    );
  }

  /// 从生产编译参数和安装包元数据构造配置。
  ///
  /// `BEECOUNT_BILLING_RULE_TRUSTED_HOSTS` 使用逗号分隔 host，不接受完整 URL。
  static Future<BillingRuleUpdateConfiguration> loadProduction({
    BillingRuleAppVersionLoader? appVersionLoader,
  }) async {
    const manifestUrl = String.fromEnvironment(manifestUrlDefine);
    const trustedHosts = String.fromEnvironment(trustedHostsDefine);
    const requireSameOrigin =
        bool.fromEnvironment(sameOriginDefine, defaultValue: true);
    final version = await (appVersionLoader ?? _installedAppVersion).call();
    return BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: manifestUrl,
      currentAppVersion: version,
      trustedPackageHosts: trustedHosts.split(',').toSet(),
      requireSameOrigin: requireSameOrigin,
    );
  }

  /// 判断规则包 URL 是否满足 HTTPS 与同源/可信 host 策略。
  bool allowsRulePackage(Uri uri) {
    if (!_isTrustedHttpsUri(uri)) return false;
    final manifest = manifestUri;
    if (manifest == null) return false;
    final sameOrigin = uri.scheme == manifest.scheme &&
        uri.host.toLowerCase() == manifest.host.toLowerCase() &&
        _effectivePort(uri) == _effectivePort(manifest);
    if (requireSameOrigin && sameOrigin) return true;
    return trustedPackageHosts.contains(uri.host.toLowerCase());
  }
}

Future<String> _installedAppVersion() async =>
    (await PackageInfo.fromPlatform()).version;

bool _isTrustedHttpsUri(Uri? uri) {
  if (uri == null ||
      !uri.isAbsolute ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host != 'example.com' &&
      !host.endsWith('.example.com') &&
      !host.endsWith('.example') &&
      !host.endsWith('.invalid');
}

int _effectivePort(Uri uri) => uri.hasPort ? uri.port : 443;

/// 严格的 SemVer 2.0.0 值对象；build metadata 不参与优先级。
class SemanticVersion implements Comparable<SemanticVersion> {
  static final _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  const SemanticVersion._(
    this.major,
    this.minor,
    this.patch,
    this.prerelease,
  );

  factory SemanticVersion.parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('无效的语义版本：$value');
    }
    return parsed;
  }

  static SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final prerelease = match.group(4)?.split('.') ?? const <String>[];
    if (prerelease.any((id) =>
        id.isEmpty ||
        (RegExp(r'^\d+$').hasMatch(id) && id.length > 1 && id[0] == '0'))) {
      return null;
    }
    return SemanticVersion._(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      List.unmodifiable(prerelease),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    for (final pair in <(int, int)>[
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final compared = pair.$1.compareTo(pair.$2);
      if (compared != 0) return compared;
    }
    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;
    final count = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < count; index++) {
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      int compared;
      if (leftNumber != null && rightNumber != null) {
        compared = leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        compared = -1;
      } else if (rightNumber != null) {
        compared = 1;
      } else {
        compared = left.compareTo(right);
      }
      if (compared != 0) return compared;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease.join('.'));
}
