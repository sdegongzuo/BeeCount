# Issue #6 Android 真机 C2 验收记录

## 结论

Issue #6 的 Android 分享入口闭环已在真机通过。测试覆盖可靠账单快速创建、不可靠账单进入待确认、仅本次不生成个人规则、明确记住后启用个人提取规则，以及下一张相似图片立即使用该规则且仍对缺失时间保持待确认。

## 运行信息

- 日期：2026-07-17
- 设备：`DEVICE_SERIAL`
- fixture：`issue6-confirm-20260717-h`
- 场景：`patrol_test/share_billing_confirmation_lifecycle_test.dart`
- 结果：1/1 通过
- runner 总耗时：351.6 秒
- 安装策略：Patrol `--no-uninstall`，结束后使用 `adb install -r` 覆盖恢复生产 APK

## 验收路径

1. 通过真实 Android `ACTION_SEND` 发送关键字段可靠的账单图片，验证 Billing Job 成功、交易金额和时间正确，并保留可解码图片附件。
2. 发送金额存在多个候选、时间缺失的图片，验证只生成 `awaitingConfirmation`，不创建正式交易；待确认页预填 OCR 文本、金额候选并展示图片。
3. 在真实待确认页面修正金额和时间并选择“仅本次”，验证交易创建成功且个人规则修订数不变。
4. 再次进入待确认页面并明确勾选“记住提取修正”，验证页面显示“个人规则已启用”且产生新的不可变个人规则修订。
5. 发送下一张相似图片，验证个人规则立即命中并提取修正金额；由于图片仍缺少时间，流程继续保持待确认且不误建交易。

## 用户数据安全与恢复

- 测试前后数据哨兵 SHA-256 均为 `d02f162f7ee4296fc01d58c17aedddf5bafbb030f8a893a51bafe8f3b38c3695`。
- 未执行 uninstall、`pm clear`、`flutter clean` 或设备测试数据清理。
- 原 Patrol bundle 已按字节恢复。
- 生产入口 APK 已覆盖安装并成功启动 MainActivity。
- 恢复 APK：`D:\workspace\BeeCount\.codex_tmp\c2-recovery\issue6-confirm-20260717-h-20260717T003714636Z-8befea67ee284d09a30a8a9b3a6e6f98\app-dev-debug-main.apk`
- 恢复 APK SHA-256：`2442d79123fbdaf384ce7b72caacc79d4472be24b8dfc9d34698331c32593958`

## 关联自动化

- `test/services/billing/pending_bill_confirmation_service_test.dart`
- `test/pages/billing/pending_bill_confirmation_page_test.dart`
- `test/services/platform/share_billing_c2_container_test.dart`
- `test/services/platform/share_billing_c2_fixture_test.dart`
- `test/services/billing/share_billing_c2_fixture_contract_test.dart`
- `test/scripts/run_share_billing_c2_script_contract_test.dart`
