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
- [x] 同一规则目录的更新、按日检查与回滚在进程内串行执行；即使存在多个
  service 实例也不会交错覆盖 active/previous/pending 状态。
- [x] 首次激活尚无 previous 时若个人规则归档失败，撤回 active、保留 pending
  并恢复内置规则，运行时缓存同步失效。
- [x] 集成测试覆盖同一服务立即生效、新仓库模拟重启、损坏安全回退，以及
  OCR、BillingJob 和两条同步生产装配共享同一个仓库实例。

验证：

```text
flutter test runtime/repository/update/active/wiring integration：39 tests passed
flutter analyze 本步涉及文件：No issues found
```

以下下载、调度、诊断与完整更新状态机仍由后续 tracer task 完成。

### Tracer Task 2：可信配置与兼容/下载安全门（已完成）

- [x] 删除占位 manifest 默认地址；生产入口只接受显式
  `BEECOUNT_BILLING_RULE_MANIFEST_URL`，缺失、HTTP、`example.com` 等占位地址
  均安全禁用，返回中文诊断且不发起网络请求。
- [x] manifest 与 TOML 包只允许 HTTPS。规则包默认与 manifest 同源；确需
  CDN 时通过 `BEECOUNT_BILLING_RULE_TRUSTED_HOSTS` 逐 host 放行，不能由远程
  manifest 自行扩展信任边界。
- [x] 默认 HTTP 下载器关闭自动重定向，拒绝所有 3xx，并核对响应最终 URI；
  请求有整体超时，manifest 与规则包分别以流式累计字节数执行响应体上限。
- [x] 用安装包 `PackageInfo.version` 与 manifest `minAppVersion` 做严格 SemVer
  比较，包含 prerelease 数字/文本标识优先级；不兼容时不下载、不激活。
- [x] 保留 sha256、manifest schema、TOML 结构和既有评测门。
- [x] 日检状态拆分为 `lastAttemptAt` 与 `lastSuccessAt`：失败绝不写成功时间，
  仅进入默认 15 分钟短退避；成功检查才启用 24 小时间隔。旧 `checkedAt`
  只按失败尝试迁移，避免旧断网记录继续压住一天重试。

生产构建示例：

```text
--dart-define=BEECOUNT_BILLING_RULE_MANIFEST_URL=https://rules.example.org/manifest.json
--dart-define=BEECOUNT_BILLING_RULE_TRUSTED_HOSTS=cdn.example.org
```

`BEECOUNT_BILLING_RULE_SAME_ORIGIN` 默认为 `true`。关闭它时必须至少配置一个
可信规则包 host，否则整套远程更新保持禁用。flavor 可以注入上述 define，运行时
仍统一经过 `BillingRuleUpdateConfiguration` 校验。

验证：

```text
flutter test update/security/runtime focused：40 tests passed
flutter analyze 本步涉及文件：No issues found
```

激活 journal、个人样本回归的生产实现、启动/手动触发和诊断 UI 仍由后续
tracer task 完成。

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
