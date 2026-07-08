# Billing Job 测试大纲

基于设计文档（docs/adr/0001~0003）和 CONTEXT.md 中的领域术语。

## 📊 全局进度

[ 50 / 50 ]

- [x] 接缝 1：BillingJobRepository (10/10)
- [x] 接缝 2：BillingJobRunner (13/13)
- [x] 接缝 3：Stage Processors (19/19)
- [x] 接缝 4：Error Classifier (12/12)
- [x] 接缝 5：Notification Mapper (8/8)
- [x] 接缝 6：Integration (10/10)

---

## 🔍 详细用例状态机说明

每一个用例必须严格经历以下四个状态：

- ⬜ `[TODO]`：未开始
- 🟥 `[RED]`：已编写失败测试，等待实现
- 🟩 `[GREEN]`：测试已通过，等待重构
- 🛠️ `[DONE]`：重构完成，提交代码

---

## 接缝约定

| # | 接缝 | 测试对象 | 文件位置 |
|---|------|---------|---------|
| 1 | BillingJobRepository | billing_jobs 表的 CRUD、查询、lease | `test/data/repositories/billing_job_repository_test.dart` |
| 2 | BillingJobRunner | 状态机编排、超时、恢复 | `test/services/billing/billing_job_runner_test.dart` |
| 3 | Stage Processors | 各阶段独立逻辑 | `test/services/billing/stages/` 目录 |
| 4 | Error Classifier | 错误分类（retryable vs non-retryable） | `test/services/billing/billing_error_classifier_test.dart` |
| 5 | Notification Mapper | stage/status → 通知文案映射 | `test/services/billing/billing_notification_mapper_test.dart` |
| 6 | Integration | 端到端流程 | `test/services/billing/billing_job_integration_test.dart` |

Mock 策略：沿用项目惯例——手写 fake 实现接口，DB 用 `BeeDatabase.forTesting(NativeDatabase.memory())`。

---

## 接缝 1：BillingJobRepository

数据层，直接操作 billing_jobs 表。

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `create job with initial stage=received` | 创建 job 后 stage 为 received，status 为 pending，attempt_count 为 0 |
| 🛠️ DONE | `update stage advances job progress` | 更新 stage 后查询到的 stage 值正确 |
| 🛠️ DONE | `update status to retryable_failed records last_error` | 标记 retryable_failed 时 last_error 和 attempt_count 正确持久化 |
| 🛠️ DONE | `findPendingJobs returns pending and retryable_failed` | 查询返回 status 为 pending 或 retryable_failed 的 job |
| 🛠️ DONE | `findPendingJobs excludes succeeded and failed` | 不返回已完成或已失败的 job |
| 🛠️ DONE | `claimJob sets lease_until and returns true` | 设置 lease_until 后返回 true |
| 🛠️ DONE | `claimJob returns false if already leased` | 已被 lease 且未过期的 job 不能被再次 claim |
| 🛠️ DONE | `claimJob returns true if lease expired` | lease 已过期的 job 可以被重新 claim |
| 🛠️ DONE | `markSucceeded sets completed_at` | 成功后 completed_at 不为 null |
| 🛠️ DONE | `findByImagePath deduplicates by path` | 同一 image_path 的 job 不会重复创建（配合已有去重逻辑） |

---

## 接缝 2：BillingJobRunner

