# 任务 06：AI 异步补全

## 目标

把 AI 增强移动到基础交易路径之后，并在快速记账完成后安全合并 AI 字段。

## 依赖

- 依赖：`docs/tasks/task-05-fast-billing-integration.md`

## 主要文件

- Modify: `lib/services/billing/ocr_service.dart`
- Modify: `lib/services/automation/auto_billing_service.dart`
- Modify: `lib/services/billing/bill_creation_service.dart`
- Modify: data repository files only if transaction update methods are missing.
- Test: `test/services/billing/ai_async_enhance_test.dart`

## 合并规则

AI 可以填充：

- note
- category
- payment method
- counterparty
- merchant full name
- acquirer
- transaction numbers
- details

AI 不得覆盖高置信字段：

- amount
- payment channel
- transaction time

## 步骤

1. 添加 AI 返回冲突金额的测试，并验证保留规则金额。
2. 添加基础交易存在后 AI 填充分组和备注的测试。
3. 添加 AI 超时和失败状态测试。
4. 如果暂不改数据库 schema，则把 `ai_enhance_status` 存入交易 details。
5. 在基础交易创建后派发 AI 补全。
6. 把允许更新的字段安全合并到现有交易。
7. 发送完成、失败或超时通知。
8. 运行 `flutter test test/services/billing/ai_async_enhance_test.dart`。
9. 运行 `flutter test test/services/billing`。
10. 运行 `flutter analyze`。

## 完成标准

- AI 失败时不会回滚基础交易。
- AI 冲突处理决策会写入日志。
- 用户仍可正常编辑交易。

## 并行说明

Task 05 完成后执行。本任务完成前负责 AI 集成相关文件。
