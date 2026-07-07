# Billing Job Queue 架构

采用 `billing_jobs` 本地队列表驱动图片分享记账流程，替代原有的单次同步管道。

原有流程中，`processScreenshot` 在 Foreground Service 窗口内一次性跑完所有阶段。一旦进程被杀或网络中断，任务丢失且无法恢复。`_saveScreenshotAttachment()` 用 `unawaited()` 裸跑，进程被杀时附件静默丢失。

新设计将流程拆成 5 个幂等阶段（received → ocr_done → rule_done → transaction_created → ai_done → attachment_done），每个阶段完成后持久化进度到 `billing_jobs` 表。任何阶段超时或异常时，job 标记为 `retryable_failed`，下次 App 回到前台时自动恢复从已完成阶段继续。

关键约束：不重复创建账单（交易去重使用精确到秒的交易时间 + 金额）；关键字段（交易主体）优先完成；附件和 AI 增强可后续补齐。
