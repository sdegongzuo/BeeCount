# Issue #7 Android C2 验收报告

> 本报告只能由实际执行 `classification` 场景的安全运行器后填写。静态检查、单测、
> analyze 或 APK 构建不能替代真机结论。

## 运行身份

- 执行时间：`待填写`
- 设备序列号：`待填写`
- fixture ID：`待填写（每次运行唯一）`
- Git commit：`待填写`
- 执行命令：

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_share_billing_c2.ps1 `
    -DeviceId <设备序列号> `
    -FixtureId <唯一fixture-id> `
    -Scenario classification `
    -UserConfirmedUnlocked
  ```

## 数据安全证据

- 测试前设备状态：`device / boot_completed=1 / 已解锁`
- 测试前用户数据哨兵 SHA-256：`待填写`
- 独立 SQLite：`beecount_share_c2_<fixture>.sqlite`
- 独立附件目录：`beecount_share_c2_<fixture>_attachments`
- production 恢复 APK 绝对路径：`待填写`
- production 恢复 APK SHA-256：`待填写`
- bundle 原字节恢复：`通过 / 失败（原因）`
- `adb install -r` production 恢复：`通过 / 失败（原因）`
- production MainActivity 启动：`通过 / 失败（原因）`
- 测试后用户数据哨兵：`逐字一致 / 不一致（立即停止排查）`

## 业务闭环证据

### 第一张图片

- 通过真实 Android `ACTION_SEND`：`通过 / 失败`
- Activity → ForegroundService → production coordinator：`通过 / 失败`
- 金额/时间：`18.50 / 2026-07-17 12:34:56`
- 商户证据：`极光测试实验室`
- 初始分类和状态：`其他 / needsClassification=true`
- production `PendingTransactionClassificationPage` 自动打开：`通过 / 失败`
- 用户选择：`餐饮 / 记住到当前账本`
- 确认结果：`needsClassification=false`
- 个人分类规则：`match_text、category_sync_id、ledger_id 待填写`

### 第二张相似图片

- 通过真实 Android `ACTION_SEND`：`通过 / 失败`
- 金额/时间：`29.90 / 2026-07-17 13:45:06`
- 命中当前账本个人规则：`通过 / 失败`
- 最终分类：`餐饮`
- 最终状态：`needsClassification=false`
- 待分类页面未再次打开：`通过 / 失败`

## 自动化结果

- Patrol `classification` 场景：`通过 / 失败（原始错误）`
- Kotlin debug/release 边界测试：`通过 / 失败`
- Dart C2/runner contract tests：`通过 / 失败`
- focused `flutter analyze`：`通过 / 失败`
- Android debug/release 构建：`通过 / 失败`

## 结论

- 本地验证：`完成 / 未完成`
- 真机安全闭环：`完成 / 未完成`
- 遗留 concern：`无 / 待填写`
- Issue #7 是否可关闭：`是 / 否`
