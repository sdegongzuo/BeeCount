# 任务 05：快速记账集成

## 目标

把 OCR 前预处理、TOML 规则加载、规则执行、trace 日志和快速交易创建接入当前记账流程。

## 依赖

- 依赖：`docs/tasks/task-01-ocr-preprocess.md`
- 依赖：`docs/tasks/task-02-toml-rule-repository.md`
- 依赖：`docs/tasks/task-03-rule-engine-core.md`
- 依赖：`docs/tasks/task-04-android-share-foreground-service.md`

## 主要文件

- Modify: `lib/services/billing/ocr_service.dart`
- Modify: `lib/services/automation/auto_billing_service.dart`
- Modify: `lib/services/billing/bill_creation_service.dart`
- Modify: `lib/services/platform/image_share_handler_service.dart` if the share service payload changes.
- Test: `test/services/billing/fast_billing_integration_test.dart`

## 范围

本任务实现不等待 AI 的基础交易创建路径。AI 异步补全放到 Task 06。

## 步骤

1. 为高置信微信支付详情 OCR 文本添加集成测试。
2. 为低置信情况添加测试：金额缺失、支付通道缺失、时间缺失。
3. 在 OCR 前接入 `OcrImagePreprocessor`。
4. 通过 `BillingRuleRepository` 加载当前激活的 `BillingRuleSet`。
5. 执行 `BillingRuleEngine` 并挂载 `BillingRuleTrace`。
6. 当金额和必要置信条件通过时创建基础交易。
7. 为低置信结果创建待确认路径或通知路径。
8. 运行 `flutter test test/services/billing`。
9. 运行 `dart run tool/image_billing_eval.dart --format markdown`。
10. 运行 `flutter analyze`。

## 完成标准

- 高置信规则结果在 OCR 成功后可以在 1-3 秒内创建交易。
- 快速路径不等待 AI。
- 日志能解释快速记账通过或拒绝原因。

## 并行说明

阶段 1 任务全部完成后执行。本任务负责共享 Dart 集成文件。
