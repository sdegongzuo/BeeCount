# 规则升级离线工具

本工具用于用一张支付截图升级 TOML 规则模板。流程只面向开发/规则升级，不进入生产分享链路。

## 前置数据

优先准备 Android OCR/AI 导出的 actual JSON：

```powershell
build\image_billing_eval\latest_actual.json
```

如果没有 actual JSON，`prepare-expected` 仍会尽量从 `tool/image_billing_golden.json` 预填，但 `ocr_text` 可能为空或不适合生成候选规则。

`prepare-expected` 会从 actual JSON 的顶层 `ocrEngine` 或 OCR trace 中保留 `ocr_engine`，用于确认当前样本的 OCR 文本来自 `rapidocr`、`mlkit` 还是其他回退链路。

如果 `prepare-expected` 输出 `ocr_engine: null`，说明当前 actual JSON 不是新导出的完整 OCR 结果，或导出时的 App 不是最新构建。此时不要用该文件判断 RapidOCR 质量，先重启 Android dev app 并重新执行“图片记账评测导出”。

可直接用 debug receiver 自检 RapidOCR 单张图：

```powershell
D:\app\Android\sdk\platform-tools\adb.exe -s <device-id> push "image\单条\微信-单条.jpg" /data/local/tmp/beecount_rapidocr_sample.jpg
D:\app\Android\sdk\platform-tools\adb.exe -s <device-id> logcat -c
D:\app\Android\sdk\platform-tools\adb.exe -s <device-id> shell am broadcast `
  -a com.tntlikely.beecount.DEBUG_RAPID_OCR `
  -n com.tntlikely.beecount.dev.debug/com.tntlikely.beecount.RapidOcrDebugReceiver `
  --es path /data/local/tmp/beecount_rapidocr_sample.jpg `
  --ei maxSideLen 1920
D:\app\Android\sdk\platform-tools\adb.exe -s <device-id> logcat -d -s RapidOcrDebugReceiver RapidOCR OCR
```

## 1. 生成待确认 expected，然后停住人工确认

```powershell
dart run tool/rule_upgrade.dart prepare `
  --image "image/单条/微信-单条.jpg" `
  --source-app "微信" `
  --case-id "wechat_pinduoduo_single"
```

输出：

```text
tool/rule_eval/upgrade_cases/wechat_pinduoduo_single.expected.json
```

人工核对 `expected`。字段固定包含：

```text
amount, type, time, note, category, account,
payment_channel, payment_method, counterparty,
merchant_full_name, acquirer, details
```

确认后把：

```json
"status": "needs_review"
```

改为：

```json
"status": "reviewed"
```

## 2. 生成候选 TOML 并验证

```powershell
dart run tool/rule_upgrade.dart verify `
  --case tool/rule_eval/upgrade_cases/wechat_pinduoduo_single.expected.json
```

输出候选和验证报告：

```text
tool/rule_eval/ai_suggestions/wechat_pinduoduo_single.candidate.toml
build/rule_upgrade/wechat_pinduoduo_single.verify.json
```

草稿阶段可临时加：

```powershell
--allow-needs-review
```

候选 TOML 默认只生成可泛化提取器：

- 金额、时间使用通用正则。
- 支付方式使用银行卡/支付方式通用正则，不写死尾号或完整卡名。
- 收单机构使用机构名称通用正则，并允许常见 OCR 纠错。
- `details.remaining_text` 使用 `remainingLines` 收集未被其他字段命中的 OCR 行，用来保留原价、优惠、交易单号、商户单号等补充信息。
- `counterparty`、`note` 不从单张图默认生成，因为这些字段通常是当前商户等样本值。

`paymentChannel` 可以作为常量保留，因为它由模拟来源 App 名称和规则模板决定，例如微信样本对应 `微信支付`。

## 调试：单独验证候选规则

```powershell
dart run tool/rule_upgrade.dart verify-candidate `
  --case tool/rule_eval/upgrade_cases/wechat_pinduoduo_single.expected.json `
  --candidate tool/rule_eval/ai_suggestions/wechat_pinduoduo_single.candidate.toml `
  --report build/rule_upgrade/wechat_pinduoduo_single.verify.json
```

通过时退出码为 `0`，失败时退出码为 `1`。报告会列出实际字段和失败字段。

默认验证会把候选 TOML 合并到 `assets/rules/billing_rules.toml` 后运行，并要求实际命中的模板是候选模板。这样可以发现候选被已有规则抢先匹配、优先级冲突或合入后字段变化的问题。

默认验证还会跑已有规则回归样本：

```text
tool/rule_eval/samples
tool/rule_eval/expected
```

这些样本必须继续命中原有期望模板和字段，避免候选模板影响之前的模板识别效果。

验证候选规则时，只比较候选 TOML 声明会提取的字段。完整 `expected` 仍保留给人工核对和后续主规则评估；订单号、商户单号等应通过 `details.remaining_text` 命中，不应生成样本值精确匹配提取器。

只调试候选本身时可以加：

```powershell
--standalone
```

但 standalone 通过不代表可以合并，必须以默认 merged 验证为准。

只在临时定位问题时跳过旧样本回归：

```powershell
--skip-regression
```

正式合并前不能跳过回归。

## 4. 合并到主规则

候选规则通过后，手工合并到：

```text
assets/rules/billing_rules.toml
```

注意：单图候选规则默认不能直接合入主规则。只有满足以下条件时才考虑合并：

- 提取器使用可泛化的标签、正则或 OCR 纠正规则。
- 不把确认后的金额、时间、收单机构、交易单号、商户单号作为主规则常量。
- 至少确认不会在同类 App 的另一张账单上写死当前样本值。
- 主规则验证和现有 `rule_eval` 回归都通过。

如果候选规则为了让单张图通过而包含固定时间、固定机构、固定订单号等确认值常量，它只能留在 `tool/rule_eval/ai_suggestions/` 作为审核材料，不能合入 `assets/rules/billing_rules.toml`。

合并后验证主规则：

```powershell
dart run tool/rule_upgrade.dart verify-candidate `
  --case tool/rule_eval/upgrade_cases/wechat_pinduoduo_single.expected.json `
  --candidate assets/rules/billing_rules.toml `
  --report build/rule_upgrade/wechat_pinduoduo_single.main.verify.json
```

再跑规则包回归：

```powershell
dart run tool/rule_eval.dart
flutter test test\services\billing\rules\billing_rule_repository_test.dart
flutter test test\services\billing\rules\rule_upgrade_tool_test.dart
dart analyze lib\services\dev\rule_upgrade\rule_upgrade.dart tool\rule_upgrade.dart
```

## 5. 打规则包

规则包本体就是 TOML 文件。当前产物位置：

```text
build/rules/billing_rules_2026.07.01.1.toml
build/rules/billing_rules_2026.07.01.1.sha256
build/rules/billing_rules_manifest_2026.07.01.1.json
```

重新打包示例：

```powershell
$version = "2026.07.01.1"
$outDir = "build\rules"
New-Item -ItemType Directory -Force $outDir | Out-Null
$pkg = Join-Path $outDir "billing_rules_$version.toml"
Copy-Item assets\rules\billing_rules.toml $pkg -Force
$hash = (Get-FileHash -Algorithm SHA256 $pkg).Hash.ToLowerInvariant()
$hash | Set-Content -Encoding ASCII -NoNewline (Join-Path $outDir "billing_rules_$version.sha256")
```
