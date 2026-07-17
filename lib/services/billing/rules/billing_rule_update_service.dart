import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'billing_rule_activation_journal.dart';
import 'billing_rule_durability.dart';
import 'billing_rule_manifest.dart';
import 'billing_rule_models.dart';
import 'billing_rule_repository.dart';
import 'billing_rule_runtime_evaluator.dart';
import 'billing_rule_secure_http_loader.dart';
import 'billing_rule_storage.dart';
import 'billing_rule_update_configuration.dart';

export 'billing_rule_secure_http_loader.dart';
export 'billing_rule_runtime_evaluator.dart'
    show BillingRulePersonalConflict, BillingRulePersonalRegressionResult;

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
typedef BillingRulePersonalRuleReconciler = Future<void> Function(
  BillingRulePersonalRegressionResult result,
  String publicRulesVersion,
);
typedef BillingRulePersonalReconciliationVerifier = Future<bool> Function(
  BillingRulePersonalRegressionResult result,
  String publicRulesVersion,
);
typedef BillingRuleUpdateClock = DateTime Function();
typedef BillingRuleRollbackSwitchHook = Future<void> Function();

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
  recovered,
  failed,
}

/// 测试专用的进程终止故障点；服务必须原样抛出，模拟 journal 落盘后崩溃。
class BillingRuleActivationInterruption implements Exception {
  /// 创建一次模拟进程终止。
  const BillingRuleActivationInterruption();
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

/// 最近一次自动或手动检查的持久化、可直接展示的稳定诊断。
class BillingRuleUpdateCheckDiagnostics {
  final BillingRuleUpdateStatus status;
  final String? rulesVersion;
  final String reason;
  final DateTime resultAt;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;

