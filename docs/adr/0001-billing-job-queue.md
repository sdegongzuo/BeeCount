# Billing Job Queue 架构

> 状态更新（ADR-0004、Issue #2）：本文原先把 `ai_done` 写成主流程终态，
> 该约定已被 `completed` 取代。`ai_done` 只作为旧数据和过渡阶段兼容，升级到
> schema v27 时迁移为 `completed`；附件状态仍由 `attachment_done` 独立表达。

采用 `billing_jobs` 本地队列表驱动图片分享记账流程，替代原有的单次同步管道。

原有流程中，`processScreenshot` 在 Foreground Service 窗口内一次性跑完所有阶段。一旦进程被杀或网络中断，任务丢失且无法恢复。`_saveScreenshotAttachment()` 用 `unawaited()` 裸跑，进程被杀时附件静默丢失。

新设计把流程拆成可持久化的幂等阶段（received → ocr_done → rule_done → transaction_created → completed），每个阶段完成后持久化进度到 `billing_jobs` 表。`ai_done` 保留为迁移兼容值，不再是终态。附件保存（AVIF 编码）与主流程完全独立——它只依赖源图片文件，从收到图片那一刻即可并行启动，用 `attachment_done` boolean 独立追踪，不是主流程 stage。主流程成功以 `stage == completed` 表达；完整完成通知还要求 `attachment_done == true`，附件未完成时显示账单已创建、附件稍后保存。

任何阶段超时或异常时，job 标记为 `retryable_failed`，下次 App 回到前台时自动恢复从已完成阶段继续。

关键约束：
- 不重复创建账单——交易去重使用精确到秒的交易时间 + 金额
- 关键字段（交易主体）优先完成，附件和 AI 增强可后续补齐
- 去重采用双重防护：内存 `_processedPaths` 快速拦截 + `billing_jobs` 表持久化防线
- `kind` 字段先实现 `image_share`，`screenshot_monitor` 留字段备用
- `lease_until` 防止并发重复执行，最多允许 2 个 job 并发
