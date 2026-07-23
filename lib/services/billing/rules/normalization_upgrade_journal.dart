import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'billing_rule_durability.dart';

enum NormalizationUpgradeActivationState {
  prepared,
  ruleSwitched,
  normalizationSwitched,
  restoring,
  committed,
}

enum NormalizationUpgradeOperation { activate, rollback }

class NormalizationUpgradeJournal {
  static const schemaVersion = 1;

  final NormalizationUpgradeActivationState state;
  final NormalizationUpgradeOperation operation;
  final String migrationDecisionId;
  final int currentRulePackageVersion;
  final String currentRulesVersion;
  final int currentNormalizationVersion;
  final int candidateRulePackageVersion;
  final String candidateRulesVersion;
  final int candidateNormalizationVersion;
  final String? lastError;

  const NormalizationUpgradeJournal({
    required this.state,
    required this.operation,
    required this.migrationDecisionId,
    required this.currentRulePackageVersion,
    required this.currentRulesVersion,
    required this.currentNormalizationVersion,
    required this.candidateRulePackageVersion,
    required this.candidateRulesVersion,
    required this.candidateNormalizationVersion,
    this.lastError,
  });

  NormalizationUpgradeJournal copyWith({
    NormalizationUpgradeActivationState? state,
    String? lastError,
  }) =>
      NormalizationUpgradeJournal(
        state: state ?? this.state,
        operation: operation,
        migrationDecisionId: migrationDecisionId,
        currentRulePackageVersion: currentRulePackageVersion,
        currentRulesVersion: currentRulesVersion,
        currentNormalizationVersion: currentNormalizationVersion,
        candidateRulePackageVersion: candidateRulePackageVersion,
        candidateRulesVersion: candidateRulesVersion,
        candidateNormalizationVersion: candidateNormalizationVersion,
        lastError: lastError ?? this.lastError,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'state': state.name,
        'operation': operation.name,
        'migrationDecisionId': migrationDecisionId,
        'currentRulePackageVersion': currentRulePackageVersion,
        'currentRulesVersion': currentRulesVersion,
        'currentNormalizationVersion': currentNormalizationVersion,
        'candidateRulePackageVersion': candidateRulePackageVersion,
        'candidateRulesVersion': candidateRulesVersion,
        'candidateNormalizationVersion': candidateNormalizationVersion,
        'lastError': lastError,
      };

  factory NormalizationUpgradeJournal.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('不支持的归一化激活 journal schema');
    }
    T parseEnum<T extends Enum>(List<T> values, Object? raw) =>
        values.where((value) => value.name == raw).firstOrNull ??
        (throw const FormatException('归一化激活 journal 枚举无效'));
    return NormalizationUpgradeJournal(
      state: parseEnum(
        NormalizationUpgradeActivationState.values,
        json['state'],
      ),
      operation: parseEnum(
        NormalizationUpgradeOperation.values,
        json['operation'],
      ),
      migrationDecisionId: json['migrationDecisionId'] as String,
      currentRulePackageVersion: json['currentRulePackageVersion'] as int,
      currentRulesVersion: json['currentRulesVersion'] as String,
      currentNormalizationVersion: json['currentNormalizationVersion'] as int,
      candidateRulePackageVersion: json['candidateRulePackageVersion'] as int,
      candidateRulesVersion: json['candidateRulesVersion'] as String,
      candidateNormalizationVersion:
          json['candidateNormalizationVersion'] as int,
      lastError: json['lastError'] as String?,
    );
  }
}

abstract class NormalizationUpgradeJournalPersistence {
  Future<void> write(NormalizationUpgradeJournal journal);

  Future<NormalizationUpgradeJournal?> read();
}

class NormalizationUpgradeJournalStore
    implements NormalizationUpgradeJournalPersistence {
  final File file;
  final BillingRuleDurability durability;

  NormalizationUpgradeJournalStore(
    this.file, {
    BillingRuleDurability? durability,
  }) : durability = durability ?? productionBillingRuleDurability();

  @override
  Future<void> write(NormalizationUpgradeJournal journal) async {
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.pending');
    await pending.writeAsString(jsonEncode(journal.toJson()), flush: true);
    await durability.syncFileAndParent(pending);
    await pending.rename(file.path);
    await durability.syncFileAndParent(file);
  }

  @override
  Future<NormalizationUpgradeJournal?> read() async {
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('归一化激活 journal 不是对象');
    }
    return NormalizationUpgradeJournal.fromJson(
      Map<String, Object?>.from(decoded),
    );
  }
}
