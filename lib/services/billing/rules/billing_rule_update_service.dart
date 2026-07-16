import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'billing_rule_manifest.dart';
import 'billing_rule_models.dart';
import 'billing_rule_repository.dart';
import 'billing_rule_secure_http_loader.dart';
import 'billing_rule_storage.dart';
import 'billing_rule_update_configuration.dart';

export 'billing_rule_secure_http_loader.dart';

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
  disabled,
  activated,
  alreadyLatest,
  notDue,
  securityPolicyRejected,
  incompatibleAppVersion,
  responseTooLarge,
  timedOut,
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

  final Directory? storageDirectory;

  /// 与生产读取链共享的规则文件布局；测试可注入隔离目录。
  final BillingRuleStorage? ruleStorage;
  final BillingRuleUpdateConfiguration configuration;
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
    required this.configuration,
    BillingRuleManifestLoader? manifestLoader,
    BillingRulePackageDownloader? rulePackageDownloader,
    BillingRuleSmokeTest? smokeTest,
    required this.upgradeEvaluation,
    required this.personalRegression,
    required this.personalRuleArchiver,
    this.beforeAtomicSwitch,
    void Function()? onActiveSnapshotChanged,
    BillingRuleUpdateClock? clock,
  })  : manifestLoader = manifestLoader ??
            ((uri) => BillingRuleSecureHttpLoader().load(
                  uri,
                  timeout: configuration.requestTimeout,
                  maxBytes: configuration.maxManifestBytes,
                )),
        rulePackageDownloader = rulePackageDownloader ??
            ((uri) => BillingRuleSecureHttpLoader().load(
                  uri,
                  timeout: configuration.requestTimeout,
                  maxBytes: configuration.maxRulePackageBytes,
                )),
        smokeTest = smokeTest ?? _defaultSmokeTest,
        onActiveSnapshotChanged =
            onActiveSnapshotChanged ?? invalidateProductionBillingRuleSnapshot,
        clock = clock ?? DateTime.now,
        assert(ruleStorage == null || storageDirectory == null);

  /// 当前显式配置的 manifest URI；禁用时可能为空或不可信，仅用于诊断。
  Uri? get manifestUri => configuration.manifestUri;

  Future<BillingRuleUpdateResult> checkForUpdateIfDue({
    Duration minInterval = const Duration(days: 1),
  }) async {
    final disabled = _disabledResult();
    if (disabled != null) return disabled;
    final storage = await _storage();
    return storage.runExclusive(() async {
      await storage.directory.create(recursive: true);
      final lastCheckFile = storage.lastCheckFile;
      final now = clock().toUtc();

      final state = await _readCheckState(lastCheckFile);
      if (state.lastSuccessAt != null &&
          now.difference(state.lastSuccessAt!) < minInterval) {
        return const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
          message:
              'Update check skipped because the daily interval has not elapsed.',
        );
      }
      final lastAttempt = state.lastAttemptAt;
      final lastAttemptFailed = lastAttempt != null &&
          (state.lastSuccessAt == null ||
              lastAttempt.isAfter(state.lastSuccessAt!));
      if (lastAttemptFailed &&
          now.difference(lastAttempt) < configuration.failureRetryInterval) {
        return const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
          message: '上次更新失败，尚未到短退避重试时间。',
        );
      }

      final result = await _checkForUpdate(storage);
      final isSuccess = result.status == BillingRuleUpdateStatus.activated ||
          result.status == BillingRuleUpdateStatus.alreadyLatest;
      await lastCheckFile.writeAsString(
        jsonEncode({
          'lastAttemptAt': now.toIso8601String(),
          if (isSuccess)
            'lastSuccessAt': now.toIso8601String()
          else if (state.lastSuccessAt != null)
            'lastSuccessAt': state.lastSuccessAt!.toIso8601String(),
        }),
        flush: true,
      );
      return result;
    });
  }

  Future<BillingRuleUpdateResult> checkForUpdate() async {
    final disabled = _disabledResult();
    if (disabled != null) return disabled;
    final storage = await _storage();
    return storage.runExclusive(() => _checkForUpdate(storage));
  }

  Future<BillingRuleUpdateResult> _checkForUpdate(
      BillingRuleStorage storage) async {
    await storage.directory.create(recursive: true);
    final activeFile = storage.activeFile;
    final previousFile = storage.previousFile;

    final manifestUri = configuration.manifestUri!;
    BillingRuleManifest manifest;
    try {
      final manifestText = await manifestLoader(manifestUri)
          .timeout(configuration.requestTimeout);
      _enforceTextLimit(manifestText, configuration.maxManifestBytes);
      manifest = BillingRuleManifest.fromJson(
        jsonDecode(manifestText) as Map<String, dynamic>,
      );
    } on BillingRuleResponseTooLargeException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.responseTooLarge,
        message: e.toString(),
      );
    } on TimeoutException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.timedOut,
        message: e.toString(),
      );
    } on BillingRuleRedirectRejectedException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.securityPolicyRejected,
        message: e.toString(),
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

    if (!configuration.allowsRulePackage(manifest.latest.url)) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.securityPolicyRejected,
        rulesVersion: manifest.latest.rulesVersion,
        message: '规则包 URL 不满足 HTTPS 与同源/可信 host 策略：${manifest.latest.url}',
      );
    }
    final minimumVersion =
        SemanticVersion.tryParse(manifest.latest.minAppVersion);
    if (minimumVersion == null) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.invalidManifest,
        rulesVersion: manifest.latest.rulesVersion,
        message: 'minAppVersion 不是有效的语义版本：${manifest.latest.minAppVersion}',
      );
    }
    if (configuration.currentAppVersion! < minimumVersion) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.incompatibleAppVersion,
        rulesVersion: manifest.latest.rulesVersion,
        message: '当前 App 版本低于规则包最低版本 ${manifest.latest.minAppVersion}',
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
      final remoteToml = await rulePackageDownloader(manifest.latest.url)
          .timeout(configuration.requestTimeout);
      _enforceTextLimit(remoteToml, configuration.maxRulePackageBytes);
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
    } on BillingRuleResponseTooLargeException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.responseTooLarge,
        rulesVersion: manifest.latest.rulesVersion,
        message: e.toString(),
      );
    } on TimeoutException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.timedOut,
        rulesVersion: manifest.latest.rulesVersion,
        message: e.toString(),
      );
    } on BillingRuleRedirectRejectedException catch (e) {
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.securityPolicyRejected,
        rulesVersion: manifest.latest.rulesVersion,
        message: e.toString(),
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

  Future<_BillingRuleCheckState> _readCheckState(File file) async {
    try {
      if (!await file.exists()) return const _BillingRuleCheckState();
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return const _BillingRuleCheckState();
      DateTime? parse(String key) {
        final value = json[key];
        return value is String ? DateTime.tryParse(value)?.toUtc() : null;
      }

      // 兼容旧版本：旧 checkedAt 只代表一次尝试，不能再视为成功而压住 24h。
      return _BillingRuleCheckState(
        lastAttemptAt: parse('lastAttemptAt') ?? parse('checkedAt'),
        lastSuccessAt: parse('lastSuccessAt'),
      );
    } catch (_) {
      return const _BillingRuleCheckState();
    }
  }

  BillingRuleUpdateResult? _disabledResult() {
    if (configuration.isEnabled) return null;
    return BillingRuleUpdateResult(
      status: BillingRuleUpdateStatus.disabled,
      message: configuration.disabledReason,
    );
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

class _BillingRuleCheckState {
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;

  const _BillingRuleCheckState({this.lastAttemptAt, this.lastSuccessAt});
}

void _enforceTextLimit(String value, int maxBytes) {
  final length = utf8.encode(value).length;
  if (length > maxBytes) {
    throw BillingRuleResponseTooLargeException(
      '响应体 $length 字节，超过上限 $maxBytes',
    );
  }
}

Future<bool> _defaultSmokeTest(BillingRuleSet ruleSet) async {
  return ruleSet.templates.isNotEmpty;
}
