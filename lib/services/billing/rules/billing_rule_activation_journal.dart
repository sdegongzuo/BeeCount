import 'dart:convert';
import 'dart:io';

import 'billing_rule_runtime_evaluator.dart';
import 'billing_rule_durability.dart';
import 'billing_rule_storage.dart';

/// 公共规则文件与个人规则裁决之间的可恢复激活阶段。
enum BillingRuleActivationState {
  downloaded,
  validated,
  evaluated,
  switchPrepared,
  activeSwitched,
  personalReconciled,
  committed,
}

/// 激活 journal 的操作类型。
enum BillingRuleActivationOperation { update, rollback }

/// 可由诊断 UI 直接读取的最近一次规则状态转换快照。
class BillingRuleActivationDiagnostics {
  final BillingRuleActivationState state;
  final BillingRuleActivationOperation operation;
  final String? activeVersion;
  final String? previousVersion;
  final String? candidateVersion;
  final String? lastError;
  final DateTime lastAttemptAt;
  final DateTime? lastSuccessAt;
  final bool diskStateVerified;

  /// 创建不可变诊断快照。
  const BillingRuleActivationDiagnostics({
    required this.state,
    required this.operation,
    required this.lastAttemptAt,
    this.activeVersion,
    this.previousVersion,
    this.candidateVersion,
    this.lastError,
    this.lastSuccessAt,
    this.diskStateVerified = false,
  });
}

/// 一次更新或回滚的持久化恢复记录。
class BillingRuleActivationJournal {
  static const schemaVersion = 1;

  final BillingRuleActivationState state;
  final BillingRuleActivationOperation operation;
  final String candidateVersion;
  final String candidateSha256;
  final String? activeVersionBefore;
  final String? activeSha256Before;
  final String? previousVersionBefore;
  final String? previousSha256Before;
  final BillingRulePersonalRegressionResult regression;
  final DateTime lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String? lastError;

  /// 创建一条完整、可重放的 journal 记录。
  const BillingRuleActivationJournal({
    required this.state,
    required this.operation,
    required this.candidateVersion,
    required this.candidateSha256,
    required this.regression,
    required this.lastAttemptAt,
    this.activeVersionBefore,
    this.activeSha256Before,
    this.previousVersionBefore,
    this.previousSha256Before,
    this.lastSuccessAt,
    this.lastError,
  });

  /// 返回只改变阶段或诊断字段的新记录。
  BillingRuleActivationJournal copyWith({
    BillingRuleActivationState? state,
    DateTime? lastSuccessAt,
    String? lastError,
    bool clearError = false,
  }) =>
      BillingRuleActivationJournal(
        state: state ?? this.state,
        operation: operation,
        candidateVersion: candidateVersion,
        candidateSha256: candidateSha256,
        activeVersionBefore: activeVersionBefore,
        activeSha256Before: activeSha256Before,
        previousVersionBefore: previousVersionBefore,
        previousSha256Before: previousSha256Before,
        regression: regression,
        lastAttemptAt: lastAttemptAt,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  BillingRuleActivationDiagnostics get diagnostics =>
      BillingRuleActivationDiagnostics(
        state: state,
        operation: operation,
        activeVersion: state == BillingRuleActivationState.committed &&
                lastSuccessAt == null
            ? activeVersionBefore
            : state.index >= BillingRuleActivationState.activeSwitched.index
                ? candidateVersion
                : activeVersionBefore,
        previousVersion: state == BillingRuleActivationState.committed &&
                lastSuccessAt == null
            ? previousVersionBefore
            : state.index >= BillingRuleActivationState.switchPrepared.index
                ? activeVersionBefore
                : previousVersionBefore,
        candidateVersion: candidateVersion,
        lastError: lastError,
        lastAttemptAt: lastAttemptAt,
        lastSuccessAt: lastSuccessAt,
        diskStateVerified: false,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'state': state.name,
        'operation': operation.name,
        'candidateVersion': candidateVersion,
        'candidateSha256': candidateSha256,
        'activeVersionBefore': activeVersionBefore,
        'activeSha256Before': activeSha256Before,
        'previousVersionBefore': previousVersionBefore,
        'previousSha256Before': previousSha256Before,
        'regression': {
          'isPassed': regression.isPassed,
          'expectedPersonalRulesVersion':
              regression.expectedPersonalRulesVersion,
          'equivalentPersonalRuleIds': regression.equivalentPersonalRuleIds,
          'conflicts': regression.conflicts
              .map((item) => {
                    'personalRuleId': item.personalRuleId,
                    'explanation': item.explanation,
                  })
              .toList(growable: false),
        },
        'lastAttemptAt': lastAttemptAt.toUtc().toIso8601String(),
        'lastSuccessAt': lastSuccessAt?.toUtc().toIso8601String(),
        'lastError': lastError,
      };

  /// 严格解析 journal；未知 schema、阶段或缺字段一律拒绝恢复。
  factory BillingRuleActivationJournal.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('不支持的激活 journal schema');
    }
    T enumValue<T extends Enum>(List<T> values, Object? raw, String name) =>
        values.where((item) => item.name == raw).firstOrNull ??
        (throw FormatException('无效的 $name'));
    final regressionJson = json['regression'];
    if (regressionJson is! Map || regressionJson['isPassed'] != true) {
      throw const FormatException('激活 journal 缺少通过的个人回归裁决');
    }
    final equivalent = regressionJson['equivalentPersonalRuleIds'];
    final conflicts = regressionJson['conflicts'];
    if (equivalent is! List || conflicts is! List) {
      throw const FormatException('激活 journal 个人裁决格式无效');
    }
    final attempt = DateTime.tryParse(json['lastAttemptAt']?.toString() ?? '');
    final candidateVersion = json['candidateVersion'];
    final candidateHash = json['candidateSha256'];
    if (attempt == null ||
        candidateVersion is! String ||
        candidateHash is! String) {
      throw const FormatException('激活 journal 缺少候选标识');
    }
    return BillingRuleActivationJournal(
      state:
          enumValue(BillingRuleActivationState.values, json['state'], 'state'),
      operation: enumValue(BillingRuleActivationOperation.values,
          json['operation'], 'operation'),
      candidateVersion: candidateVersion,
      candidateSha256: candidateHash,
      activeVersionBefore: json['activeVersionBefore'] as String?,
      activeSha256Before: json['activeSha256Before'] as String?,
      previousVersionBefore: json['previousVersionBefore'] as String?,
      previousSha256Before: json['previousSha256Before'] as String?,
      regression: BillingRulePersonalRegressionResult.passed(
        expectedPersonalRulesVersion:
            regressionJson['expectedPersonalRulesVersion'] as int?,
        equivalentPersonalRuleIds:
            equivalent.map((item) => item as String).toList(growable: false),
        conflicts: conflicts.map((item) {
          if (item is! Map) throw const FormatException('无效的冲突裁决');
          return BillingRulePersonalConflict(
            personalRuleId: item['personalRuleId'] as String,
            explanation: item['explanation'] as String,
          );
        }).toList(growable: false),
      ),
      lastAttemptAt: attempt.toUtc(),
      lastSuccessAt:
          DateTime.tryParse(json['lastSuccessAt']?.toString() ?? '')?.toUtc(),
      lastError: json['lastError'] as String?,
    );
  }
}

