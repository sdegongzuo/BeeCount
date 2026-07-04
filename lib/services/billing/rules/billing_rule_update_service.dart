import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'billing_rule_manifest.dart';
import 'billing_rule_models.dart';
import 'billing_rule_repository.dart';

typedef BillingRuleManifestLoader = Future<String> Function(Uri uri);
typedef BillingRulePackageDownloader = Future<String> Function(Uri uri);
typedef BillingRuleSmokeTest = Future<bool> Function(BillingRuleSet ruleSet);
typedef BillingRuleUpdateClock = DateTime Function();

enum BillingRuleUpdateStatus {
  activated,
  alreadyLatest,
  notDue,
  hashMismatch,
  invalidManifest,
  invalidRulePackage,
  smokeTestFailed,
  rolledBack,
  rollbackUnavailable,
  failed,
}

class BillingRuleUpdateResult {
  final BillingRuleUpdateStatus status;
  final String? rulesVersion;
  final String? message;

  const BillingRuleUpdateResult({
    required this.status,
    this.rulesVersion,
    this.message,
  });
}

class BillingRuleUpdateService {
  static const activeFileName = 'billing_rules.active.toml';
  static const previousFileName = 'billing_rules.previous.toml';
  static const lastCheckFileName = 'billing_rules.last_check.json';
  static const defaultManifestUrl =
      'https://example.com/beecount/billing_rules_manifest.json';

  final Directory? storageDirectory;
  final Uri manifestUri;
  final BillingRuleManifestLoader manifestLoader;
  final BillingRulePackageDownloader rulePackageDownloader;
  final BillingRuleSmokeTest smokeTest;
  final BillingRuleUpdateClock clock;

  BillingRuleUpdateService({
    this.storageDirectory,
    Uri? manifestUri,
    BillingRuleManifestLoader? manifestLoader,
    BillingRulePackageDownloader? rulePackageDownloader,
    BillingRuleSmokeTest? smokeTest,
    BillingRuleUpdateClock? clock,
  })  : manifestUri = manifestUri ?? Uri.parse(defaultManifestUrl),
        manifestLoader = manifestLoader ?? _httpGetString,
        rulePackageDownloader = rulePackageDownloader ?? _httpGetString,
        smokeTest = smokeTest ?? _defaultSmokeTest,
        clock = clock ?? DateTime.now;

  Future<BillingRuleUpdateResult> checkForUpdateIfDue({
    Duration minInterval = const Duration(days: 1),
  }) async {
    final directory = await _storageDirectory();
    await directory.create(recursive: true);
    final lastCheckFile = File('${directory.path}/$lastCheckFileName');
    final now = clock().toUtc();

    final lastCheck = await _readLastCheck(lastCheckFile);
    if (lastCheck != null && now.difference(lastCheck) < minInterval) {
      return const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.notDue,
        message:
            'Update check skipped because the daily interval has not elapsed.',
      );
    }

    final result = await checkForUpdate();
    await lastCheckFile.writeAsString(
      jsonEncode({'checkedAt': now.toIso8601String()}),
    );
    return result;
  }

  Future<BillingRuleUpdateResult> checkForUpdate() async {
    final directory = await _storageDirectory();
    await directory.create(recursive: true);
    final activeFile = File('${directory.path}/$activeFileName');
    final previousFile = File('${directory.path}/$previousFileName');

    BillingRuleManifest manifest;
    try {
      manifest = BillingRuleManifest.fromJson(
        jsonDecode(await manifestLoader(manifestUri)) as Map<String, dynamic>,
      );
    } on BillingRuleManifestException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.invalidManifest,
        message: e.toString(),
      );
    } catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        message: e.toString(),
      );
    }

    if (await activeFile.exists()) {
      final activeRuleSet = await _tryLoadRuleSet(activeFile);
      if (activeRuleSet?.rulesVersion == manifest.latest.rulesVersion) {
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.alreadyLatest,
          rulesVersion: activeRuleSet?.rulesVersion,
        );
      }
    }

    final remoteToml = await rulePackageDownloader(manifest.latest.url);
    final remoteHash = sha256.convert(utf8.encode(remoteToml)).toString();
    if (remoteHash.toLowerCase() != manifest.latest.sha256.toLowerCase()) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.hashMismatch,
        rulesVersion: manifest.latest.rulesVersion,
        message: 'Expected ${manifest.latest.sha256}, got $remoteHash',
      );
    }

    final candidateFile =
        File('${directory.path}/billing_rules.candidate.toml');
    await candidateFile.writeAsString(remoteToml);
    final candidateRuleSet = await _tryLoadRuleSet(candidateFile);
    if (candidateRuleSet == null) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.invalidRulePackage,
        rulesVersion: manifest.latest.rulesVersion,
      );
    }

    if (!await smokeTest(candidateRuleSet)) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.smokeTestFailed,
        rulesVersion: candidateRuleSet.rulesVersion,
      );
    }

    if (await activeFile.exists()) {
      await previousFile.writeAsString(await activeFile.readAsString());
    }
    await activeFile.writeAsString(remoteToml);

    return BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.activated,
      rulesVersion: candidateRuleSet.rulesVersion,
    );
  }

  Future<BillingRuleUpdateResult> rollback() async {
    final directory = await _storageDirectory();
    final activeFile = File('${directory.path}/$activeFileName');
    final previousFile = File('${directory.path}/$previousFileName');
    if (!await previousFile.exists()) {
      return const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.rollbackUnavailable,
      );
    }

    final previousText = await previousFile.readAsString();
    final activeText =
        await activeFile.exists() ? await activeFile.readAsString() : null;
    await activeFile.writeAsString(previousText);
    if (activeText != null) {
      await previousFile.writeAsString(activeText);
    }

    final activeRuleSet = await _tryLoadRuleSet(activeFile);
    return BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.rolledBack,
      rulesVersion: activeRuleSet?.rulesVersion,
    );
  }

  Future<Directory> _storageDirectory() async {
    final injected = storageDirectory;
    if (injected != null) return injected;
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/rules');
  }

  Future<DateTime?> _readLastCheck(File file) async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      final checkedAt = json['checkedAt'];
      if (checkedAt is! String) return null;
      return DateTime.tryParse(checkedAt)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<BillingRuleSet?> _tryLoadRuleSet(File file) async {
    try {
      final repository = TomlBillingRuleRepository(activeRuleFile: file);
      final ruleSet = await repository.loadActiveRuleSet();
      if (ruleSet.source != file.path) return null;
      return ruleSet;
    } catch (_) {
      return null;
    }
  }
}

Future<String> _httpGetString(Uri uri) async {
  final response = await http.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('HTTP ${response.statusCode}: $uri');
  }
  return response.body;
}

Future<bool> _defaultSmokeTest(BillingRuleSet ruleSet) async {
  return ruleSet.templates.isNotEmpty;
}