状态机编排，协调各阶段执行。

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `runJob completes all stages in order` | 从 received 跑到 ai_done，stage 逐步推进 |
| 🛠️ DONE | `runJob sets attachment_done when attachment completes` | 附件完成后 attachment_done 为 true |
| 🛠️ DONE | `runJob marks succeeded when ai_done and attachment_done` | 主流程完成 + 附件完成 → status=succeeded |
| 🛠️ DONE | `runJob stops at deadline and marks retryable_failed` | 超时后 status=retryable_failed，stage 为已完成阶段 |
| 🛠️ DONE | `resumeJob continues from saved stage` | 从 ocr_done 恢复，不再执行 OCR，直接从 rule_done 继续 |
| 🛠️ DONE | `resumeJob skips already-completed stages` | 从 transaction_created 恢复，OCR/规则/交易创建都被跳过 |
| 🛠️ DONE | `resumeJob re-runs failed stage` | 从 retryable_failed 的某个 stage 恢复，重新执行该 stage |
| 🛠️ DONE | `runJob respects lease_until concurrency control` | 两个 runner 不能同时运行同一个 job |
| 🛠️ DONE | `runJob increments attempt_count on failure` | 失败后 attempt_count 加 1 |
| 🛠️ DONE | `runJob classifies AI errors correctly` | AI 网络超时 → retryable_failed；API key 缺失 → failed |
| 🛠️ DONE | `runJob does not write AI errors to transaction detailsText` | AI 失败信息只写 job 表，不写交易的 detailsText |
| 🛠️ DONE | `runJob launches attachment in parallel from start` | 附件编码在收到图片后立即启动，不等 OCR 完成 |
| 🛠️ DONE | `runJob succeeds even if attachment finishes before AI` | 附件先完成 + AI 后完成 → succeeded |

---

## 接缝 3：Stage Processors

各阶段的独立逻辑。每个处理器接收 stage 输入，返回 stage 输出。

### 3a：OCR Stage Processor

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `OCR extracts raw_text from valid image` | 正常图片 → raw_text 非空 |
| 🛠️ DONE | `OCR skips if raw_text already exists (idempotent)` | raw_text 已有值 → 不再调用 OCR，直接返回 |
| 🛠️ DONE | `OCR fails on corrupted image file` | 文件损坏 → stage 保持 received，status=failed |
| 🛠️ DONE | `OCR fails when engine returns empty text` | OCR 返回空文本 → 视为失败，job 终止 |

### 3b：Rule Extraction Stage Processor

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `rule extraction populates rule_result_json` | 匹配到规则 → rule_result_json 有值 |
| 🛠️ DONE | `rule extraction skips if rule_result_json exists` | 幂等：已有结果 → 不重新提取 |
| 🛠️ DONE | `rule extraction proceeds with empty match` | 没匹配到规则 → 正常推进到 transaction_created（不报错） |
| 🛠️ DONE | `rule extraction merges legacy regex results` | TOML 规则 + 旧正则结果正确合并 |

### 3c：Transaction Creation Stage Processor

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `creates transaction and saves transaction_id` | 创建成功 → transaction_id 不为 null |
| 🛠️ DONE | `skips creation if transaction_id already exists` | 幂等：已有 transaction_id → 不重复创建 |
| 🛠️ DONE | `deduplicates by time+amount within same second` | 相同秒级时间 + 相同金额 → 不创建第二笔交易 |
| 🛠️ DONE | `assigns default category when match fails` | 分类匹配失败 → 使用默认分类，不报错 |
| 🛠️ DONE | `assigns default account when match fails` | 账户匹配失败 → 使用默认账户，不报错 |

### 3d：AI Enhancement Stage Processor

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `AI enhances transaction with extracted fields` | AI 成功 → 交易字段被更新 |
| 🛠️ DONE | `AI skips if transaction_id is null` | 没有交易 → 跳过 AI 阶段 |
| 🛠️ DONE | `AI timeout classified as retryable` | 网络超时 → retryable_failed，stage 保持 transaction_created |
| 🛠️ DONE | `AI 401/403 classified as non-retryable` | 认证失败 → status=failed |
| 🛠️ DONE | `AI 429 classified as retryable` | 限流 → retryable_failed |
| 🛠️ DONE | `AI network unavailable classified as retryable` | 无网络 → retryable_failed |
| 🛠️ DONE | `AI does not pollute transaction detailsText` | AI 错误不写入交易的 detailsText 字段 |

### 3e：Attachment Stage Processor

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `saves AVIF attachment and marks attachment_done=true` | 正常保存 → attachment_done 为 true |
| 🛠️ DONE | `skips if attachment already exists for this job` | 幂等：已有附件 → 直接标记 attachment_done |
| 🛠️ DONE | `generates thumbnail from source image for AVIF` | AVIF 编码时缩略图从源图生成，不解码 AVIF |
| 🛠️ DONE | `small image (≤1920) skips JPEG preprocessing` | 小图直接 encodeAvif，不缩放 |
| 🛠️ DONE | `large image resizes before AVIF encoding` | 超大图先缩放再编码 |
| 🛠️ DONE | `attachment failure does not block main pipeline` | 附件失败不影响主流程 stage 推进 |

