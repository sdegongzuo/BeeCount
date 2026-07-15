# Task 07：完成确定性分类与待分类补正

对应 Issue：#7

## Task 1：结构化待分类状态和非阻塞门禁

- 为 `transactions` 增加 `needs_classification`，数据库升级到 v29并回填历史魔法字符串。
- 交易创建、Repository、序列化、同步 apply 和 JSON 导入导出完整传递该字段。
- 新图片交易不再把 `待分类：是` 写进 `details_text`。
- `TransactionStageProcessor` 只用金额与时间决定是否待确认。
- 先补 RED 测试，再实现并运行相关测试与生成 Drift 代码。

## Task 2：待分类补正领域服务

- 提供按账本查询待分类交易、加载补正草稿和确认分类的公开边界。
- 确认在同一数据库事务中更新分类、清除标志并登记同步 change。
- 个人规则只在明确选择账本/全局时创建，目标用 category syncId。
- 分类规则匹配键不使用自由补充信息。
- 补充信息与现有 `details_text` 合并，分类/提取/备注记忆选择解耦。
- 先补 service/repository RED 测试，再实现。

## Task 3：生产入口与 UI

- 新增待分类页面，展示证据和结构化摘要，支持仅本次、当前账本、全局三种行为。
- 分享完成后通知主应用；启动/恢复时发现遗留待分类交易。
- 补 widget 与 production navigation 测试。

## Task 4：Android C2 与验收

- 扩展安全 C2 fixture：真实 `ACTION_SEND` → 立即创建“其他+待分类”交易 → 页面选择分类和作用域 → 第二张相似图片命中个人规则。
- 继续使用独立 DB/附件/样本空间、`--no-uninstall`、预构建恢复 APK和前后哨兵。
- 完整 Flutter 测试、相关 analyze、Android 构建、真机证据、独立 spec/code review 后才关闭 #7。

## TODO

- 查找相似历史账单，让用户预览并批量确认。