  const BillingRuleUpdateCheckDiagnostics({
    required this.status,
    required this.reason,
    required this.resultAt,
    this.rulesVersion,
    this.lastAttemptAt,
    this.lastSuccessAt,
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
  final BillingRulePersonalRuleReconciler? personalRuleReconciler;
  final BillingRulePersonalReconciliationVerifier?
      personalRuleReconciliationVerifier;
  final void Function()? beforeAtomicSwitch;

  /// journal 每次成功落盘后的故障注入点，仅用于中断/重启测试。
  final void Function(BillingRuleActivationState state)?
      afterActivationStatePersisted;
  final BillingRuleRollbackSwitchHook? beforeRollbackAtomicSwitch;

  /// 活动文件完成原子切换或恢复后使运行时内存快照失效。
  final void Function() onActiveSnapshotChanged;
  final BillingRuleUpdateClock clock;
  final BillingRuleDurability durability;

  BillingRuleUpdateService({
    this.storageDirectory,
    this.ruleStorage,
    required this.configuration,
    BillingRuleManifestLoader? manifestLoader,
    BillingRulePackageDownloader? rulePackageDownloader,
    BillingRuleSmokeTest? smokeTest,
    required this.upgradeEvaluation,
    required this.personalRegression,
    BillingRulePersonalRuleArchiver? personalRuleArchiver,
    this.personalRuleReconciler,
    this.personalRuleReconciliationVerifier,
    this.beforeAtomicSwitch,
    this.afterActivationStatePersisted,
    this.beforeRollbackAtomicSwitch,
    void Function()? onActiveSnapshotChanged,
    BillingRuleUpdateClock? clock,
    BillingRuleDurability? durability,
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
        personalRuleArchiver =
            personalRuleArchiver ?? _missingPersonalRuleArchiver,
        onActiveSnapshotChanged =
            onActiveSnapshotChanged ?? invalidateProductionBillingRuleSnapshot,
        clock = clock ?? DateTime.now,
        durability = durability ?? productionBillingRuleDurability(),
        assert(ruleStorage == null || storageDirectory == null);

  /// 当前显式配置的 manifest URI；禁用时可能为空或不可信，仅用于诊断。
  Uri? get manifestUri => configuration.manifestUri;

  /// 在同一规则目录互斥区恢复上次被进程终止的状态转换。
  Future<BillingRuleUpdateResult> reconcileInterruptedActivation() async {
    final storage = await _storage();
    return storage.runExclusive(() => _reconcileInterruptedActivation(storage));
  }

  /// 读取最近一次持久化激活诊断；损坏 journal 会被隔离并返回失败诊断。
  Future<BillingRuleActivationDiagnostics?> activationDiagnostics() async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      try {
        final journal = await _journalStore(storage).read();
        if (journal == null) return null;
        final activeExists = await storage.activeFile.exists();
        final previousExists = await storage.previousFile.exists();
        final active = await _snapshot(storage.activeFile);
        final previous = await _snapshot(storage.previousFile);
        return BillingRuleActivationDiagnostics(
          state: journal.state,
          operation: journal.operation,
          activeVersion: active?.version,
          previousVersion: previous?.version,
          candidateVersion: journal.candidateVersion,
          lastError: journal.lastError,
          lastAttemptAt: journal.lastAttemptAt,
          lastSuccessAt: journal.lastSuccessAt,
          diskStateVerified: (!activeExists || active != null) &&
              (!previousExists || previous != null),
        );
      } catch (_) {
        return null;
      }
    });
  }

  /// 读取自动/手动检查的稳定结果；原始异常只进入日志，不写入该展示边界。
  Future<BillingRuleUpdateCheckDiagnostics?> checkDiagnostics() async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      final state = await _readCheckState(storage.lastCheckFile);
      final status = state.lastStatus;
      final resultAt = state.lastResultAt;
      if (status == null || resultAt == null) return null;
      return BillingRuleUpdateCheckDiagnostics(
        status: status,
        rulesVersion: state.lastRulesVersion,
        reason: state.lastReason ?? _stableResultReason(status),
        resultAt: resultAt,
        lastAttemptAt: state.lastAttemptAt,
        lastSuccessAt: state.lastSuccessAt,
      );
    });
  }

  Future<BillingRuleUpdateResult> checkForUpdateIfDue({
    Duration minInterval = const Duration(days: 1),
  }) async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      final disabled = _disabledResult();
      if (disabled != null) {
        await _recordCheckResult(storage, disabled, attempted: false);
        return disabled;
      }
      final recovery = await _reconcileInterruptedActivation(storage);
      if (recovery.status == BillingRuleUpdateStatus.failed) {
        await _recordCheckResult(storage, recovery, attempted: false);
        return recovery;
      }
      await storage.directory.create(recursive: true);
      final lastCheckFile = storage.lastCheckFile;
      final now = clock().toUtc();

      final state = await _readCheckState(lastCheckFile);
      if (state.lastSuccessAt != null &&
          now.difference(state.lastSuccessAt!) < minInterval) {
        const result = BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
          message:
              'Update check skipped because the daily interval has not elapsed.',
        );
        await _recordCheckResult(storage, result,
            attempted: false, state: state);
        return result;
      }
      final lastAttempt = state.lastAttemptAt;
      final lastAttemptFailed = lastAttempt != null &&
          (state.lastSuccessAt == null ||
              lastAttempt.isAfter(state.lastSuccessAt!));
      if (lastAttemptFailed &&
          now.difference(lastAttempt) < configuration.failureRetryInterval) {
        const result = BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.notDue,
          message: '上次更新失败，尚未到短退避重试时间。',
        );
        await _recordCheckResult(storage, result,
            attempted: false, state: state);
        return result;
      }

      final result = await _checkForUpdate(storage);
      await _recordCheckResult(storage, result, attempted: true, state: state);
      return result;
    });
  }

  Future<BillingRuleUpdateResult> checkForUpdate() async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      final disabled = _disabledResult();
      if (disabled != null) {
        await _recordCheckResult(storage, disabled, attempted: false);
        return disabled;
      }
      final recovery = await _reconcileInterruptedActivation(storage);
      if (recovery.status == BillingRuleUpdateStatus.failed) {
        await _recordCheckResult(storage, recovery, attempted: false);
        return recovery;
      }
      final result = await _checkForUpdate(storage);
      await _recordCheckResult(storage, result, attempted: true);
      return result;
    });
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
      await _writeDurable(candidateFile, remoteToml);
      var activeBefore = await _snapshot(activeFile);
      var previousBefore = await _snapshot(previousFile);
      if (await activeFile.exists() && activeBefore == null) {
        await _quarantineIfExists(activeFile, 'damaged-active');
      }
      if (await previousFile.exists() && previousBefore == null) {
        await _quarantineIfExists(previousFile, 'damaged-previous');
        previousBefore = null;
      }
      activeBefore ??= previousBefore;
      var journal = BillingRuleActivationJournal(
        state: BillingRuleActivationState.downloaded,
        operation: BillingRuleActivationOperation.update,
        candidateVersion: manifest.latest.rulesVersion,
        candidateSha256: remoteHash,
        activeVersionBefore: activeBefore?.version,
        activeSha256Before: activeBefore?.sha256,
        previousVersionBefore: previousBefore?.version,
        previousSha256Before: previousBefore?.sha256,
        regression: const BillingRulePersonalRegressionResult.passed(),
        lastAttemptAt: clock().toUtc(),
      );
      await _persistJournal(storage, journal);
      final candidateRuleSet = await _tryLoadRuleSet(candidateFile);
      if (candidateRuleSet == null ||
          candidateRuleSet.schemaVersion != manifest.latest.schemaVersion ||
          candidateRuleSet.rulesVersion != manifest.latest.rulesVersion) {
        return _abortTransition(
          storage,
          journal,
          BillingRuleUpdateStatus.invalidRulePackage,
          '候选规则包解析、schema 或版本不匹配。',
        );
      }

      if (!await smokeTest(candidateRuleSet)) {
        return _abortTransition(storage, journal,
            BillingRuleUpdateStatus.smokeTestFailed, '候选规则 smoke test 失败。');
      }
      journal = journal.copyWith(state: BillingRuleActivationState.validated);
      await _persistJournal(storage, journal);

      if (!await upgradeEvaluation(candidateRuleSet)) {
        return _abortTransition(storage, journal,
            BillingRuleUpdateStatus.goldenEvaluationFailed, '候选规则黄金样本评测失败。');
      }
      final regression = await personalRegression(candidateRuleSet);
      if (!regression.isPassed) {
        return _abortTransition(
          storage,
          journal,
          BillingRuleUpdateStatus.personalRegressionFailed,
          regression.explanation ?? '候选规则个人样本回归失败。',
        );
      }
      journal = BillingRuleActivationJournal(
        state: BillingRuleActivationState.evaluated,
        operation: journal.operation,
        candidateVersion: journal.candidateVersion,
        candidateSha256: journal.candidateSha256,
        activeVersionBefore: journal.activeVersionBefore,
        activeSha256Before: journal.activeSha256Before,
        previousVersionBefore: journal.previousVersionBefore,
        previousSha256Before: journal.previousSha256Before,
        regression: regression,
        lastAttemptAt: journal.lastAttemptAt,
      );
      await _persistJournal(storage, journal);

      if (await activeFile.exists()) {
        final previousPending = storage.previousPendingFile;
        await _writeDurable(previousPending, await activeFile.readAsString());
        await previousPending.rename(previousFile.path);
        await durability.syncFileAndParent(previousFile);
      }
      journal =
          journal.copyWith(state: BillingRuleActivationState.switchPrepared);
      await _persistJournal(storage, journal);
      try {
        beforeAtomicSwitch?.call();
      } on BillingRuleActivationInterruption {
        rethrow;
      } catch (error) {
        return _abortTransition(storage, journal,
            BillingRuleUpdateStatus.failed, '原子切换准备失败：$error');
      }
      final candidateNow = await _snapshot(candidateFile);
      if (candidateNow?.sha256 != journal.candidateSha256 ||
          candidateNow?.version != journal.candidateVersion) {
        await _quarantineIfExists(candidateFile, 'candidate-tampered');
        return _abortTransition(
          storage,
          journal,
          BillingRuleUpdateStatus.failed,
          '候选规则在评测与切换之间发生变化，已隔离并拒绝激活。',
        );
      }
      await candidateFile.rename(activeFile.path);
      await durability.syncFileAndParent(activeFile);
      onActiveSnapshotChanged();
      final switched = await _snapshot(activeFile);
      if (switched?.sha256 != journal.candidateSha256 ||
          switched?.version != journal.candidateVersion) {
        return _restoreAfterUncommittedReconciliation(
          storage,
          journal,
          '切换后的 active 无法按候选哈希和版本读取。',
        );
      }
      journal =
          journal.copyWith(state: BillingRuleActivationState.activeSwitched);
      await _persistJournal(storage, journal);
      String? activationMessage = regression.conflictExplanation;
      if (personalRuleReconciler != null ||
          regression.equivalentPersonalRuleIds.isNotEmpty) {
        try {
          final reconciler = personalRuleReconciler;
          if (reconciler != null) {
            await reconciler(regression, candidateRuleSet.rulesVersion);
          } else {
            await personalRuleArchiver
                .call(regression.equivalentPersonalRuleIds);
          }
        } catch (e) {
          return _resolveReconciliationFailure(storage, journal, e);
        }
      }

      journal = journal.copyWith(
          state: BillingRuleActivationState.personalReconciled);
      await _persistJournal(storage, journal);
      journal = journal.copyWith(
        state: BillingRuleActivationState.committed,
        lastSuccessAt: clock().toUtc(),
        clearError: true,
      );
      await _persistJournal(storage, journal);

      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.activated,
        rulesVersion: candidateRuleSet.rulesVersion,
        message: activationMessage,
      );
    } on BillingRuleActivationInterruption {
      rethrow;
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

  Future<void> _persistJournal(
    BillingRuleStorage storage,
    BillingRuleActivationJournal journal,
  ) async {
    await _journalStore(storage).write(journal);
    afterActivationStatePersisted?.call(journal.state);
  }

  Future<BillingRuleUpdateResult> _reconcileInterruptedActivation(
      BillingRuleStorage storage) async {
    final store = _journalStore(storage);
    BillingRuleActivationJournal? journal;
    try {
      journal = await store.read();
    } catch (error) {
      final fallback = await _snapshot(storage.previousFile);
      await _quarantineIfExists(storage.activeFile, 'journal-corrupt');
      if (fallback != null) {
        await _atomicCopy(storage.previousFile,
            storage.activeRecoveryPendingFile, storage.activeFile);
      } else if (await storage.previousFile.exists()) {
        await _quarantineIfExists(
            storage.previousFile, 'journal-corrupt-previous');
      }
      onActiveSnapshotChanged();
      final now = clock().toUtc();
      final diagnostic = BillingRuleActivationJournal(
        state: BillingRuleActivationState.committed,
        operation: BillingRuleActivationOperation.update,
        candidateVersion: fallback?.version ?? 'built-in',
        candidateSha256: fallback?.sha256 ?? '',
        activeVersionBefore: fallback?.version,
        activeSha256Before: fallback?.sha256,
        previousVersionBefore: fallback?.version,
        previousSha256Before: fallback?.sha256,
        regression: const BillingRulePersonalRegressionResult.passed(),
        lastAttemptAt: now,
        lastError:
            '激活 journal 已损坏并隔离，已恢复${fallback == null ? '内置' : ' previous'}规则：$error',
      );
      await store.write(diagnostic);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.recovered,
        rulesVersion: fallback?.version,
        message: diagnostic.lastError,
      );
    }
    if (journal == null ||
        journal.state == BillingRuleActivationState.committed) {
      return const BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.recovered);
    }
    var currentJournal = journal;
    await storage.directory.create(recursive: true);
    final active = await _snapshot(storage.activeFile);
    final candidateIsActive =
        active?.sha256 == currentJournal.candidateSha256 &&
            active?.version == currentJournal.candidateVersion;

    if (currentJournal.state.index <
        BillingRuleActivationState.switchPrepared.index) {
      final aborted = currentJournal.copyWith(
        state: BillingRuleActivationState.committed,
        lastError: '启动恢复：候选尚未准备切换，继续使用旧安全快照。',
      );
      await store.write(aborted);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.recovered,
        rulesVersion: currentJournal.activeVersionBefore,
        message: aborted.lastError,
      );
    }

    if (!candidateIsActive) {
      final oldStillActive =
          active?.sha256 == currentJournal.activeSha256Before;
      if (!oldStillActive && currentJournal.activeSha256Before != null) {
        final previous = await _snapshot(storage.previousFile);
        if (previous?.sha256 != currentJournal.activeSha256Before) {
          await _quarantineIfExists(storage.activeFile, 'unproven-active');
          if (await storage.previousFile.exists() && previous == null) {
            await _quarantineIfExists(
                storage.previousFile, 'unproven-previous');
          }
          onActiveSnapshotChanged();
          final aborted = currentJournal.copyWith(
            state: BillingRuleActivationState.committed,
            lastError: 'active 与 previous 都无法证明为旧安全快照，已隔离并恢复内置规则。',
          );
          await store.write(aborted);
          return BillingRuleUpdateResult(
            status: BillingRuleUpdateStatus.recovered,
            message: aborted.lastError,
          );
        }
        await _atomicCopy(storage.previousFile,
            storage.activeRecoveryPendingFile, storage.activeFile);
        onActiveSnapshotChanged();
      } else if (!oldStillActive && currentJournal.activeSha256Before == null) {
        await _quarantineIfExists(storage.activeFile, 'first-activation');
        onActiveSnapshotChanged();
      }
      final aborted = currentJournal.copyWith(
        state: BillingRuleActivationState.committed,
        lastError: '启动恢复：切换未完成，已恢复旧安全快照。',
      );
      await store.write(aborted);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.recovered,
        rulesVersion: currentJournal.activeVersionBefore,
        message: aborted.lastError,
      );
    }

    if (currentJournal.operation == BillingRuleActivationOperation.rollback &&
        currentJournal.activeSha256Before != null) {
      final previous = await _snapshot(storage.previousFile);
      if (previous?.sha256 != currentJournal.activeSha256Before) {
        final prepared = await _snapshot(storage.previousRollbackPendingFile);
        if (prepared?.sha256 != currentJournal.activeSha256Before) {
          return const BillingRuleUpdateResult(
            status: BillingRuleUpdateStatus.failed,
            message: '恢复失败：回滚后的 previous 无法证明为切换前 active。',
          );
        }
        await storage.previousRollbackPendingFile
            .rename(storage.previousFile.path);
        await durability.syncFileAndParent(storage.previousFile);
      }
    }

    try {
      if (currentJournal.state.index <
          BillingRuleActivationState.personalReconciled.index) {
        final reconciler = personalRuleReconciler;
        if (reconciler != null) {
          await reconciler(
              currentJournal.regression, currentJournal.candidateVersion);
        } else {
          await personalRuleArchiver(
              currentJournal.regression.equivalentPersonalRuleIds);
        }
        currentJournal = currentJournal.copyWith(
            state: BillingRuleActivationState.personalReconciled);
        await store.write(currentJournal);
      }
      final committed = currentJournal.copyWith(
        state: BillingRuleActivationState.committed,
        lastSuccessAt: clock().toUtc(),
        clearError: true,
      );
      await store.write(committed);
      onActiveSnapshotChanged();
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.recovered,
        rulesVersion: currentJournal.candidateVersion,
      );
    } catch (error) {
      final verifier = personalRuleReconciliationVerifier;
      if (verifier == null) {
        final failed =
            currentJournal.copyWith(lastError: '启动恢复个人规则裁决结果无法证明：$error');
        await store.write(failed);
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.failed,
          rulesVersion: currentJournal.candidateVersion,
          message: failed.lastError,
        );
      }
      bool applied;
      try {
        applied = await verifier(
            currentJournal.regression, currentJournal.candidateVersion);
      } catch (verificationError) {
        final failed = currentJournal.copyWith(
            lastError: '启动恢复个人裁决验证失败：$verificationError');
        await store.write(failed);
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.failed,
          rulesVersion: currentJournal.candidateVersion,
          message: failed.lastError,
        );
      }
      if (applied) {
        final committed = currentJournal.copyWith(
          state: BillingRuleActivationState.committed,
          lastSuccessAt: clock().toUtc(),
          clearError: true,
        );
        await store.write(committed);
        onActiveSnapshotChanged();
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.recovered,
          rulesVersion: currentJournal.candidateVersion,
          message: '个人规则裁决已由 SQLite 事务完整提交，journal 已补记完成。',
        );
      }
      final previous = await _snapshot(storage.previousFile);
      final canRestorePrevious = currentJournal.activeSha256Before != null &&
          previous?.sha256 == currentJournal.activeSha256Before;
      if (canRestorePrevious || currentJournal.activeSha256Before == null) {
        await _quarantineIfExists(storage.activeFile, 'reconcile-failed');
        if (canRestorePrevious) {
          await _atomicCopy(storage.previousFile,
              storage.activeRecoveryPendingFile, storage.activeFile);
        }
        onActiveSnapshotChanged();
        final restored = currentJournal.copyWith(
          state: BillingRuleActivationState.committed,
          lastError:
              '启动恢复个人规则裁决失败，已恢复${canRestorePrevious ? '旧活动' : '内置'}规则：$error',
        );
        await store.write(restored);
        return BillingRuleUpdateResult(
          status: BillingRuleUpdateStatus.recovered,
          rulesVersion: currentJournal.activeVersionBefore,
          message: restored.lastError,
        );
      }
      if (await storage.previousFile.exists()) {
        await _quarantineIfExists(storage.previousFile, 'damaged-previous');
      }
      await _quarantineIfExists(storage.activeFile, 'uncommitted-candidate');
      onActiveSnapshotChanged();
      final failed = currentJournal.copyWith(lastError: '启动恢复个人规则裁决失败：$error');
      await store.write(failed);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        rulesVersion: currentJournal.candidateVersion,
        message: failed.lastError,
      );
    }
  }

  Future<_RuleFileSnapshot?> _snapshot(File file) async {
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    final rules = await _tryLoadRuleSet(file);
    if (rules == null) return null;
    return _RuleFileSnapshot(
      version: rules.rulesVersion,
      sha256: sha256.convert(utf8.encode(text)).toString(),
    );
  }

  Future<void> _atomicCopy(File source, File pending, File target) async {
    await _writeDurable(pending, await source.readAsString());
    await pending.rename(target.path);
    await durability.syncFileAndParent(target);
  }

  Future<File?> _quarantineIfExists(File file, String reason) async {
    if (!await file.exists()) return null;
    final quarantined =
        File('${file.path}.$reason.${clock().toUtc().microsecondsSinceEpoch}');
    final result = await file.rename(quarantined.path);
    await durability.syncFileAndParent(result);
    return result;
  }

  Future<BillingRuleUpdateResult> rollback() async {
    final storage = await _storage();
    return storage.runExclusive(() async {
      final recovery = await _reconcileInterruptedActivation(storage);
      if (recovery.status == BillingRuleUpdateStatus.failed) return recovery;
      return _rollback(storage);
    });
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
    final previousHash = sha256.convert(utf8.encode(previousText)).toString();
    final activeBefore = await _snapshot(activeFile);
    final previousBefore = await _snapshot(previousFile);
    if (previousBefore == null || previousBefore.sha256 != previousHash) {
      await _quarantineIfExists(previousFile, 'damaged-rollback-previous');
      return const BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.rollbackUnavailable,
        message: 'previous 规则无法通过解析、schema 与哈希读取校验。',
      );
    }

    final rollbackPending = storage.activeRollbackPendingFile;
    await _writeDurable(rollbackPending, previousText);
    var journal = BillingRuleActivationJournal(
      state: BillingRuleActivationState.downloaded,
      operation: BillingRuleActivationOperation.rollback,
      candidateVersion: previousBefore.version,
      candidateSha256: previousHash,
      activeVersionBefore: activeBefore?.version,
      activeSha256Before: activeBefore?.sha256,
      previousVersionBefore: previousBefore.version,
      previousSha256Before: previousBefore.sha256,
      regression: const BillingRulePersonalRegressionResult.passed(),
      lastAttemptAt: clock().toUtc(),
    );
    await _persistJournal(storage, journal);

    final candidate = await _tryLoadRuleSet(rollbackPending);
    if (candidate == null || candidate.rulesVersion != previousBefore.version) {
      return _abortTransition(storage, journal,
          BillingRuleUpdateStatus.invalidRulePackage, '回滚候选解析失败。');
    }
    if (!await smokeTest(candidate)) {
      return _abortTransition(storage, journal,
          BillingRuleUpdateStatus.smokeTestFailed, '回滚候选 smoke test 失败。');
    }
    journal = journal.copyWith(state: BillingRuleActivationState.validated);
    await _persistJournal(storage, journal);

    if (!await upgradeEvaluation(candidate)) {
      return _abortTransition(storage, journal,
          BillingRuleUpdateStatus.goldenEvaluationFailed, '回滚候选黄金样本评测失败。');
    }
    final regression = await personalRegression(candidate);
    if (!regression.isPassed) {
      return _abortTransition(
          storage,
          journal,
          BillingRuleUpdateStatus.personalRegressionFailed,
          regression.explanation ?? '回滚候选个人样本回归失败。');
    }
    journal = BillingRuleActivationJournal(
      state: BillingRuleActivationState.evaluated,
      operation: BillingRuleActivationOperation.rollback,
      candidateVersion: journal.candidateVersion,
      candidateSha256: journal.candidateSha256,
      activeVersionBefore: journal.activeVersionBefore,
      activeSha256Before: journal.activeSha256Before,
      previousVersionBefore: journal.previousVersionBefore,
      previousSha256Before: journal.previousSha256Before,
      regression: regression,
      lastAttemptAt: journal.lastAttemptAt,
    );
    await _persistJournal(storage, journal);

    if (await activeFile.exists()) {
      await _writeDurable(
          storage.previousRollbackPendingFile, await activeFile.readAsString());
    }
    journal =
        journal.copyWith(state: BillingRuleActivationState.switchPrepared);
    await _persistJournal(storage, journal);
    await beforeRollbackAtomicSwitch?.call();

    final sourceNow = await _snapshot(previousFile);
    final pendingNow = await _snapshot(rollbackPending);
    if (sourceNow?.sha256 != previousHash ||
        pendingNow?.sha256 != previousHash) {
      return _abortTransition(storage, journal, BillingRuleUpdateStatus.failed,
          'previous 在回滚验证与切换之间发生变化，已拒绝切换。');
    }
    await rollbackPending.rename(activeFile.path);
    await durability.syncFileAndParent(activeFile);
    if (activeBefore != null) {
      await storage.previousRollbackPendingFile.rename(previousFile.path);
      await durability.syncFileAndParent(previousFile);
    }
    onActiveSnapshotChanged();
    journal =
        journal.copyWith(state: BillingRuleActivationState.activeSwitched);
    await _persistJournal(storage, journal);

    try {
      final activated = await _snapshot(activeFile);
      if (activated?.sha256 != previousHash ||
          activated?.version != candidate.rulesVersion) {
        return _restoreAfterUncommittedReconciliation(
          storage,
          journal,
          '回滚切换后的 runtime active 无法按原哈希读取。',
        );
      }
      final reconciler = personalRuleReconciler;
      if (reconciler != null) {
        await reconciler(regression, candidate.rulesVersion);
      } else {
        await personalRuleArchiver(regression.equivalentPersonalRuleIds);
      }
      journal = journal.copyWith(
          state: BillingRuleActivationState.personalReconciled);
      await _persistJournal(storage, journal);
      journal = journal.copyWith(
        state: BillingRuleActivationState.committed,
        lastSuccessAt: clock().toUtc(),
        clearError: true,
      );
      await _persistJournal(storage, journal);
      onActiveSnapshotChanged();
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.rolledBack,
        rulesVersion: activated?.version,
      );
    } on BillingRuleActivationInterruption {
      rethrow;
    } catch (error) {
      return _resolveReconciliationFailure(storage, journal, error);
    }
  }

  Future<BillingRuleUpdateResult> _resolveReconciliationFailure(
    BillingRuleStorage storage,
    BillingRuleActivationJournal journal,
    Object error,
  ) async {
    final verifier = personalRuleReconciliationVerifier;
    if (verifier == null) {
      final failed = journal.copyWith(lastError: '个人裁决结果无法证明：$error');
      await _journalStore(storage).write(failed);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        rulesVersion: journal.candidateVersion,
        message: failed.lastError,
      );
    }
    bool applied;
    try {
      applied = await verifier(journal.regression, journal.candidateVersion);
    } catch (verificationError) {
      final failed =
          journal.copyWith(lastError: '个人裁决验证失败，保持未提交状态：$verificationError');
      await _journalStore(storage).write(failed);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        rulesVersion: journal.candidateVersion,
        message: failed.lastError,
      );
    }
    if (applied) {
      var completed = journal.copyWith(
          state: BillingRuleActivationState.personalReconciled);
      await _journalStore(storage).write(completed);
      completed = completed.copyWith(
        state: BillingRuleActivationState.committed,
        lastSuccessAt: clock().toUtc(),
        clearError: true,
      );
      await _journalStore(storage).write(completed);
      onActiveSnapshotChanged();
      return BillingRuleUpdateResult(
        status: journal.operation == BillingRuleActivationOperation.rollback
            ? BillingRuleUpdateStatus.rolledBack
            : BillingRuleUpdateStatus.activated,
        rulesVersion: journal.candidateVersion,
        message: '个人裁决已提交，已补记完成。',
      );
    }
    return _restoreAfterUncommittedReconciliation(
      storage,
      journal,
      '个人裁决未提交，已恢复切换前公共规则：$error',
    );
  }

  Future<BillingRuleUpdateResult> _restoreAfterUncommittedReconciliation(
    BillingRuleStorage storage,
    BillingRuleActivationJournal journal,
    String message,
  ) async {
    final oldHash = journal.activeSha256Before;
    final previous = await _snapshot(storage.previousFile);
    if (oldHash != null && previous?.sha256 != oldHash) {
      if (await storage.previousFile.exists()) {
        await _quarantineIfExists(storage.previousFile, 'damaged-previous');
      }
      await _quarantineIfExists(storage.activeFile, 'uncommitted-candidate');
      onActiveSnapshotChanged();
      final failed = journal.copyWith(
          lastError: '$message；previous 无法证明为切换前 active，保持未提交。');
      await _journalStore(storage).write(failed);
      return BillingRuleUpdateResult(
        status: BillingRuleUpdateStatus.failed,
        rulesVersion: journal.candidateVersion,
        message: failed.lastError,
      );
    }
    await _quarantineIfExists(storage.activeFile, 'uncommitted-candidate');
    if (oldHash != null) {
      await _atomicCopy(storage.previousFile, storage.activeRecoveryPendingFile,
          storage.activeFile);
    }
    onActiveSnapshotChanged();
    return _abortTransition(
      storage,
      journal,
      BillingRuleUpdateStatus.failed,
      oldHash == null ? '$message（built-in snapshot restored）' : message,
    );
  }

  Future<BillingRuleUpdateResult> _abortTransition(
    BillingRuleStorage storage,
    BillingRuleActivationJournal journal,
    BillingRuleUpdateStatus status,
    String message,
  ) async {
    await _journalStore(storage).write(journal.copyWith(
      state: BillingRuleActivationState.committed,
      lastError: message,
    ));
    return BillingRuleUpdateResult(
      status: status,
      rulesVersion: journal.candidateVersion,
      message: message,
    );
  }

  BillingRuleActivationJournalStore _journalStore(BillingRuleStorage storage) =>
      BillingRuleActivationJournalStore(storage, durability: durability);

  Future<void> _writeDurable(File file, String text) async {
    await file.writeAsString(text, flush: true);
    await durability.syncFileAndParent(file);
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

      BillingRuleUpdateStatus? parseStatus() {
        final value = json['lastStatus'];
        if (value is! String) return null;
        for (final status in BillingRuleUpdateStatus.values) {
          if (status.name == value) return status;
        }
        return null;
      }

      // 兼容旧版本：旧 checkedAt 只代表一次尝试，不能再视为成功而压住 24h。
      return _BillingRuleCheckState(
        lastAttemptAt: parse('lastAttemptAt') ?? parse('checkedAt'),
        lastSuccessAt: parse('lastSuccessAt'),
        lastResultAt: parse('lastResultAt'),
        lastStatus: parseStatus(),
        lastRulesVersion: json['lastRulesVersion'] as String?,
        lastReason: json['lastReason'] as String?,
      );
    } catch (_) {
      return const _BillingRuleCheckState();
    }
  }

  Future<void> _recordCheckResult(
    BillingRuleStorage storage,
    BillingRuleUpdateResult result, {
    required bool attempted,
    _BillingRuleCheckState? state,
  }) async {
    final previous = state ?? await _readCheckState(storage.lastCheckFile);
    final now = clock().toUtc();
    final isSuccess = result.status == BillingRuleUpdateStatus.activated ||
        result.status == BillingRuleUpdateStatus.alreadyLatest;
    final version = result.rulesVersion ??
        (await _snapshot(storage.activeFile))?.version ??
        previous.lastRulesVersion;
    await storage.lastCheckFile.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        if (attempted)
          'lastAttemptAt': now.toIso8601String()
        else if (previous.lastAttemptAt != null)
          'lastAttemptAt': previous.lastAttemptAt!.toIso8601String(),
        if (isSuccess)
          'lastSuccessAt': now.toIso8601String()
        else if (previous.lastSuccessAt != null)
          'lastSuccessAt': previous.lastSuccessAt!.toIso8601String(),
        'lastResultAt': now.toIso8601String(),
        'lastStatus': result.status.name,
        if (version != null) 'lastRulesVersion': version,
        'lastReason': _stableResultReason(result.status),
      }),
      flush: true,
    );
    await durability.syncFileAndParent(storage.lastCheckFile);
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
  final DateTime? lastResultAt;
  final BillingRuleUpdateStatus? lastStatus;
  final String? lastRulesVersion;
  final String? lastReason;

  const _BillingRuleCheckState({
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastResultAt,
    this.lastStatus,
    this.lastRulesVersion,
    this.lastReason,
  });
}

