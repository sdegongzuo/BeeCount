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

### Tracer Task 1：统一生产运行时公共规则仓库（已完成）

- [x] 在 application documents 的 `rules` 目录建立唯一
  `BillingRuleStorage`，统一声明 active、previous、pending 与原子切换临时路径。
- [x] OCR、BillingJob、个人规则回归和两条同步组装链共同使用进程内唯一的
  `RuntimeBillingRuleRepository`，生产代码不再裸创建无活动路径的 TOML 仓库。
- [x] 活动公共规则快照常驻内存；更新激活或回滚后显式失效缓存，下一张图片
  与新建服务实例立即读取新快照，不为每次识别重复读取磁盘。
- [x] 进程重启重新读取 active；active 缺失或损坏时依次回退 previous 和内置
  规则，保证旧安全快照仍可用。
- [x] 集成测试覆盖同一服务立即生效、新仓库模拟重启、损坏安全回退，以及
  BillingJob 生产规则组装链。

验证：

```text
flutter test runtime/repository/update/active integration：34 tests passed
flutter analyze 本步涉及文件：No issues found
```

以下下载、调度、诊断与完整更新状态机仍由后续 tracer task 完成。

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
