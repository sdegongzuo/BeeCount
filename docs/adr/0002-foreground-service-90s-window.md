# Foreground Service 90 秒执行窗口

图片分享启动 Android Foreground Service，提供 90 秒保护窗口执行 billing job。

选择 90 秒而非更短的窗口（如 50 秒），是因为 AI 增强（网络调用）的正常耗时为 10-40 秒，加上 OCR/规则/交易创建/AVIF 编码，50 秒窗口几乎不可能在一次运行中完成所有阶段。90 秒窗口与现有 AI 超时（90 秒）匹配，避免需要额外缩短 AI 超时。

Android Foreground Service 本身没有硬性时间限制（ANR 限制针对 Activity/BroadcastReceiver），90 秒窗口通过自定义 watchdog 定时器实现。超时时，已完成的阶段进度已持久化，未完成阶段标记为 `retryable_failed`，用户不会感知到失败——下次打开 App 时自动恢复。

最多允许 2 个 job 并发执行，多余排队。用户快速连续分享多张图片时，串行处理确保每张图都有完整的执行窗口。
