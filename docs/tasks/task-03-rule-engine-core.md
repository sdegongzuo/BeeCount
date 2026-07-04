# 任务 03：规则引擎核心

## 目标

实现模板匹配、字段提取、解析器执行、置信度计算和 trace 输出。

## 依赖

- 依赖：`docs/tasks/task-00-contracts.md`
- Task 02 完成前，可以先使用内存中的规则集进行开发。

## 主要文件

- Create: `lib/services/billing/rules/billing_rule_engine_impl.dart`
- Create: `lib/services/billing/rules/billing_rule_extractors.dart`
- Create: `lib/services/billing/rules/billing_rule_parsers.dart`
- Test: `test/services/billing/rules/billing_rule_engine_test.dart`

## 必须支持的提取器

- `constant`
- `regex`
- `labelNextLine`
- `labelPreviousLine`
- `betweenLabels`
- `nearKeyword`

## 必须支持的解析器

- 金额
- 中文日期时间
- ISO 日期时间
- 正则分组
- 原始字符串

## 步骤

1. 添加按来源包名和关键词匹配模板的测试。
2. 为每种 extractor 添加测试。
3. 添加中文日期时间和金额解析测试。
4. 添加测试证明 `details.transaction_no` 会写入嵌套 details 输出。
5. 为每个提取字段实现字段证据和置信度输出。
6. 实现确定性的模板优先级排序。
7. 运行 `flutter test test/services/billing/rules/billing_rule_engine_test.dart`。
8. 运行 `flutter analyze`。

## 完成标准

- 引擎能输出 `BillingRuleResult` 和 `BillingRuleTrace`。
- 每个提取字段都有证据、提取器类型和置信度。
- 规则执行不涉及任何 AI 调用。

## 并行说明

Task 00 完成后，可与 Task 01、Task 02、Task 04 并行执行。
