class BillingRuleManifestException implements Exception {
  final String message;

  const BillingRuleManifestException(this.message);

  @override
  String toString() => 'BillingRuleManifestException: $message';
}

class BillingRuleManifest {
  final BillingRuleManifestLatest latest;

  const BillingRuleManifest({required this.latest});

  factory BillingRuleManifest.fromJson(Map<String, dynamic> json) {
    final latest = json['latest'];
    if (latest is! Map) {
      throw const BillingRuleManifestException('latest must be an object');
    }
    return BillingRuleManifest(
      latest: BillingRuleManifestLatest.fromJson(
        latest.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }
}

class BillingRuleManifestLatest {
  static const supportedSchemaVersion = 1;

  final int schemaVersion;
  final String rulesVersion;
  final String minAppVersion;
  final Uri url;
  final String sha256;

  const BillingRuleManifestLatest({
    required this.schemaVersion,
    required this.rulesVersion,
    required this.minAppVersion,
    required this.url,
    required this.sha256,
  });

  factory BillingRuleManifestLatest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw BillingRuleManifestException(
        'Unsupported schemaVersion: $schemaVersion',
      );
    }

    final sha256 = _requiredString(json, 'sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const BillingRuleManifestException('sha256 must be 64 hex chars');
    }

    final url = Uri.tryParse(_requiredString(json, 'url'));
    if (url == null || !url.hasScheme) {
      throw const BillingRuleManifestException('url must be absolute');
    }

    return BillingRuleManifestLatest(
      schemaVersion: schemaVersion,
      rulesVersion: _requiredString(json, 'rulesVersion'),
      minAppVersion: _requiredString(json, 'minAppVersion'),
      url: url,
      sha256: sha256,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw BillingRuleManifestException('$key is required');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw BillingRuleManifestException('$key is required');
}
