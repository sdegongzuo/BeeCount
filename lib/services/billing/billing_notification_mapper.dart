import '../../data/db.dart';
import '../../data/repositories/billing_job_repository.dart';

class NotificationContent {
  final String title;
  final String body;

  const NotificationContent({required this.title, required this.body});
}

class BillingNotificationMapper {
  NotificationContent map(BillingJob job) {
    if (job.status == BillingJobStatus.succeeded) {
      return const NotificationContent(title: '记账完成', body: '账单已成功记录');
    }
    if (job.status == BillingJobStatus.failed) {
      return const NotificationContent(title: '部分信息待补全', body: '打开 App 后继续');
    }
    if (job.status == BillingJobStatus.retryableFailed) {
      return const NotificationContent(title: '记账已创建', body: '剩余信息稍后补全');
    }
    // In progress
    switch (job.stage) {
      case BillingJobStage.received:
      case BillingJobStage.ocrDone:
        return const NotificationContent(title: '正在识别账单', body: '请稍候...');
      case BillingJobStage.ruleDone:
      case BillingJobStage.transactionCreated:
        return const NotificationContent(title: '正在补全账单信息', body: '请稍候...');
      case BillingJobStage.aiDone:
        if (!job.attachmentDone) {
          return const NotificationContent(title: '记账已创建', body: '附件稍后保存');
        }
        return const NotificationContent(title: '记账完成', body: '账单已成功记录');
      default:
        return const NotificationContent(title: '正在处理', body: '请稍候...');
    }
  }
}
