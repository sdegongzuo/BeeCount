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
typedef BillingRuleUpgradeEvaluation = Future<bool> Function(
    BillingRuleSet ruleSet);
typedef BillingRulePersonalRegression
    = Future<BillingRulePersonalRegressionResult> Function(
        BillingRuleSet ruleSet);
typedef BillingRulePersonalRuleArchiver = Future<void> Function(
    List<String> ruleIds);
typedef BillingRuleUpdateClock = DateTime Function();

class BillingRulePersonalRegressionResult {
  final bool isPassed;
  final List<String> equivalentPersonalRuleIds;
  final String? explanation;
  final String? conflictExplanation;

  const BillingRulePersonalRegressionResult.passed({
    this.equivalentPersonalRuleIds = const [],
    this.conflictExplanation,
  })  : isPassed = true,
        explanation = null;

  const BillingRulePersonalRegressionResult.rejected({
    required this.explanation,
  })  : isPassed = false,
        equivalentPersonalRuleIds = const [],
        conflictExplanation = null;
}

enum BillingRuleUpdateStatus {
  activated,
  alreadyLatest,
  notDue,
  hashMismatch,
  invalidManifest,
  invalidRulePackage,
  smokeTestFailed,
  goldenEvaluationFailed,
  personalRegressionFailed,
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
  final BillingRuleUpgradeEvaluation upgradeEvaluation;
  final BillingRulePersonalRegression personalRegression;
  final BillingRulePersonalRuleArchiver personalRuleArchiver;
  final void Function()? beforeAtomicSwitch;
  final BillingRuleUpdateClock clock;

  BillingRuleUpdateService({
    this.storageDirectory,
    Uri? manifestUri,
    BillingRuleManifestLoader? manifestLoader,
    BillingRulePackageDownloader? rulePackageDownloader,
    BillingRuleSmokeTest? smokeTest,
    required this.upgradeEvaluation,
    required this.personalRegression,
    required this.personalRuleArchiver,
    this.beforeAtomicSwitch,
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

    try {
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
      if (candidateRuleSet == null ||
          candidateRuleSet.schemaVersion != manifest.latest.schemaVersion ||
          candidateRuleSet.rulesVersion != manifest.latest.rulesVersion) {
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

      if (!await upgradeEvaluation(candidateRuleSet)) {
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.goldenEvaluationFailed,
          rulesVersion: candidateRuleSet.rulesVersion,
        );
      }
      final regression = await personalRegression(candidateRuleSet);
      if (!regression.isPassed) {
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.personalRegressionFailed,
          rulesVersion: candidateRuleSet.rulesVersion,
          message: regression.explanation,
        );
      }

      if (await activeFile.exists()) {
        final previousPending = File('${previousFile.path}.pending');
        await previousPending.writeAsString(await activeFile.readAsString(),
            flush: true);
        await previousPending.rename(previousFile.path);
      }
      beforeAtomicSwitch?.call();
      await candidateFile.rename(activeFile.path);
      String? activationMessage = regression.conflictExplanation;
      if (regression.equivalentPersonalRuleIds.isNotEmpty) {
        try {
          await personalRuleArchiver.call(regression.equivalentPersonalRuleIds);
        } catch (e) {
          if (await previousFile.exists()) {
            await _restorePrevious(activeFile, previousFile);
          }
          return BillingRuleUpdateResult(
            status: BillingRuleUpdateStatus.failed,
            rulesVersion: candidateRuleSet.rulesVersion,
            message:
                'Equivalent personal rule archival failed; old public snapshot restored: $e',
          );
        }
      }

      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.activated,
        rulesVersion: candidateRuleSet.rulesVersion,
        message: activationMessage,
      );
    } catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        rulesVersion: manifest.latest.rulesVersion,
        message: e.toString(),
      );
    }
  }

  Future<void> _restorePrevious(File activeFile, File previousFile) async {
    final pending = File('${activeFile.path}.recovery.pending');
    await pending.writeAsString(await previousFile.readAsString(), flush: true);
    await pending.rename(activeFile.path);
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
    final rollbackPending = File('${activeFile.path}.rollback.pending');
    await rollbackPending.writeAsString(previousText, flush: true);
    await rollbackPending.rename(activeFile.path);
    if (activeText != null) {
      final previousPending = File('${previousFile.path}.rollback.pending');
      await previousPending.writeAsString(activeText, flush: true);
      await previousPending.rename(previousFile.path);
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
