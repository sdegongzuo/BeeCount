# Issue #7 Android C2 验收报告

> 本报告由实际执行 `classification` 场景的安全运行器后填写。静态检查、单测、
> analyze 或 APK 构建不替代下面的真机结论。

## 运行身份

- 执行时间：`2026-07-17 13:36–13:42 +08:00`
- 设备序列号：`DEVICE_SERIAL`
- fixture ID：`issue7-classification-20260717-final`
- Git commit：`df5ec8d52564`
- 执行命令：

  ```powershell
  rtk powershell -ExecutionPolicy Bypass -File scripts\run_share_billing_c2.ps1 `
    -DeviceId DEVICE_SERIAL `
    -FixtureId issue7-classification-20260717-final `
    -Scenario classification `
    -UserConfirmedUnlocked
  ```

## 数据安全证据

- 测试前设备状态：`device / boot_completed=1 / 已解锁`
- 测试前用户数据哨兵 SHA-256：`d02f162f7ee4296fc01d58c17aedddf5bafbb030f8a893a51bafe8f3b38c3695`
- 独立 SQLite：`beecount_share_c2_issue7-classification-20260717-final.sqlite`
- 独立附件目录：`beecount_share_c2_issue7-classification-20260717-final_attachments`
- production 恢复 APK 绝对路径：`D:\workspace\BeeCount\.codex_tmp\c2-recovery\issue7-classification-20260717-final-20260717T053639976Z-18836a10fab041bca66d0274dc954fe7\app-dev-debug-main.apk`
- production 恢复 APK SHA-256：`43e67ecfb34ba34d7b12aa262a5b670a1156f5a005542495ba95bd2ff2c3f668`
- bundle 原字节恢复：`通过（image-eval 标记复核通过）`
- `adb install -r` production 恢复：`通过`
- production MainActivity 启动：`通过`
- 测试后用户数据哨兵：`哈希逐字一致`

## 业务闭环证据

### 第一张图片

- 通过真实 Android `ACTION_SEND`：`通过`
- Activity → ForegroundService → production coordinator：`通过`
- 金额/时间：`18.50 / 2026-07-17 12:34:56`
- 商户证据：`极光测试实验室`
- 初始分类和状态：`其他 / needsClassification=true`
- production `PendingTransactionClassificationPage` 自动打开：`通过`
- 用户选择：`餐饮 / 记住到当前账本`
- 确认结果：`needsClassification=false`
- 个人分类规则：`match_text=极光测试实验室；category_sync_id 与餐饮分类的非空稳定标识一致；ledger_id 与当前交易账本一致`

### 第二张相似图片

- 通过真实 Android `ACTION_SEND`：`通过`
- 金额/时间：`29.90 / 2026-07-17 13:45:06`
- 命中当前账本个人规则：`通过`
- 最终分类：`餐饮`
- 最终状态：`needsClassification=false`
- 待分类页面未再次打开：`通过`

## 自动化结果

- Patrol `classification` 场景：`通过，1/1，业务用例 10s`
- Kotlin debug/release 注册边界测试：`通过（ShareBillingC2ChannelRegistrationTest + ShareBillingC2RuntimeCorrelationTest）`
- Dart 确定性分类、摘要/备注、个人规则、补正页与 C2 contract 集中回归：`通过`
- focused `flutter analyze`：`通过`
- Android debug 构建：`通过（安全 runner 两次构建）`
- Android release APK：`未单独构建；不是 #7 验收项，release 下 C2 通道关闭由 Kotlin 边界测试验证`

## 结论

- 本地验证：`完成`
- 真机安全闭环：`完成`
- 验证分层：`真机 C2 验证 ACTION_SEND、OCR、production 页面回调、持久化与未来图片；412×915 widget 测试验证真实 tap 到页面回调`
- 遗留 concern：`无`
- Issue #7 是否可关闭：`是`
