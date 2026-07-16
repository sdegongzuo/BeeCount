import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:beecount/services/billing/rules/billing_rule_activation_journal.dart';
import 'package:beecount/services/billing/rules/billing_rule_storage.dart';
import 'package:beecount/services/billing/rules/billing_rule_durability.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_configuration.dart';
import 'package:beecount/services/billing/rules/billing_rule_update_service.dart';
import 'package:beecount/data/db.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingRuleUpdateService activation recovery', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('rule_recovery_');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('activeSwitched interruption replays personal decision and commits',
        () async {
      final oldRules = _toml('old');
      final candidate = _toml('candidate');
      await File('${directory.path}/billing_rules.active.toml')
          .writeAsString(oldRules);
      var reconciliations = 0;
      final interrupted = _service(
        directory,
        candidate,
        personalReconciler: (_, __) async => reconciliations++,
        afterActivationStatePersisted: (state) {
          if (state == BillingRuleActivationState.activeSwitched) {
            throw const BillingRuleActivationInterruption();
          }
        },
      );

      await expectLater(
        interrupted.checkForUpdate(),
        throwsA(isA<BillingRuleActivationInterruption>()),
      );
      expect(reconciliations, 0);
      expect(
        await File('${directory.path}/billing_rules.active.toml')
            .readAsString(),
        contains('rulesVersion = "candidate"'),
      );

      final restarted = _service(
        directory,
        candidate,
        personalReconciler: (_, __) async => reconciliations++,
      );
      final result = await restarted.reconcileInterruptedActivation();

      expect(result.status, BillingRuleUpdateStatus.recovered);
      expect(reconciliations, 1);
      final diagnostics = await restarted.activationDiagnostics();
      expect(diagnostics?.state, BillingRuleActivationState.committed);
      expect(diagnostics?.activeVersion, 'candidate');
      expect(diagnostics?.previousVersion, 'old');
      expect(diagnostics?.lastSuccessAt, isNotNull);
    });

    for (final interruptedState in BillingRuleActivationState.values) {
      test('recovers idempotently after ${interruptedState.name}', () async {
        final oldRules = _toml('old');
        final candidate = _toml('candidate');
        await File('${directory.path}/billing_rules.active.toml')
            .writeAsString(oldRules);
        var reconciliations = 0;
        final interrupted = _service(
          directory,
          candidate,
          personalReconciler: (_, __) async => reconciliations++,
          afterActivationStatePersisted: (state) {
            if (state == interruptedState) {
              throw const BillingRuleActivationInterruption();
            }
          },
        );

        await expectLater(interrupted.checkForUpdate(),
            throwsA(isA<BillingRuleActivationInterruption>()));
        final restarted = _service(
          directory,
          candidate,
          personalReconciler: (_, __) async => reconciliations++,
        );
        expect(
          (await restarted.reconcileInterruptedActivation()).status,
          BillingRuleUpdateStatus.recovered,
        );
        expect(
          (await restarted.reconcileInterruptedActivation()).status,
          BillingRuleUpdateStatus.recovered,
          reason: '连续启动恢复必须幂等',
        );

        final candidateShouldBeActive = interruptedState.index >=
            BillingRuleActivationState.activeSwitched.index;
        final activeText =
            await File('${directory.path}/billing_rules.active.toml')
                .readAsString();
        expect(
            activeText,
            contains(
                'rulesVersion = "${candidateShouldBeActive ? 'candidate' : 'old'}"'));
        expect(reconciliations, candidateShouldBeActive ? 1 : 0);
        expect((await restarted.activationDiagnostics())?.state,
            BillingRuleActivationState.committed);
      });
    }

    test('corrupt journal is quarantined and never deleted', () async {
      final journal =
          File('${directory.path}/billing_rules.activation_journal.json');
      await journal.writeAsString('{broken', flush: true);
      final service = _service(directory, _toml('candidate'));

      final result = await service.reconcileInterruptedActivation();

      expect(result.status, BillingRuleUpdateStatus.recovered);
      expect(await journal.exists(), isTrue, reason: '原损坏内容隔离后应在稳定路径写入恢复诊断');
      expect(await journal.readAsString(), contains('committed'));
      expect(
        directory
            .listSync()
            .whereType<File>()
            .any((file) => file.path.contains('.json.corrupt.')),
        isTrue,
      );
    });

    test('valid pending journal is reused when stable journal is corrupt',
        () async {
      final storage = BillingRuleStorage(directory);
      final store = BillingRuleActivationJournalStore(storage);
      final pendingRecord = BillingRuleActivationJournal(
        state: BillingRuleActivationState.validated,
        operation: BillingRuleActivationOperation.update,
        candidateVersion: 'candidate',
        candidateSha256: 'a' * 64,
        regression: const BillingRulePersonalRegressionResult.passed(),
        lastAttemptAt: DateTime.utc(2026, 7, 17),
      );
      await store.write(pendingRecord);
      final validText = await storage.activationJournalFile.readAsString();
      await storage.activationJournalPendingFile
          .writeAsString(validText, flush: true);
      await storage.activationJournalFile.writeAsString('{broken', flush: true);

      final recovered = await store.read();

      expect(recovered?.state, BillingRuleActivationState.validated);
      expect(await storage.activationJournalPendingFile.exists(), isFalse);
      expect(
        directory
            .listSync()
            .whereType<File>()
            .any((file) => file.path.contains('.json.corrupt.')),
        isTrue,
      );
    });

    test('OS file lock serializes two real isolates and crash releases it',
        () async {
      final events = ReceivePort();
      final exits = ReceivePort();
      await Isolate.spawn(
        _holdStorageLock,
        [directory.path, 'first', events.sendPort, 300],
        onExit: exits.sendPort,
      );
      final iterator = StreamIterator<Object?>(events);
      expect(await iterator.moveNext(), isTrue);
      final firstEvent = iterator.current! as List<Object?>;
      expect(firstEvent.first, 'first');

      await Isolate.spawn(
        _holdStorageLock,
        [directory.path, 'second', events.sendPort, 0],
        onExit: exits.sendPort,
      );
      var secondEntered = false;
      final secondWait = iterator.moveNext().then((hasValue) {
        secondEntered = hasValue;
        return iterator.current! as List<Object?>;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(secondEntered, isFalse);
      final secondEvent = await secondWait.timeout(const Duration(seconds: 20));
      expect(secondEvent.first, 'second');
      final exitIterator = StreamIterator<Object?>(exits);
      expect(await exitIterator.moveNext(), isTrue);
      expect(await exitIterator.moveNext(), isTrue);

      final crashEvents = ReceivePort();
      final crashExit = ReceivePort();
      final crashing = await Isolate.spawn(
        _holdStorageLock,
        [directory.path, 'crash', crashEvents.sendPort, -1],
        onExit: crashExit.sendPort,
      );
      final crashEvent = await crashEvents.first as List<Object?>;
      expect(crashEvent.first, 'crash');
      crashing.kill(priority: Isolate.immediate);
      await crashExit.first;
      await BillingRuleStorage(directory)
          .runExclusive(() async {})
          .timeout(const Duration(seconds: 20));
      events.close();
      exits.close();
      crashEvents.close();
      crashExit.close();
    });

    test('journal durability barriers run pending then stable and fail closed',
        () async {
      final storage = BillingRuleStorage(directory);
      final durability = _RecordingDurability();
      final store = BillingRuleActivationJournalStore(
        storage,
        durability: durability,
      );
      final record = BillingRuleActivationJournal(
        state: BillingRuleActivationState.downloaded,
        operation: BillingRuleActivationOperation.update,
        candidateVersion: 'candidate',
        candidateSha256: 'a' * 64,
        regression: const BillingRulePersonalRegressionResult.passed(),
        lastAttemptAt: DateTime.utc(2026, 7, 17),
      );

      await store.write(record);

      expect(durability.paths, [
        endsWith('.json.pending'),
        endsWith('.json'),
      ]);

      final failedStorage = BillingRuleStorage(
          await Directory.systemTemp.createTemp('durability_failure_'));
      addTearDown(() async {
        if (await failedStorage.directory.exists()) {
          await failedStorage.directory.delete(recursive: true);
        }
      });
      final failing = _RecordingDurability(failOnCall: 1);
      await expectLater(
        BillingRuleActivationJournalStore(failedStorage, durability: failing)
            .write(record),
        throwsStateError,
      );
      expect(await failedStorage.activationJournalFile.exists(), isFalse);
      expect(await failedStorage.activationJournalPendingFile.exists(), isTrue);
    });

    test('rollback validates all gates before preserving current active',
        () async {
      await File('${directory.path}/billing_rules.active.toml')
          .writeAsString(_toml('current'));
      await File('${directory.path}/billing_rules.previous.toml')
          .writeAsString(_toml('previous'));
      var goldenCalled = false;
      var personalCalled = false;
      final service = _service(
        directory,
        _toml('unused'),
        smokeTest: (_) async => false,
        upgradeEvaluation: (_) async {
          goldenCalled = true;
          return true;
        },
        personalRegression: (_) async {
          personalCalled = true;
          return const BillingRulePersonalRegressionResult.passed();
        },
      );

      final result = await service.rollback();

      expect(result.status, BillingRuleUpdateStatus.smokeTestFailed);
      expect(goldenCalled, isFalse);
      expect(personalCalled, isFalse);
      expect(
        await File('${directory.path}/billing_rules.active.toml')
            .readAsString(),
        contains('rulesVersion = "current"'),
      );
    });

    test('rollback rejects previous changed after validation', () async {
      final active = File('${directory.path}/billing_rules.active.toml');
      final previous = File('${directory.path}/billing_rules.previous.toml');
      await active.writeAsString(_toml('current'));
      await previous.writeAsString(_toml('previous'));
      final service = _service(
        directory,
        _toml('unused'),
        beforeRollbackAtomicSwitch: () async {
          await previous.writeAsString(_toml('tampered'), flush: true);
        },
      );

      final result = await service.rollback();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.readAsString(), contains('rulesVersion = "current"'));
    });

    test('first activation reconciliation failure restores built-in fallback',
        () async {
      final candidate = _toml('candidate');
      final interrupted = _service(
        directory,
        candidate,
        afterActivationStatePersisted: (state) {
          if (state == BillingRuleActivationState.activeSwitched) {
            throw const BillingRuleActivationInterruption();
          }
        },
      );
      await expectLater(interrupted.checkForUpdate(),
          throwsA(isA<BillingRuleActivationInterruption>()));
      final restarted = _service(
        directory,
        candidate,
        personalReconciler: (_, __) async => throw StateError('db failed'),
        personalReconciliationVerifier: (_, __) async => false,
      );

      final result = await restarted.reconcileInterruptedActivation();

      expect(result.status, BillingRuleUpdateStatus.recovered);
      expect(await File('${directory.path}/billing_rules.active.toml').exists(),
          isFalse);
      expect(
        directory
            .listSync()
            .whereType<File>()
            .any((file) => file.path.contains('.reconcile-failed.')),
        isTrue,
      );
    });

    test('damaged switched candidate restores hash-proven previous snapshot',
        () async {
      final active = File('${directory.path}/billing_rules.active.toml');
      await active.writeAsString(_toml('old'));
      final interrupted = _service(
        directory,
        _toml('candidate'),
        afterActivationStatePersisted: (state) {
          if (state == BillingRuleActivationState.activeSwitched) {
            throw const BillingRuleActivationInterruption();
          }
        },
      );
      await expectLater(interrupted.checkForUpdate(),
          throwsA(isA<BillingRuleActivationInterruption>()));
      await active.writeAsString('damaged', flush: true);

      final result = await _service(directory, _toml('candidate'))
          .reconcileInterruptedActivation();

      expect(result.status, BillingRuleUpdateStatus.recovered);
      expect(await active.readAsString(), contains('rulesVersion = "old"'));
    });

    test('damaged previous is quarantined and never restored', () async {
      final active = File('${directory.path}/billing_rules.active.toml');
      final previous = File('${directory.path}/billing_rules.previous.toml');
      await active.writeAsString(_toml('old'));
      final interrupted = _service(
        directory,
        _toml('candidate'),
        afterActivationStatePersisted: (state) {
          if (state == BillingRuleActivationState.activeSwitched) {
            throw const BillingRuleActivationInterruption();
          }
        },
      );
      await expectLater(interrupted.checkForUpdate(),
          throwsA(isA<BillingRuleActivationInterruption>()));
      await previous.writeAsString('damaged', flush: true);

      final result = await _service(
        directory,
        _toml('candidate'),
        personalReconciler: (_, __) async => throw StateError('db failed'),
        personalReconciliationVerifier: (_, __) async => false,
      ).reconcileInterruptedActivation();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.exists(), isFalse);
      expect(await previous.exists(), isFalse);
      expect(
        directory
            .listSync()
            .whereType<File>()
            .any((file) => file.path.contains('.damaged-previous.')),
        isTrue,
      );
    });

    test('diagnostics reports verified disk snapshots instead of journal hints',
        () async {
      final active = File('${directory.path}/billing_rules.active.toml');
      final previous = File('${directory.path}/billing_rules.previous.toml');
      await active.writeAsString(_toml('old'));
      final service = _service(directory, _toml('candidate'));
      expect((await service.checkForUpdate()).status,
          BillingRuleUpdateStatus.activated);
      await previous.writeAsString('damaged', flush: true);

      final diagnostics = await service.activationDiagnostics();

      expect(diagnostics?.activeVersion, 'candidate');
      expect(diagnostics?.previousVersion, isNull);
      expect(diagnostics?.diskStateVerified, isFalse);
    });

    test('candidate tampered by pre-switch hook is quarantined', () async {
      final active = File('${directory.path}/billing_rules.active.toml');
      await active.writeAsString(_toml('old'));
      final service = _service(
        directory,
        _toml('candidate'),
        beforeAtomicSwitch: () =>
            File('${directory.path}/billing_rules.pending.toml')
                .writeAsStringSync(_toml('tampered'), flush: true),
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.failed);
      expect(await active.readAsString(), contains('rulesVersion = "old"'));
      expect(
          directory
              .listSync()
              .whereType<File>()
              .any((file) => file.path.contains('.candidate-tampered.')),
          isTrue);
    });

    test('SQLite commit then Future error is verifier-completed', () async {
      final database = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement(
          'CREATE TABLE recovery_marker(id INTEGER PRIMARY KEY)');
      final service = _service(
        directory,
        _toml('candidate'),
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.passed(),
        personalReconciler: (_, __) async {
          await database.transaction(() => database.customStatement(
              'INSERT OR IGNORE INTO recovery_marker(id) VALUES (1)'));
          throw StateError('future failed after commit');
        },
        personalReconciliationVerifier: (_, __) async =>
            (await database
                    .customSelect(
                        'SELECT COUNT(*) AS count FROM recovery_marker')
                    .getSingle())
                .read<int>('count') ==
            1,
      );

      final result = await service.checkForUpdate();

      expect(result.status, BillingRuleUpdateStatus.activated);
      expect(
          await File('${directory.path}/billing_rules.active.toml')
              .readAsString(),
          contains('rulesVersion = "candidate"'));
    });

    test('rollback DB commit then Future error is verifier-completed',
        () async {
      final database = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement(
          'CREATE TABLE rollback_marker(id INTEGER PRIMARY KEY)');
      final active = File('${directory.path}/billing_rules.active.toml');
      await active.writeAsString(_toml('current'));
      await File('${directory.path}/billing_rules.previous.toml')
          .writeAsString(_toml('previous'));
      final service = _service(
        directory,
        _toml('unused'),
        personalRegression: (_) async =>
            const BillingRulePersonalRegressionResult.passed(),
        personalReconciler: (_, __) async {
          await database.transaction(() => database.customStatement(
              'INSERT OR IGNORE INTO rollback_marker(id) VALUES (1)'));
          throw StateError('future failed after commit');
        },
        personalReconciliationVerifier: (_, __) async =>
            (await database
                    .customSelect(
                        'SELECT COUNT(*) AS count FROM rollback_marker')
                    .getSingle())
                .read<int>('count') ==
            1,
      );

      final result = await service.rollback();

      expect(result.status, BillingRuleUpdateStatus.rolledBack);
      expect(
          await active.readAsString(), contains('rulesVersion = "previous"'));
    });

    for (final interruptedState in BillingRuleActivationState.values) {
      test('rollback recovers after ${interruptedState.name}', () async {
        final active = File('${directory.path}/billing_rules.active.toml');
        final previous = File('${directory.path}/billing_rules.previous.toml');
        await active.writeAsString(_toml('current'));
        await previous.writeAsString(_toml('previous'));
        var reconciliations = 0;
        final interrupted = _service(
          directory,
          _toml('unused'),
          personalReconciler: (_, __) async => reconciliations++,
          afterActivationStatePersisted: (state) {
            if (state == interruptedState) {
              throw const BillingRuleActivationInterruption();
            }
          },
        );

        await expectLater(interrupted.rollback(),
            throwsA(isA<BillingRuleActivationInterruption>()));
        final restarted = _service(
          directory,
          _toml('unused'),
          personalReconciler: (_, __) async => reconciliations++,
        );
        expect((await restarted.reconcileInterruptedActivation()).status,
            BillingRuleUpdateStatus.recovered);
        expect((await restarted.reconcileInterruptedActivation()).status,
            BillingRuleUpdateStatus.recovered);

        final rollbackCompleted = interruptedState.index >=
            BillingRuleActivationState.activeSwitched.index;
        expect(
            await active.readAsString(),
            contains(
                'rulesVersion = "${rollbackCompleted ? 'previous' : 'current'}"'));
        expect(reconciliations, rollbackCompleted ? 1 : 0);
        if (rollbackCompleted) {
          expect(await previous.readAsString(),
              contains('rulesVersion = "current"'));
        }
      });
    }
  });
}

