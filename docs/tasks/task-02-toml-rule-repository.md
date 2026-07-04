# 任务 02：TOML 规则仓库

## 目标

加载、解析并校验内置和本地 TOML 记账规则包。

## 依赖

- 依赖：`docs/tasks/task-00-contracts.md`

## 主要文件

- Create: `assets/rules/billing_rules.toml`
- Create: `lib/services/billing/rules/billing_rule_repository.dart`
- Create: `test/services/billing/rules/billing_rule_repository_test.dart`
- Modify: `pubspec.yaml` only if a TOML parser package is required.

## 范围

本任务不执行规则，只负责加载和校验规则集。

## TOML 校验要求

规则仓库必须校验：

- `schemaVersion`
- `rulesVersion`
- 模板 ID 唯一性
- 字符串字段路径，例如 `paymentChannel` 和 `details.transaction_no`
- extractor 类型白名单
- parser 白名单
- 正则表达式可编译性

## 步骤

1. 添加微信支付详情模板的 TOML fixture。
2. 添加加载内置 TOML asset 的测试。
3. 添加无效 schema version、重复规则 ID、无效字段路径、未知 extractor、未知 parser、无效正则的测试。
4. 实现 `BillingRuleRepository`，支持内置规则、当前本地激活规则、上一版本地规则和调试覆盖规则位置。
5. 确保本地激活规则无效时回退到内置规则。
6. 运行 `flutter test test/services/billing/rules/billing_rule_repository_test.dart`。
7. 运行 `flutter analyze`。

## 完成标准

- 内置 TOML 规则可以加载为 `BillingRuleSet`。
- 无效规则不会替换当前激活规则。
- 测试直接覆盖各种校验失败场景。

## 并行说明

Task 00 完成后，可与 Task 01、Task 03、Task 04 并行执行。
