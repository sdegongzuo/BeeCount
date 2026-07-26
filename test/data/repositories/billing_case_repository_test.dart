import 'package:beecount/data/db.dart';
import 'package:beecount/data/models/billing_case.dart';
import 'package:beecount/data/repositories/billing_case_repository.dart';
import 'package:beecount/data/repositories/local/local_billing_case_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late BeeDatabase db;
  late BillingCaseRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBillingCaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getOrCreateCaseByRequestId', () {
    test('重复 requestId 只创建同一个 Case', () async {
      final first = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-1',
        sourceImagePath: '/tmp/a.png',
        ledgerId: 7,
      );
      final second = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-1',
        sourceImagePath: '/tmp/a.png',
        ledgerId: 7,
      );

      expect(second.id, first.id);
      expect(second.requestId, 'req-1');
      expect(second.state, BillingCaseState.accepted);
      expect(second.version, 1);
      expect(second.syncAllowed, isFalse);
      // 新 schema 可在全新数据库创建，且 ledger 保留。
      expect(first.ledgerId, 7);
    });

    test('onCreate 仅在新建时执行', () async {
      var created = 0;
      await repo.getOrCreateCaseByRequestId(
        requestId: 'req-2',
        sourceImagePath: '/tmp/b.png',
        onCreate: (caseId) async => created++,
      );
      await repo.getOrCreateCaseByRequestId(
        requestId: 'req-2',
        sourceImagePath: '/tmp/b.png',
        onCreate: (caseId) async => created++,
      );

      expect(created, 1);
    });

    test('findCaseByRequestId 定位 Case', () async {
      final created = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-3',
        sourceImagePath: '/tmp/c.png',
      );
      final found = await repo.findCaseByRequestId('req-3');
      expect(found!.id, created.id);
      expect(await repo.findCaseByRequestId('missing'), isNull);
    });
  });

  group('Automation Task 不变量', () {
    test('同一 Case 同一任务类型不能重复插入', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-t1',
        sourceImagePath: '/tmp/d.png',
      );
      final first = await repo.insertAutomationTaskIfAbsent(
        caseId: caseRow.id,
        kind: BillingAutomationKind.recognizeImage,
      );
      final second = await repo.insertAutomationTaskIfAbsent(
        caseId: caseRow.id,
        kind: BillingAutomationKind.recognizeImage,
      );

      expect(first, isTrue);
      expect(second, isFalse);
      final tasks = await repo.findAutomationTasksByCase(caseRow.id);
      expect(tasks, hasLength(1));
      expect(tasks.single.kind, BillingAutomationKind.recognizeImage);
      expect(tasks.single.state, BillingAutomationTaskState.ready);
    });

    test('同一 Case 不同任务类型可以共存', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-t2',
        sourceImagePath: '/tmp/e.png',
      );
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.prepareAttachment);

      final tasks = await repo.findAutomationTasksByCase(caseRow.id);
      expect(tasks, hasLength(2));
    });
  });

  group('claim 与 generation fencing', () {
    test('claim 增加 generation 并设置 owner/lease', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-c1',
        sourceImagePath: '/tmp/f.png',
      );
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);

      final lease = await repo.claimAutomationTask(
        workerIdentity: 'worker-A',
        leaseDuration: const Duration(minutes: 1),
      );

      expect(lease, isNotNull);
      expect(lease!.leaseOwner, 'worker-A');
      expect(lease.leaseGeneration, greaterThan(0));
      final task = (await repo.findAutomationTasksByCase(caseRow.id)).single;
      expect(task.state, BillingAutomationTaskState.running);
      expect(task.leaseGeneration, lease.leaseGeneration);
    });

    test('过期 generation 永远不能提交副作用', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-c2',
        sourceImagePath: '/tmp/g.png',
      );
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);

      final lease1 = await repo.claimAutomationTask(
        workerIdentity: 'worker-A',
        leaseDuration: const Duration(seconds: 1),
      );
      expect(lease1, isNotNull);
      // 等待第一个 owner 的 lease 过期，第二个 owner 才能 claim（lease 未过期
      // 时不能抢占，见规格 §6.2）。Drift 默认秒精度，故等待略长于 lease。
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      final lease2 = await repo.claimAutomationTask(
        workerIdentity: 'worker-B',
        leaseDuration: const Duration(minutes: 1),
      );

      expect(lease2, isNotNull);
      expect(lease2!.leaseGeneration, greaterThan(lease1!.leaseGeneration));

      // 旧 owner 用过期 generation 提交必须失败。
      await expectLater(
        repo.runFenced(lease1!, () async => 'should-not-run'),
        throwsA(isA<BillingAutomationLeaseLost>()),
      );
      // 新 owner 用当前 generation 可以提交。
      final result = await repo.runFenced(
        lease2,
        () async => await repo.completeAutomationTask(lease2.taskId),
      );
      expect(result, isTrue);
    });

    test('lease 过期后提交失败', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-c3',
        sourceImagePath: '/tmp/h.png',
      );
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);

      final lease = await repo.claimAutomationTask(
        workerIdentity: 'worker-A',
        leaseDuration: const Duration(milliseconds: 1),
      );
      expect(lease, isNotNull);
      // 等待 lease 过期。
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      await expectLater(
        repo.runFenced(lease!, () async => 'should-not-run'),
        throwsA(isA<BillingAutomationLeaseLost>()),
      );
    });

    test('两个 worker 同时 claim 只有一个成功', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-c4',
        sourceImagePath: '/tmp/i.png',
      );
      await repo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);

      final results = await Future.wait([
        repo.claimAutomationTask(
          workerIdentity: 'worker-A',
          leaseDuration: const Duration(minutes: 1),
        ),
        repo.claimAutomationTask(
          workerIdentity: 'worker-B',
          leaseDuration: const Duration(minutes: 1),
        ),
      ]);

      final claimed =
          results.where((r) => r != null).map((r) => r!.leaseOwner).toList();
      expect(claimed, hasLength(1));
    });
  });

  group('User Task 乐观并发', () {
    test('resolve 以 open + version 为条件，重复提交无副作用', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-u1',
        sourceImagePath: '/tmp/j.png',
      );
      await repo.insertUserTaskIfAbsent(
        caseId: caseRow.id,
        kind: BillingUserTaskKind.confirmBill,
      );
      final task = (await repo.findOpenUserTasksByCase(caseRow.id)).single;

      final first = await repo.resolveUserTask(
        task.id,
        expectedVersion: task.version,
        resolutionJson: '{"amount":100}',
      );
      final second = await repo.resolveUserTask(
        task.id,
        expectedVersion: task.version, // 旧 version
        resolutionJson: '{"amount":200}',
      );

      expect(first, isTrue);
      expect(second, isFalse);
      final resolved = await repo.findUserTask(task.id);
      expect(resolved!.state, BillingUserTaskState.resolved);
      expect(resolved.version, task.version + 1);
      expect(resolved.resolutionJson, '{"amount":100}');
    });

    test('cancel 以 open + version 为条件', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-u2',
        sourceImagePath: '/tmp/k.png',
      );
      await repo.insertUserTaskIfAbsent(
          caseId: caseRow.id, kind: BillingUserTaskKind.confirmBill);
      final task = (await repo.findOpenUserTasksByCase(caseRow.id)).single;

      final cancelled = await repo.cancelUserTask(
        task.id,
        expectedVersion: task.version,
      );
      expect(cancelled, isTrue);
      final after = await repo.findUserTask(task.id);
      expect(after!.state, BillingUserTaskState.cancelled);
    });

    test('已 resolved 的任务不能再 cancel', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-u3',
        sourceImagePath: '/tmp/l.png',
      );
      await repo.insertUserTaskIfAbsent(
          caseId: caseRow.id, kind: BillingUserTaskKind.confirmBill);
      final task = (await repo.findOpenUserTasksByCase(caseRow.id)).single;
      await repo.resolveUserTask(task.id, expectedVersion: task.version);

      final cancelled = await repo.cancelUserTask(
        task.id,
        expectedVersion: task.version + 1,
      );
      expect(cancelled, isFalse);
    });
  });

  group('事务回滚与组合创建', () {
    test('事务内 Case + 任务 + Outbox 一起提交', () async {
      final caseId = await repo.transaction(() async {
        final caseRow = await repo.getOrCreateCaseByRequestId(
          requestId: 'req-tx1',
          sourceImagePath: '/tmp/m.png',
        );
        await repo.insertAutomationTaskIfAbsent(
            caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);
        await repo.insertAutomationTaskIfAbsent(
            caseId: caseRow.id, kind: BillingAutomationKind.prepareAttachment);
        await repo.insertOutboxEvent(
          caseId: caseRow.id,
          eventType: BillingOutboxEventType.billingProcessing,
        );
        return caseRow.id;
      });

      final tasks = await repo.findAutomationTasksByCase(caseId);
      expect(tasks, hasLength(2));
      final pending = await repo.findPendingOutboxEvents();
      expect(pending, hasLength(1));
      expect(pending.single.eventType,
          BillingOutboxEventType.billingProcessing);
      expect(pending.single.state, BillingOutboxState.pending);
    });

    test('事务回滚不留下任何记录', () async {
      try {
        await repo.transaction(() async {
          await repo.getOrCreateCaseByRequestId(
            requestId: 'req-tx2-rollback',
            sourceImagePath: '/tmp/n.png',
          );
          throw StateError('boom');
        });
      } catch (e) {
        expect(e, isStateError);
      }

      expect(await repo.findCaseByRequestId('req-tx2-rollback'), isNull);
    });

    test('Case 状态转换推进 version', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-tx3',
        sourceImagePath: '/tmp/o.png',
      );
      final updated = await repo.updateCaseState(
        caseRow.id,
        state: BillingCaseState.automating,
        expectedVersion: caseRow.version,
      );
      expect(updated, isTrue);
      final after = (await repo.findCaseById(caseRow.id))!;
      expect(after.state, BillingCaseState.automating);
      expect(after.version, caseRow.version + 1);
      expect(after.completedAt, isNull);
    });

    test('终态 Case 设置 completedAt', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-tx4',
        sourceImagePath: '/tmp/p.png',
      );
      await repo.updateCaseState(
        caseRow.id,
        state: BillingCaseState.completed,
        expectedVersion: caseRow.version,
      );
      final after = (await repo.findCaseById(caseRow.id))!;
      expect(after.state, BillingCaseState.completed);
      expect(after.completedAt, isNotNull);
    });
  });

  group('数据库重开恢复', () {
    test('Case 与任务在数据库重开后保持一致', () async {
      final underlying = sqlite.sqlite3.openInMemory();
      final firstDb = BeeDatabase.forTesting(NativeDatabase.opened(
        underlying,
        closeUnderlyingOnClose: false,
      ));
      final firstRepo = LocalBillingCaseRepository(firstDb);
      final caseRow = await firstRepo.getOrCreateCaseByRequestId(
        requestId: 'req-reopen',
        sourceImagePath: '/tmp/q.png',
        ledgerId: 9,
      );
      await firstRepo.insertAutomationTaskIfAbsent(
          caseId: caseRow.id, kind: BillingAutomationKind.recognizeImage);
      await firstRepo.insertOutboxEvent(
        caseId: caseRow.id,
        eventType: BillingOutboxEventType.billingCreated,
      );
      await firstDb.close();

      final reopenedDb =
          BeeDatabase.forTesting(NativeDatabase.opened(underlying));
      addTearDown(reopenedDb.close);
      final reopenedRepo = LocalBillingCaseRepository(reopenedDb);

      final restored = await reopenedRepo.findCaseByRequestId('req-reopen');
      expect(restored, isNotNull);
      expect(restored!.ledgerId, 9);
      final tasks = await reopenedRepo.findAutomationTasksByCase(restored.id);
      expect(tasks, hasLength(1));
      final outbox = await reopenedRepo.findPendingOutboxEvents();
      expect(outbox, hasLength(1));
      underlying.close();
    });
  });

  group('Outbox 交付', () {
    test('markDelivered 标记事件已交付', () async {
      final caseRow = await repo.getOrCreateCaseByRequestId(
        requestId: 'req-ob1',
        sourceImagePath: '/tmp/r.png',
      );
      final id = await repo.insertOutboxEvent(
        caseId: caseRow.id,
        eventType: BillingOutboxEventType.billingCompleted,
      );
      final delivered = await repo.markOutboxDelivered(id);
      expect(delivered, isTrue);
      final pending = await repo.findPendingOutboxEvents();
      expect(pending, isEmpty);
    });
  });
}
