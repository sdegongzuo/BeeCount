# Issue tracker：GitHub

本仓库的 issue、PRD 和任务入口统一放在 GitHub Issues 中。所有相关操作默认使用 `gh` CLI，并从当前仓库的 `git remote -v` 自动推断 GitHub 仓库。

## 常用约定

- **创建 issue**：`gh issue create --title "..." --body "..."`
- **读取 issue**：`gh issue view <number> --comments`
- **列出 issue**：`gh issue list --state open --json number,title,body,labels,comments`
- **评论 issue**：`gh issue comment <number> --body "..."`
- **添加或移除 label**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭 issue**：`gh issue close <number> --comment "..."`

多行正文应使用 heredoc 或等价方式，避免命令行转义导致内容损坏。

## PR 是否作为 triage 请求入口

**PRs as a request surface：no。**

`triage` 默认只处理 GitHub Issues，不把外部 PR 纳入同一套请求队列。协作者或外部贡献者提交的 PR 仍按普通代码评审流程处理。

## 当技能说“发布到 issue tracker”

创建一个 GitHub Issue。

## 当技能说“读取相关 ticket”

执行 `gh issue view <number> --comments`，同时关注 issue 的 labels 和评论上下文。

## Wayfinding 操作约定

如果后续技能需要维护路线图或任务地图：

- **Map**：使用一个带 `wayfinder:map` label 的 GitHub Issue 记录 Notes、Decisions-so-far 和 Fog。
- **Child ticket**：使用子 issue 或在 map 正文中维护任务列表，并在子 issue 正文顶部写明 `Part of #<map>`。
- **Blocking**：优先使用 GitHub 原生 issue dependencies；不可用时，在子 issue 正文顶部写 `Blocked by: #<n>, #<n>`。
- **Claim**：使用 `gh issue edit <n> --add-assignee @me`。
- **Resolve**：评论结论后关闭 issue，并把必要的上下文链接补回 map。
