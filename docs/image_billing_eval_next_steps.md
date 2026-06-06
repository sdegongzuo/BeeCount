# 图片记账评测整合与清理计划

## 目标

把图片记账评测收敛到一套共享评测核心，并让 Patrol 成为唯一主入口。

Patrol 负责在 Android 上跑真实 OCR、图片理解大模型和 final JSON。共享核心负责 golden 比对。CLI 不再作为主流程，只临时保留为读取已导出的 actual JSON 并生成本地报告的兼容 wrapper。

## 当前原则

- golden 比对逻辑只保留一份。
- Android runner 只负责产出 actual。
- Patrol 是主评测入口。
- CLI 不是必须能力，后续 Patrol 报告稳定后可删除。
- 删除文件前必须单独确认。

## 已整合方向

### 1. 共享评测核心

新增 `lib/services/dev/image_billing_eval_assertions.dart`，作为纯 Dart 评测核心。

它负责：

- golden JSON 解析。
- actual JSON 解析。
- final payload 提取。
- 字段比对。
- 字段归一化。
- `expected_any` 可接受变体。
- `ImageBillingEvalSummary`。
- `evaluateImageBillingPayload()`。

共享核心不得依赖 Flutter、`path_provider`、`rootBundle`、OCR 或 AI provider。

### 2. Patrol 主入口

保留 `patrol_test/image_billing_eval_test.dart` 作为主自动化测试。

Patrol 流程：

- 从 asset 读取 `tool/image_billing_golden.json`。
- 把样本图片复制到 App 可读临时目录。
- 调用 `ImageBillingEvalRunner.run()`。
- 读取 `latest_actual.json`。
- 调用共享评测核心生成 summary。

默认强制：

- 7 个样本全部运行。
- 7 个样本都有 actual。
- runner failed 为 0。

strict 模式：

- 通过 `IMAGE_BILLING_EVAL_STRICT=true` 开启。
- golden failure 不为空时测试失败。

### 3. CLI 降级为临时 wrapper

`tool/image_billing_eval.dart` 暂时保留，但只做：

- 解析命令行参数。
- 读取 golden 和 actual 文件。
- 调用共享评测核心。
- 输出 Markdown/JSON 报告。

CLI 不再拥有独立业务比对逻辑，不再作为主评测入口。等 Patrol 报告稳定后，再确认是否删除这个 wrapper。

### 4. 页面说明

`lib/pages/ai/ai_settings_page.dart` 的调试说明改为：

- Patrol 是图片记账评测主入口。
- 主要报告位置是 `build/image_billing_eval/patrol_report.md`。
- actual JSON 位置是 `build/image_billing_eval/latest_actual.json`。

不再提示手动运行 tool 脚本作为主流程。

## Evaluation Rules

字段归一化集中在共享核心：

- `payment_method`：统一中英文括号、方括号和空格，例如 `中国银行银联准贷记卡[2853]` 与 `中国银行银联准贷记卡(3610)` 视为一致。
- `merchant_full_name` / `counterparty`：统一中英文括号。
- `category`：明确同义词归一，例如 `医疗` 与 `医疗保健`。
- `amount`：保留小额浮点误差容忍。
- `time`：保留 1 秒内误差容忍。

golden 规则：

- `expected` 保留主期望。
- `expected_any` 表示合理变体。
- `forbidden` 表示必须避免的错误值。

Patrol 设备端 payload 评测不检查 `image/单条/...` 文件存在性；本地报告 wrapper 继续检查图片文件存在性。

## 待确认清理项

以下文件暂不删除，删除前需要单独确认：

- `tool/image_billing_eval.dart`
- `scripts/push_image_billing_eval_samples.ps1`
- `scripts/pull_image_billing_eval_actual.ps1`
- `patrol_test/test_bundle.dart` 如果它只是 Patrol 生成产物且不需要提交

推荐清理顺序：

1. 先让 Patrol 稳定生成 summary 和报告。
2. 确认不再需要本地离线重算报告。
3. 再删除 `tool/image_billing_eval.dart`。
4. 确认 Patrol 已稳定复制样本、拉取 actual 后，再删除 push/pull 脚本。

## Test Plan

静态检查：

```powershell
dart analyze tool/image_billing_eval.dart patrol_test/image_billing_eval_test.dart lib/services/dev/image_billing_eval_runner.dart lib/services/dev/image_billing_eval_assertions.dart
```

本地报告 wrapper 回归：

```powershell
dart run tool/image_billing_eval.dart --actual build/image_billing_eval/latest_actual.json --report build/image_billing_eval/patrol_report.md
```

Patrol Android 回归：

```powershell
patrol test --target patrol_test/image_billing_eval_test.dart --device emulator-5554 --no-uninstall --no-check-compatibility --no-coverage --show-flutter-logs
```

验证结果：

- `Total: 1`
- `Successful: 1`
- `Failed: 0`
- `With actual: 7/7`

strict 回归：

```powershell
patrol test --target patrol_test/image_billing_eval_test.dart --device emulator-5554 --dart-define=IMAGE_BILLING_EVAL_STRICT=true --no-uninstall --no-check-compatibility --no-coverage --show-flutter-logs
```

目标：

- `With actual: 7/7`
- golden failures 为 0

跑完 Patrol 后恢复 dev 入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/restart_android_dev.ps1
```

确认 App 回到正常 `lib/main.dart` dev 入口。
