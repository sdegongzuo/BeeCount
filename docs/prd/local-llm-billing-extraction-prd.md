# 端侧模型账单补全 PRD

## Problem Statement

当前图片自动记账依赖 OCR、TOML 规则和云端 AI 增强。TOML 规则适合提取金额、时间、支付通道、付款方式、订单号等确定字段，但对备注、交易对方、分类、补充明细的可读化取舍能力有限。云端 AI 能补足语义字段，但会带来网络依赖、耗时、隐私顾虑和可用性波动。

用户希望在 Android 端引入本地 GGUF 文本模型，根据 OCR 文本补全低风险语义字段，同时保留 TOML 规则对核心字段的确定性保护，让自动记账在离线或弱网环境下仍能得到更可读的交易信息。

## Solution

引入端侧文本模型作为“轻量账单增强”能力。基础链路仍由 OCR 和 TOML 规则完成高置信自动记账；本地模型只在 OCR 文本已产生、规则结果已存在后，从 OCR 文本和规则结果中补充或精简低风险字段。

第一版使用 `Qwen3.5-0.8B-Q5_K_M.gguf` 作为默认验证模型。模型不打入 APK，开发期从设备本地路径加载；正式发布前再做模型下载或导入体验。

TOML 规则继续主导金额、时间、支付通道、付款方式、商户全称、收单机构和结构化补充明细。端侧模型主导备注、交易对方、分类、交易类型候选和用户可读补充明细。最终写入交易前，由合并和归一化层决定哪些字段可以覆盖。

## User Stories

1. As a BeeCount user, I want image billing to work without cloud AI, so that private payment screenshots do not need to leave my device.
2. As a BeeCount user, I want automatic billing to remain fast, so that sharing a screenshot still creates a transaction quickly.
3. As a BeeCount user, I want the app to preserve correct amount and time from deterministic rules, so that local model mistakes do not create wrong transactions.
4. As a BeeCount user, I want notes to be short and readable, so that the transaction list is easy to scan.
5. As a BeeCount user, I want counterparties to prefer the real merchant or platform, so that I do not see clearing institutions as merchants.
6. As a BeeCount user, I want details to show useful readable lines, so that order numbers, discounts, stores, and trip routes remain available after automatic billing.
7. As a BeeCount user, I want model failure to be harmless, so that a bad or missing local model does not block basic automatic billing.
8. As a BeeCount user, I want cloud AI to remain available as an option, so that I can use higher-quality enhancement when desired.
9. As a developer, I want the local model provider to reuse the existing AI extraction contract, so that cloud and local extraction can share prompt parsing and merge behavior.
10. As a developer, I want golden tests to compare TOML-only and TOML-plus-local-model outputs, so that model changes are measurable.
11. As a developer, I want local model traces to record prompt, response, duration, and parse status, so that field errors can be diagnosed.
12. As a developer, I want local model integration to be Android-first, so that the project stays aligned with its current platform target.

## Implementation Decisions

- The local model is a text-only enhancement provider. It consumes OCR text plus the existing rule result and returns JSON-compatible bill fields.
- The first supported model is `Qwen3.5-0.8B-Q5_K_M.gguf`; `Qwen3.5-2B-Q4_K_M.gguf` is reserved for development comparison, not default mobile use.
- The model file is not bundled into the APK in the first iteration. The runtime loads a configured local model path for development validation.
- Android exposes GGUF inference through a platform boundary with methods for availability checks, model loading, text generation, and model unloading.
- Flutter wraps that platform boundary behind a local LLM service, then exposes it as an AI text provider compatible with the existing bill extraction flow.
- The default prompt for local model extraction is shorter than the cloud prompt. It asks only for strict JSON and focuses on low-risk fields.
- TOML high-confidence `amount`, `time`, and `payment_channel` are not overwritten by local model output unless a future explicit conflict policy allows it.
- `payment_method`, `counterparty`, `merchant_full_name`, `acquirer`, `note`, `category`, and `details` may be filled by the local model when they are absent or low confidence.
- `detailsText` is not generated directly by the model. The model returns structured `details`; app code renders user-readable supplemental detail text.
- Debug metadata such as rule IDs, confidence, AI status, prompt text, and trace information must not appear in user-facing supplemental details.
- Local model enhancement runs after fast billing creation or as a non-blocking enhancement step. It must not block the foreground service from finishing the base transaction.
- The existing cloud AI flow remains available. Provider choice is configuration-driven, with local provider treated as another text inference backend.

## Testing Decisions

- The highest-value seam is the image billing evaluation output: compare final recognized fields against `tool/image_billing_golden.json`.
- Unit tests should cover local model response parsing, invalid JSON handling, timeout handling, and merge behavior without requiring a real GGUF model.
- Integration tests should use a fake local LLM service returning deterministic JSON, then verify that the existing OCR result merge and transaction creation behavior are preserved.
- Android runtime validation should run on the project default Android target, not Windows or Web.
- Golden samples should include user-readable `details` objects so that supplemental detail display requirements are tested as data, not as free-form OCR leftovers.
- Performance validation should record model load time, first-token latency, total generation time, and memory pressure for at least the 0.8B model.
- Regression tests should verify that local model output cannot override high-confidence amount, time, or payment channel from TOML rules.

## Out of Scope

- Bundling GGUF models into the APK.
- Building a full production model download marketplace.
- Replacing OCR with a vision model.
- Replacing TOML templates for deterministic core fields.
- Supporting iOS local GGUF inference in the first iteration.
- Training or fine-tuning a custom model.
- Allowing the model to directly write user-facing `detailsText`.

## Further Notes

The current environment does not have `gh` CLI available, so this PRD could not be published to GitHub Issues from this session. When `gh` is available, create a GitHub Issue with this body and apply the `ready-for-agent` label.
