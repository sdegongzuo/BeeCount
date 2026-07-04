# 自动记账规则引擎升级任务总控

来源设计文档：`docs/billing_rule_engine_upgrade_plan.md`

本文档规定子任务的执行顺序、并行边界和集成约束。本次升级拆成契约任务、并行模块任务、集成任务和后续扩展任务，避免多个执行者同时修改同一批核心文件。

## 执行规则

1. 删除任何文件前必须先和用户确认。
2. 本项目默认跑 Android，不要改成 Windows 或 Web 平台启动。
3. 执行任务时不要做大范围无关重构。
4. 不允许多个执行者同时修改同一批共享集成文件。
5. 每个子任务结束前必须运行该任务文档列出的验证命令。
6. 每完成一个独立任务后优先做小粒度提交。

## 共享文件写入限制

以下文件只能由集成类任务统一修改；`android/app/src/main/AndroidManifest.xml` 允许 Task 04 作为 Android 分享入口任务修改，但 Task 05 集成时必须复核该 manifest 变更。

- `lib/services/billing/ocr_service.dart`
- `lib/services/automation/auto_billing_service.dart`
- `lib/services/billing/bill_creation_service.dart`
- `android/app/src/main/kotlin/com/tntlikely/beecount/MainActivity.kt`

并行子任务可以读取这些文件，但在集成前应优先新增独立模块、接口和测试夹具，不直接改共享集成文件。

## 任务依赖图

```text
task-00-contracts.md
  -> task-01-ocr-preprocess.md
  -> task-02-toml-rule-repository.md
  -> task-03-rule-engine-core.md
  -> task-04-android-share-foreground-service.md

task-01 + task-02 + task-03 + task-04
  -> task-05-fast-billing-integration.md

task-05-fast-billing-integration.md
  -> task-06-ai-async-enhance.md

MVP 后：
  -> task-07-rule-eval-cli.md
  -> task-08-remote-rule-update.md
  -> task-09-ai-rule-review.md
```

## 并行执行安排

### 阶段 0：契约闸门

必须最先单独执行：

- `docs/tasks/task-00-contracts.md`

该任务定义共享模型、服务接口和状态枚举。在它完成前，不应启动其他实现任务。

### 阶段 1：并行模块任务

Task 00 完成后，以下任务可以并行执行：

- `docs/tasks/task-01-ocr-preprocess.md`
- `docs/tasks/task-02-toml-rule-repository.md`
- `docs/tasks/task-03-rule-engine-core.md`
- `docs/tasks/task-04-android-share-foreground-service.md`

除非子任务明确要求，否则这些任务应避免修改共享集成文件。

### 阶段 2：MVP 集成任务

阶段 1 全部完成后执行：

- `docs/tasks/task-05-fast-billing-integration.md`
- `docs/tasks/task-06-ai-async-enhance.md`

Task 05 必须先于 Task 06 落地，因为 AI 异步补全依赖快速记账先创建出可持久化的基础交易。

### 阶段 3：MVP 后扩展能力

MVP 稳定后执行：

- `docs/tasks/task-07-rule-eval-cli.md`
- `docs/tasks/task-08-remote-rule-update.md`
- `docs/tasks/task-09-ai-rule-review.md`

Task 07 应早于 Task 08 和 Task 09，因为远程规则激活和 AI 规则评估都应依赖规则评测能力。

## MVP 完成定义

满足以下条件才算 MVP 完成：

1. Android 分享到 BeeCount 后可以接收图片、复制到 cache、通过短时前台服务处理，并在基础交易创建或失败通知后停止服务。
2. OCR 输入会先预处理，移除或遮罩状态栏干扰，并把预处理元数据写入 trace。
3. 内置 TOML 规则可以识别微信支付详情模板并提取核心字段。
4. 快速记账可以在不等待 AI 的情况下创建基础交易。
5. AI 补全在基础交易路径之后执行，并且不会覆盖高置信的金额、支付通道和交易时间。

## 推荐验证顺序

1. `flutter test test/services/billing`
2. `dart run tool/image_billing_eval.dart --format markdown`
3. `flutter analyze`
4. 使用项目默认 Android 配置，在真机或模拟器上手动验证分享流程。

如果某个命令在当前任务中不适用，必须在任务完成说明中写明原因。