---

## 接缝 4：Error Classifier

错误分类逻辑，决定 retryable vs non-retryable。

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `connection abort is retryable` | SocketException → retryable |
| 🛠️ DONE | `timeout is retryable` | TimeoutException → retryable |
| 🛠️ DONE | `5xx server error is retryable` | HTTP 500/502/503 → retryable |
| 🛠️ DONE | `429 rate limit is retryable` | HTTP 429 → retryable |
| 🛠️ DONE | `network unavailable is retryable` | 无网络连接 → retryable |
| 🛠️ DONE | `401 unauthorized is non-retryable` | HTTP 401 → non-retryable |
| 🛠️ DONE | `403 forbidden is non-retryable` | HTTP 403 → non-retryable |
| 🛠️ DONE | `missing API key is non-retryable` | AI 配置缺失 → non-retryable |
| 🛠️ DONE | `corrupted image file is non-retryable` | 图片文件损坏 → non-retryable |
| 🛠️ DONE | `OOM during OCR is non-retryable` | OCR 引擎 OOM → non-retryable |
| 🛠️ DONE | `disk full during DB write is non-retryable` | 磁盘满 → non-retryable |
| 🛠️ DONE | `default category not found allows continuation` | 默认分类不存在 → 允许继续（不报错） |

---

## 接缝 5：Notification Mapper

stage/status 组合 → 通知文案。

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `received stage shows 正在识别账单` | OCR 阶段 → "正在识别账单..." |
| 🛠️ DONE | `ocr_done stage shows 正在识别账单` | 规则提取阶段 → "正在识别账单..." |
| 🛠️ DONE | `transaction_created stage shows 正在补全账单信息` | AI 阶段 → "正在补全账单信息..." |
| 🛠️ DONE | `ai_done + attachment_done shows 记账完成` | 全部完成 → "记账完成" |
| 🛠️ DONE | `ai_done + attachment_pending shows 记账已创建附件稍后保存` | AI 完成但附件未完成 → "记账已创建，附件稍后保存" |
| 🛠️ DONE | `timeout at any stage shows 记账已创建剩余信息稍后补全` | 超时 → "记账已创建，剩余信息稍后补全" |
| 🛠️ DONE | `failed status shows 部分信息待补全` | 失败 → "部分信息待补全，打开 App 后继续" |
| 🛠️ DONE | `notification tap triggers resumePendingBillingJobs` | 点击通知 → 打开 App 并恢复任务 |

---

## 接缝 6：Integration（端到端）

跨接缝的完整流程测试。

| 状态 | 测试名 | 描述 |
|------|--------|------|
| 🛠️ DONE | `full pipeline: image share to succeeded` | 分享图片 → OCR → 规则 → 交易 → AI → 附件 → succeeded |
| 🛠️ DONE | `full pipeline with AI timeout: retry and succeed` | AI 超时 → retryable_failed → 恢复 → AI 成功 → succeeded |
| 🛠️ DONE | `full pipeline with permanent AI failure: transaction still created` | AI 不可恢复失败 → 交易已创建，stage=transaction_created，status=failed |
| 🛠️ DONE | `resume from ocr_done after app restart` | App 重启后从 ocr_done 恢复，不重复 OCR |
| 🛠️ DONE | `same image shared twice does not create duplicate transaction` | 同图分享两次 → 只有一笔交易（时间+金额去重） |
| 🛠️ DONE | `two concurrent jobs run independently` | 2 个 job 并发 → 各自独立完成 |
| 🛠️ DONE | `90s timeout saves partial progress` | 90s 超时 → 进度已持久化 → 下次恢复 |
| 🛠️ DONE | `attachment runs in parallel and finishes before AI` | 附件比 AI 先完成 → 不阻塞主流程 |
| 🛠️ DONE | `attachment runs in parallel and finishes after AI` | 附件比 AI 慢 → AI 完成后等附件 → succeeded |
| 🛠️ DONE | `notification opens app and triggers recovery` | 点击通知 → App 打开 → resumePendingBillingJobs 被调用 |
