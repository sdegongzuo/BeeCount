---
status: accepted
---

# 分享图片记账采用 Billing Case 与分离工作队列

分享图片记账完全替换旧 Billing Job Stage Runner 和覆盖整个处理周期的原生 delivery lease。
每次分享以本地 Billing Case 为业务事实来源；机器可抢占工作进入带 generation fencing 的
Automation Task，等待用户的金额/时间裁决与分类进入不持有 lease 的 User Task，图片转换和
附件发布形成独立流水线，通知及页面刷新通过本地 Transactional Outbox 可靠交付。队列之间
只通过短 SQLite 事务转换，任何 OCR、图片转换、重试等待或用户输入都不持有数据库事务。

选择该方案是因为旧设计把原生交付、自动执行、用户交接、附件和通知状态分散在
SharedPreferences、Billing Job Stage、异步 Future 和页面 Provider 中，导致 lease 过期
fencing、崩溃恢复、待确认附件续跑和通知一致性难以局部保证。分离工作队列使自动 owner、
用户责任和外部交付各自只有一个持久化来源，同时允许 OCR 与图片转换并行、待用户工作不阻塞
新分享、通知失败不丢任务。

## Considered Options

- 在现有 Billing Job 上继续增加状态与修复：迁移较小，但继续让一个 Stage 模型承担多条独立
  流水线，无法形成清晰的 owner 和恢复规则。
- 只增加两个页面查询队列：可以改善入口，却不能解决原生 delivery lease、附件并行和通知
  原子性问题。
- 长期双写旧、新运行时：降低一次切换风险，但会让状态不一致面扩大并长期保留两套恢复语义。

## Consequences

V2 使用 Billing Case、Automation Task、User Task、Prepared Attachment 和 Billing Outbox
Event；旧 Stage、长生命周期 delivery lease、原生待确认 payload 和 Provider 事实来源在切换
后删除。已有用户数据通过一次性 SQLite migration 映射，新运行时直接启用，不长期双轨。
Billing Case、任务、OCR 证据和 Outbox 只在本设备保存；待分类完成前交易不得同步。

