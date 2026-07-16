import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'billing_rule_manifest.dart';
import 'billing_rule_models.dart';
import 'billing_rule_repository.dart';
import 'billing_rule_storage.dart';

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
  static const activeFileName = BillingRuleStorage.activeFileName;
  static const previousFileName = BillingRuleStorage.previousFileName;
  static const lastCheckFileName = BillingRuleStorage.lastCheckFileName;
  static const defaultManifestUrl =
      'https://example.com/beecount/billing_rules_manifest.json';

  final Directory? storageDirectory;

  /// 与生产读取链共享的规则文件布局；测试可注入隔离目录。
  final BillingRuleStorage? ruleStorage;
  final Uri manifestUri;
  final BillingRuleManifestLoader manifestLoader;
  final BillingRulePackageDownloader rulePackageDownloader;
  final BillingRuleSmokeTest smokeTest;
  final BillingRuleUpgradeEvaluation upgradeEvaluation;
  final BillingRulePersonalRegression personalRegression;
  final BillingRulePersonalRuleArchiver personalRuleArchiver;
  final void Function()? beforeAtomicSwitch;

  /// 活动文件完成原子切换或恢复后使运行时内存快照失效。
  final void Function() onActiveSnapshotChanged;
  final BillingRuleUpdateClock clock;

  BillingRuleUpdateService({
    this.storageDirectory,
    this.ruleStorage,
    Uri? manifestUri,
    BillingRuleManifestLoader? manifestLoader,
    BillingRulePackageDownloader? rulePackageDownloader,
    BillingRuleSmokeTest? smokeTest,
    required this.upgradeEvaluation,
    required this.personalRegression,
    required this.personalRuleArchiver,
    this.beforeAtomicSwitch,
    void Function()? onActiveSnapshotChanged,
    BillingRuleUpdateClock? clock,
  })  : manifestUri = manifestUri ?? Uri.parse(defaultManifestUrl),
        manifestLoader = manifestLoader ?? _httpGetString,
        rulePackageDownloader = rulePackageDownloader ?? _httpGetString,
        smokeTest = smokeTest ?? _defaultSmokeTest,
        onActiveSnapshotChanged =
            onActiveSnapshotChanged ?? invalidateProductionBillingRuleSnapshot,
        clock = clock ?? DateTime.now,
        assert(ruleStorage == null || storageDirectory == null);

  Future<BillingRuleUpdateResult> checkForUpdateIfDue({
    Duration minInterval = const Duration(days: 1),
  }) async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      await storage.directory.create(recursive: true);
      final lastCheckFile = storage.lastCheckFile;
      final now = clock().toUtc();

      final lastCheck = await _readLastCheck(lastCheckFile);
      if (lastCheck != null && now.difference(lastCheck) < minInterval) {
        return const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
          message:
              'Update check skipped because the daily interval has not elapsed.',
        );
      }

      final result = await _checkForUpdate(storage);
      await lastCheckFile.writeAsString(
        jsonEncode({'checkedAt': now.toIso8601String()}),
      );
      return result;
    });
  }

  Future<BillingRuleUpdateResult> checkForUpdate() async {
    final storage = await _storage();
    return storage.runExclusive(() => _checkForUpdate(storage));
  }

  Future<BillingRuleUpdateResult> _checkForUpdate(
      BillingRuleStorage storage) async {
    await storage.directory.create(recursive: true);
    final activeFile = storage.activeFile;
    final previousFile = storage.previousFile;

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

      final candidateFile = storage.pendingFile;
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
        final previousPending = storage.previousPendingFile;
        await previousPending.writeAsString(await activeFile.readAsString(),
            flush: true);
        await previousPending.rename(previousFile.path);
      }
      beforeAtomicSwitch?.call();
      await candidateFile.rename(activeFile.path);
      onActiveSnapshotChanged();
      String? activationMessage = regression.conflictExplanation;
      if (regression.equivalentPersonalRuleIds.isNotEmpty) {
        try {
          await personalRuleArchiver.call(regression.equivalentPersonalRuleIds);
        } catch (e) {
          final restoredPrevious = await previousFile.exists();
          if (restoredPrevious) {
            await _restorePrevious(storage);
          } else if (await activeFile.exists()) {
            await activeFile.rename(storage.pendingFile.path);
          }
          onActiveSnapshotChanged();
          return BillingRuleUpdateResult(
            status: BillingRuleUpdateStatus.failed,
            rulesVersion: candidateRuleSet.rulesVersion,
            message: restoredPrevious
                ? 'Equivalent personal rule archival failed; old public snapshot restored: $e'
                : 'Equivalent personal rule archival failed; built-in snapshot restored: $e',
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

  Future<void> _restorePrevious(BillingRuleStorage storage) async {
    final pending = storage.activeRecoveryPendingFile;
    await pending.writeAsString(await storage.previousFile.readAsString(),
        flush: true);
    await pending.rename(storage.activeFile.path);
  }

  Future<BillingRuleUpdateResult> rollback() async {
    final storage = await _storage();
    return storage.runExclusive(() => _rollback(storage));
  }

  Future<BillingRuleUpdateResult> _rollback(BillingRuleStorage storage) async {
    final activeFile = storage.activeFile;
    final previousFile = storage.previousFile;
    if (!await previousFile.exists()) {
      return const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.rollbackUnavailable,
      );
    }

    final previousText = await previousFile.readAsString();
    final activeText =
        await activeFile.exists() ? await activeFile.readAsString() : null;
    final rollbackPending = storage.activeRollbackPendingFile;
    await rollbackPending.writeAsString(previousText, flush: true);
    await rollbackPending.rename(activeFile.path);
    if (activeText != null) {
      final previousPending = storage.previousRollbackPendingFile;
      await previousPending.writeAsString(activeText, flush: true);
      await previousPending.rename(previousFile.path);
    }

    final activeRuleSet = await _tryLoadRuleSet(activeFile);
    onActiveSnapshotChanged();
    return BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.rolledBack,
      rulesVersion: activeRuleSet?.rulesVersion,
    );
  }

  Future<BillingRuleStorage> _storage() async {
    final injectedStorage = ruleStorage;
    if (injectedStorage != null) return injectedStorage;
    final injectedDirectory = storageDirectory;
    if (injectedDirectory != null) {
      return BillingRuleStorage(injectedDirectory);
    }
    return productionBillingRuleStorage();
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
