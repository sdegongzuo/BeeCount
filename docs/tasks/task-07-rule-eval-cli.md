# 任务 07：规则评测 CLI

## 目标

新增本地 CLI，用于在不运行完整 App 的情况下，用 golden OCR 样本评测 TOML 规则变更。

## 依赖

- 依赖：`docs/tasks/task-02-toml-rule-repository.md`
- 依赖：`docs/tasks/task-03-rule-engine-core.md`

## 主要文件

- Create: `tool/rule_eval.dart`
- Create: `tool/rule_eval/samples/wechat_payment_detail_001.json`
- Create: `tool/rule_eval/expected/wechat_payment_detail_001.expected.json`
- Test: `test/services/billing/rules/rule_eval_test.dart`

## 步骤

1. 定义样本 JSON 格式，包含 `id`、`sourcePackage`、`ocrText` 和 `expected`。
2. 添加微信样本，覆盖金额、时间、支付通道、商户全称和支付方式。
3. 实现 CLI，支持加载当前激活规则或指定 TOML 规则文件。
4. 输出模板命中率、字段准确率、误命中、提取耗时和字段 diff。
5. 添加通过和失败报告渲染的测试。
6. 运行 `dart run tool/rule_eval.dart`。
7. 运行 `flutter test test/services/billing/rules/rule_eval_test.dart`。
8. 运行 `flutter analyze`。

## 完成标准

- 不启动 Flutter UI 也能评测规则变更。
- 失败输出能标明样本 ID、字段名、期望值和实际值。
- 该 CLI 可用于远程规则激活前的 smoke test。

## 并行说明

规则仓库和规则引擎稳定后执行。该任务应早于远程更新任务。