BillingRuleUpdateService _service(
  Directory directory,
  String candidate, {
  BillingRulePersonalRuleReconciler? personalReconciler,
  void Function(BillingRuleActivationState state)?
      afterActivationStatePersisted,
  BillingRuleSmokeTest? smokeTest,
  BillingRuleUpgradeEvaluation? upgradeEvaluation,
  BillingRulePersonalRegression? personalRegression,
  Future<void> Function()? beforeRollbackAtomicSwitch,
  BillingRulePersonalReconciliationVerifier? personalReconciliationVerifier,
  void Function()? beforeAtomicSwitch,
}) {
  return BillingRuleUpdateService(
    storageDirectory: directory,
    configuration: BillingRuleUpdateConfiguration.fromValues(
      manifestUrl: 'https://rules.test/manifest.json',
      currentAppVersion: '1.0.0',
    ),
    manifestLoader: (_) async => jsonEncode({
      'latest': {
        'schemaVersion': 1,
        'rulesVersion': 'candidate',
        'minAppVersion': '0.0.1',
        'url': 'https://rules.test/candidate.toml',
        'sha256': sha256.convert(utf8.encode(candidate)).toString(),
      },
    }),
    rulePackageDownloader: (_) async => candidate,
    smokeTest: smokeTest ?? (_) async => true,
    upgradeEvaluation: upgradeEvaluation ?? (_) async => true,
    personalRegression: personalRegression ??
        (_) async => const BillingRulePersonalRegressionResult.passed(
              expectedPersonalRulesVersion: 1,
              equivalentPersonalRuleIds: ['personal-1'],
            ),
    personalRuleReconciler: personalReconciler,
    personalRuleReconciliationVerifier: personalReconciliationVerifier,
    beforeAtomicSwitch: beforeAtomicSwitch,
    personalRuleArchiver: (_) async {},
    afterActivationStatePersisted: afterActivationStatePersisted,
    beforeRollbackAtomicSwitch: beforeRollbackAtomicSwitch,
  );
}

String _toml(String version) => '''
schemaVersion = 1
rulesVersion = "$version"

[[templates]]
id = "template_$version"
enabled = true
priority = 1

[[templates.extract]]
field = "note"
type = "constant"
value = "$version"
''';

Future<void> _holdStorageLock(List<Object?> arguments) async {
  final directory = Directory(arguments[0]! as String);
  final label = arguments[1]! as String;
  final events = arguments[2]! as SendPort;
  final holdMilliseconds = arguments[3]! as int;
  await BillingRuleStorage(directory).runExclusive(() async {
    events.send([label]);
    if (holdMilliseconds < 0) {
      await Completer<void>().future;
    } else if (holdMilliseconds > 0) {
      await Future<void>.delayed(Duration(milliseconds: holdMilliseconds));
    }
  });
}

class _RecordingDurability implements BillingRuleDurability {
  final int? failOnCall;
  final List<String> paths = [];

  _RecordingDurability({this.failOnCall});

  @override
  Future<void> syncFileAndParent(File file) async {
    paths.add(file.path);
    if (paths.length == failOnCall) throw StateError('fsync failed');
  }
}
