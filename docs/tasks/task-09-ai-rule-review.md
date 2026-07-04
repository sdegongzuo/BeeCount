# 任务 09：AI 规则评估工作流

## 目标

收集规则质量证据，生成可审核的 AI 建议，但不得自动激活 AI 生成的规则。

## 依赖

- 依赖：`docs/tasks/task-03-rule-engine-core.md`
- 依赖：`docs/tasks/task-07-rule-eval-cli.md`

## 主要文件

- Create: `lib/services/billing/rules/ai_rule_review_service.dart`
- Create: `tool/rule_eval/ai_suggestions/README.md`
- Test: `test/services/billing/rules/ai_rule_review_service_test.dart`

## 范围

本任务不得发布、激活或静默应用 AI 生成的规则。

## 步骤

1. 定义 AI 评估输入，包含来源包名、支付通道、OCR 文本、规则 trace、规则结果、AI 结果和用户最终结果。
2. 定义建议输出，包含诊断、建议字段策略、原因、风险和是否需要人工审核。
3. 添加测试，证明建议只会保存为审核产物。
4. 实现服务，从失败样本或用户编辑后的结果构建评估 payload。
5. 将 AI 建议保存到审核目录或仓库抽象中。
6. 要求建议必须人工转换为 TOML 规则。
7. 运行 `flutter test test/services/billing/rules/ai_rule_review_service_test.dart`。
8. 运行 `flutter analyze`。

## 完成标准

- AI 建议可审计。
- 建议规则永远不会自动激活。
- 建议可以关联到规则 ID、字段、证据和样本 ID。

## 并行说明

MVP 后执行。Trace 输出和规则评测稳定后再执行。
