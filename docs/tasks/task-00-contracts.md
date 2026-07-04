# 任务 00：共享契约

## 目标

定义 OCR 预处理、TOML 规则加载、规则执行、快速记账和 AI 异步补全共同使用的模型与接口。

## 依赖

无。该任务必须在其他实现任务之前执行。

## 主要文件

- Create: `lib/services/billing/rules/billing_rule_models.dart`
- Create: `lib/services/billing/rules/billing_rule_trace.dart`
- Create: `lib/services/billing/rules/billing_rule_engine.dart`
- Create: `test/services/billing/rules/billing_rule_models_test.dart`

## 必须定义的契约

定义以下模型：

- `OcrPreprocessResult`
- `BillingRuleSet`
- `BillingPaymentChannelRule`
- `BillingRuleTemplate`
- `BillingRuleMatch`
- `BillingFieldExtractorRule`
- `BillingRuleResult`
- `BillingRuleFieldResult`
- `BillingRuleFieldEvidence`
- `BillingRuleTrace`
- `AiEnhanceStatus`

定义以下接口：

- `BillingRuleRepository`
- `BillingRuleEngine`

## 步骤

1. 添加模型测试，覆盖 trace 和字段结果的 JSON/debug 序列化。
2. 添加不可变模型类，并明确所有可空字段。
3. 添加 AI 补全状态枚举解析。
4. 添加接口类，但不实现 TOML 加载和规则执行。
5. 运行 `flutter test test/services/billing/rules/billing_rule_models_test.dart`。
6. 运行 `flutter analyze`。

## 完成标准

- 共享类型名和字段名稳定。
- 后续实现任务不需要重复发明 trace 或 result 结构。
- 测试证明 trace 序列化包含规则版本、预处理元数据、字段证据和最终规则结果。

## 并行说明

该任务完成后，Task 01 到 Task 04 可以并行执行。
