import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/billing_job_repository.dart';
import 'package:beecount/services/billing/billing_notification_mapper.dart';

BillingJob _fakeJob({
  String stage = BillingJobStage.received,
  String status = BillingJobStatus.pending,
  bool attachmentDone = false,
}) {
  return BillingJob(
    id: 1,
    kind: 'image_share',
    status: status,
    stage: stage,
    imagePath: '/tmp/test.png',
    attemptCount: 0,
    attachmentDone: attachmentDone,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('BillingNotificationMapper', () {
    late BillingNotificationMapper mapper;

    setUp(() {
      mapper = BillingNotificationMapper();
    });

    test('TC-62: received stage shows 正在识别账单', () {
      final job = _fakeJob(stage: BillingJobStage.received);
      final result = mapper.map(job);
      expect(result.title, '正在识别账单');
    });

    test('TC-63: ocr_done stage shows 正在识别账单', () {
      final job = _fakeJob(stage: BillingJobStage.ocrDone);
      final result = mapper.map(job);
      expect(result.title, '正在识别账单');
    });

    test('TC-64: transaction_created stage shows 正在补全账单信息', () {
      final job = _fakeJob(stage: BillingJobStage.transactionCreated);
      final result = mapper.map(job);
      expect(result.title, '正在补全账单信息');
    });

    test('TC-65: ai_done + attachment_done shows 记账完成', () {
      final job = _fakeJob(
        stage: BillingJobStage.aiDone,
        attachmentDone: true,
      );
      final result = mapper.map(job);
      expect(result.title, '记账完成');
      expect(result.body, '账单已成功记录');
    });

    test('TC-66: ai_done + attachment_pending shows 记账已创建附件稍后保存', () {
      final job = _fakeJob(
        stage: BillingJobStage.aiDone,
        attachmentDone: false,
      );
      final result = mapper.map(job);
      expect(result.title, '记账已创建');
      expect(result.body, '附件稍后保存');
    });

    test('TC-67: timeout at any stage shows 记账已创建剩余信息稍后补全', () {
      final job = _fakeJob(status: BillingJobStatus.retryableFailed);
      final result = mapper.map(job);
      expect(result.title, '记账已创建');
      expect(result.body, '剩余信息稍后补全');
    });

    test('TC-68: failed status shows 部分信息待补全', () {
      final job = _fakeJob(status: BillingJobStatus.failed);
      final result = mapper.map(job);
      expect(result.title, '部分信息待补全');
      expect(result.body, '打开 App 后继续');
    });

    test('TC-69: notification content is non-empty for any valid job', () {
      final jobs = [
        _fakeJob(stage: BillingJobStage.received),
        _fakeJob(stage: BillingJobStage.ocrDone),
        _fakeJob(stage: BillingJobStage.transactionCreated),
        _fakeJob(stage: BillingJobStage.aiDone, attachmentDone: true),
        _fakeJob(stage: BillingJobStage.aiDone, attachmentDone: false),
        _fakeJob(status: BillingJobStatus.retryableFailed),
        _fakeJob(status: BillingJobStatus.failed),
      ];
      for (final job in jobs) {
        final result = mapper.map(job);
        expect(result.title, isNotEmpty);
        expect(result.body, isNotEmpty);
      }
    });
  });
}
