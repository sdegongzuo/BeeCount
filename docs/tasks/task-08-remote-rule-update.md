# 任务 08：远程规则更新

## 目标

添加远程 TOML 规则包更新、校验、激活和回滚能力。

## 依赖

- 依赖：`docs/tasks/task-02-toml-rule-repository.md`
- 依赖：`docs/tasks/task-07-rule-eval-cli.md`

## 主要文件

- Create: `lib/services/billing/rules/billing_rule_update_service.dart`
- Create: `lib/services/billing/rules/billing_rule_manifest.dart`
- Modify: settings page only if exposing diagnostics in UI.
- Test: `test/services/billing/rules/billing_rule_update_service_test.dart`

## 步骤

1. 添加 manifest 解析测试，覆盖 `latest.schemaVersion`、`rulesVersion`、`minAppVersion`、`url` 和 `sha256`。
2. 添加 hash 不匹配、未知 schema version、无效 TOML、smoke test 失败和回滚测试。
3. 实现启动时或每日更新检查，更新失败时不得影响当前激活规则。
4. 下载 TOML 规则包，并在解析前校验 sha256。
5. 校验 TOML 结构、字段路径、extractor/parser 白名单和正则可编译性。
6. 激活前运行 smoke test。
7. 在 application documents 下保存当前激活规则和上一版规则。
8. 运行 `flutter test test/services/billing/rules/billing_rule_update_service_test.dart`。
9. 运行 `flutter analyze`。

## 完成标准

- 远程更新失败不会破坏内置规则。
- 上一版激活规则会被保留用于回滚。
- 规则版本和更新状态可在诊断区展示。

## 并行说明

MVP 后执行。不要在规则评测 CLI 完成前执行。
