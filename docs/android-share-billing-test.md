# Android 分享账单真机测试方法

## 推荐方式：写入 pending payload 后启动 MainActivity

`ShareBillingForegroundService` 是 `exported=false`，不能直接从 `adb shell am start-foreground-service` 启动。`ACTION_SEND image/*` 的 `am start` 也可能缺少真实分享器提供的 URI 授权/ClipData，导致只启动 `ShareBillingActivity`，但没有进入 OCR 流程。

稳定的真机回归方式是模拟前台服务已经完成图片复制后的兜底路径：把 payload 写入 app 私有 `SharedPreferences`，再启动 `MainActivity`。Flutter 启动后会调用 `getPendingShareBillingPayload` 并处理图片。

示例 PowerShell：

```powershell
$adb = 'D:\app\Android\sdk\platform-tools\adb.exe'
$serial = 'DEVICE_SERIAL'
$pkg = 'com.tntlikely.beecount.dev.debug'
$imagePath = '/data/data/com.tntlikely.beecount.dev.debug/cache/beecount_fixture.jpg'

$json = '{
  "path":"'+$imagePath+'",
  "cacheImagePath":"'+$imagePath+'",
  "originalUri":"content://media/external/images/media/1000000001",
  "mimeType":"image/jpeg",
  "receivedAtMillis":9000000001000,
  "dateTakenMillis":9000000000000,
  "screenshotTimeMillis":9000000000000,
  "sourcePaymentChannel":"支付宝",
  "sourceConfidence":0.9,
  "sourceMethod":"test_pending_payload"
}' -replace "`r?`n\\s*", ''

$xml = '<?xml version="1.0" encoding="utf-8" standalone="yes" ?><map><string name="pending_payload">'+[System.Security.SecurityElement]::Escape($json)+'</string></map>'
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($xml))

& $adb -s $serial logcat -c
& $adb -s $serial shell am force-stop $pkg
& $adb -s $serial shell "run-as $pkg sh -c 'mkdir -p shared_prefs && echo $b64 | base64 -d > shared_prefs/share_billing_payloads.xml'"
& $adb -s $serial shell am start -n "$pkg/com.tntlikely.beecount.MainActivity"
```

关键成功日志：

```text
[ImageShare] 发现待处理分享图片: ...
[OCR] [快速规则] accepted=true ...
[BillCreation] [自动记账] 成功 | ID:...
[AiAsyncEnhance] 视觉规则审计结束 | score=1.0, accepted=true
[AutoBilling] AI异步增强结束 | status=succeeded
```

## 示例验证记录

图片：`Screenshot_TEST_FIXTURE.JPG`，缓存路径：`/data/data/com.tntlikely.beecount.dev.debug/cache/beecount_fixture.jpg`。

结果：

- 交易创建成功：`ID=TEST_ID`
- 金额：`-18.46`
- 类型：支出
- 分类：咖啡
- 支付通道：支付宝
- 时间：`2026-06-18 10:24:36`
- 视觉审计：`rule_score=1.0`，`accepted=true`
- AI 异步增强：`status=succeeded`
