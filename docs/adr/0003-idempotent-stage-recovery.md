# 幂等阶段恢复

billing job 的每个阶段设计为幂等——恢复时从已完成阶段的下一步继续，不重复执行已完成的工作。

主流程 stage 追踪 OCR → 规则 → 交易创建 → AI 增强的线性进度。stage 值域为：received / ocr_done / rule_done / transaction_created / ai_done。附件保存（AVIF 编码）与主流程完全独立——它只依赖源图片文件，从收到图片那一刻即可并行启动，用 `attachment_done` boolean 独立追踪。

成功条件：`stage == ai_done && attachment_done == true`。

幂等规则：
- OCR 完成后保存 `raw_text`，恢复时如果 `raw_text` 已有值，不再调用 OCR。
- 规则提取结果保存到 `rule_result_json`，恢复时复用。
- 交易创建前检查 `transaction_id` 是否已存在，已存在则跳过创建。额外使用精确到秒的交易时间 + 金额做防重复，防止同一张图片被分享两次时创建两笔交易。
- AI 增强只更新已存在交易，失败不回滚交易。
- 附件保存前检查 `attachment_done` boolean，已为 true 则直接返回。

错误分类：
- AI 阶段 retryable：网络超时 / 5xx / 429 / 网络不可用
- AI 阶段 non-retryable：API key 缺失 / 401 / 403
- 非 AI 阶段：基础设施错误（文件损坏 / OOM / 磁盘满）标记 failed；业务逻辑错误（默认分类/账户不存在）允许继续
- AI 失败信息只写 job 表的 `last_error`，不写交易的 `detailsText`
