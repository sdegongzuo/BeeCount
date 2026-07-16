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

### Tracer Task 3：生产黄金评测与本机个人样本回归（已完成）

- [x] 将 `tool/rule_eval/samples` 与 `tool/rule_eval/expected` 的 20 份人工真值
  随安装包发布；生产运行时读取与 CLI 相同的固定语料，不另造测试真值。
- [x] 候选公共规则逐样本对比候选、当前活动和内置规则；全部期望字段必须
  正确，金额与时间等关键字段不得相对旧安全基线降级。
- [x] `RegressionSampleStore` 和 Android 加密存储增加稳定游标分页。默认每页
  50 条、最多 100 条；Dart 处理完一页即可释放该页 OCR 明文，不再一次持有
  500 条完整 OCR。数据密钥在本机存储实例内复用，单条密文损坏会标记且使
  本次候选安全失败。
- [x] 回归支持墙钟超时和主动取消；500 条真实规则引擎循环的测试预算为 5 秒，
  同时保留个人规则生命周期原有的 1 秒门禁（本次验证 P95 38ms、最坏 40ms）。
- [x] 候选与活动个人规则行为等价时，通过 SQLite 不可变新修订移出活动快照，
  并保留归档审计；行为冲突时保留回归通过的个人安全结果，将公共版本、个人
  规则标识和中文解释追加写入 `personal_rule_public_decisions`，不删除历史。
- [x] 评测记录个人活动版本，激活后的归档/冲突写入使用 CAS 且位于公共规则
  更新的同一存储互斥区。并发变化或落库失败会让更新恢复旧公共快照。
- [x] `createProductionBillingRuleUpdateService` 默认接入真实随包黄金语料、生产
  公共规则仓库、Android 加密样本存储和 SQLite 个人规则生命周期，不再要求
  生产调用方提供“永远通过”的测试回调。

验证：

```text
focused Flutter tests：43 tests passed
flutter analyze（Task 3 涉及的 10 个 Dart 文件）：No issues found
flutter build apk --debug --flavor dev：成功（含 Kotlin 分页通道编译）
```

激活 journal、启动/每日/手动触发和诊断 UI 仍由后续 tracer task 完成。

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