/// 以 flush + 同目录原子 rename 持久化 journal，并隔离损坏记录。
class BillingRuleActivationJournalStore {
  final BillingRuleStorage storage;
  final BillingRuleDurability durability;

  /// 创建绑定到唯一规则目录的 journal 存储。
  BillingRuleActivationJournalStore(
    this.storage, {
    BillingRuleDurability? durability,
  }) : durability = durability ?? productionBillingRuleDurability();

  /// 原子保存一个状态；固定 pending 文件可在下次恢复时安全复用。
  Future<void> write(BillingRuleActivationJournal journal) async {
    await storage.directory.create(recursive: true);
    final pending = storage.activationJournalPendingFile;
    await pending.writeAsString(jsonEncode(journal.toJson()), flush: true);
    await durability.syncFileAndParent(pending);
    await _renameWithTransientRetry(
        pending, storage.activationJournalFile.path);
    await durability.syncFileAndParent(storage.activationJournalFile);
  }

  /// 读取 journal；损坏内容会原子移入隔离文件而不是删除。
  Future<BillingRuleActivationJournal?> read() async {
    final file = storage.activationJournalFile;
    final pending = storage.activationJournalPendingFile;
    if (!await file.exists()) {
      if (!await pending.exists()) return null;
      try {
        final recovered = await _decode(pending);
        await _renameWithTransientRetry(pending, file.path);
        await durability.syncFileAndParent(file);
        return recovered;
      } catch (_) {
        await _quarantine(pending);
        rethrow;
      }
    }
    try {
      return await _decode(file);
    } catch (_) {
      await _quarantine(file);
      if (await pending.exists()) {
        try {
          final recovered = await _decode(pending);
          await _renameWithTransientRetry(pending, file.path);
          await durability.syncFileAndParent(file);
          return recovered;
        } catch (_) {
          await _quarantine(pending);
        }
      }
      rethrow;
    }
  }

  Future<BillingRuleActivationJournal> _decode(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) throw const FormatException('journal 不是对象');
    return BillingRuleActivationJournal.fromJson(
        Map<String, Object?>.from(decoded));
  }

  Future<void> _quarantine(File file) async {
    final suffix = DateTime.now().toUtc().microsecondsSinceEpoch;
    final quarantined = await file.rename('${file.path}.corrupt.$suffix');
    await durability.syncFileAndParent(quarantined);
  }

  Future<File> _renameWithTransientRetry(File source, String target) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await source.rename(target);
      } on PathAccessException {
        if (!Platform.isWindows || attempt >= 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }
}