class _RuleFileSnapshot {
  final String version;
  final String sha256;

  const _RuleFileSnapshot({required this.version, required this.sha256});
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

String _stableResultReason(BillingRuleUpdateStatus status) => switch (status) {
      BillingRuleUpdateStatus.disabled => '远程规则更新未启用',
      BillingRuleUpdateStatus.activated => '新规则已安全启用',
      BillingRuleUpdateStatus.alreadyLatest => '当前已经是最新规则',
      BillingRuleUpdateStatus.notDue => '尚未到下一次自动检查时间',
      BillingRuleUpdateStatus.securityPolicyRejected => '更新来源未通过安全策略',
      BillingRuleUpdateStatus.incompatibleAppVersion => '规则需要更高版本的 App',
      BillingRuleUpdateStatus.responseTooLarge => '下载内容超过安全上限',
      BillingRuleUpdateStatus.timedOut => '规则更新请求超时',
      BillingRuleUpdateStatus.hashMismatch => '规则包校验失败，已继续使用安全快照',
      BillingRuleUpdateStatus.invalidManifest => '更新清单无效，已继续使用安全快照',
      BillingRuleUpdateStatus.invalidRulePackage => '规则包无效，已继续使用安全快照',
      BillingRuleUpdateStatus.smokeTestFailed => '规则基础验证失败，已继续使用安全快照',
      BillingRuleUpdateStatus.goldenEvaluationFailed => '黄金样本回归失败，已继续使用安全快照',
      BillingRuleUpdateStatus.personalRegressionFailed =>
        '本机个人样本回归失败，已继续使用安全快照',
      BillingRuleUpdateStatus.rolledBack => '已安全回滚到上一版规则',
      BillingRuleUpdateStatus.rollbackUnavailable => '没有可安全回滚的上一版',
      BillingRuleUpdateStatus.recovered => '已恢复上次中断的规则操作',
      BillingRuleUpdateStatus.failed => '规则检查失败，已继续使用安全快照',
    };

Future<void> _missingPersonalRuleArchiver(List<String> ruleIds) async {
  if (ruleIds.isNotEmpty) {
    throw StateError('缺少个人规则归档实现，公共候选不能安全激活');
  }
}
