# 任务 04：Android 分享短时前台服务

## 目标

新增 Android 分享到 BeeCount 的入口路径，使用轻量分享接收 Activity 和短时前台服务通知。

## 依赖

- 依赖：`docs/tasks/task-00-contracts.md`

## 主要文件

- Create: `android/app/src/main/kotlin/com/tntlikely/beecount/ShareBillingActivity.kt`
- Create: `android/app/src/main/kotlin/com/tntlikely/beecount/ShareBillingForegroundService.kt`
- Create or modify: Android notification channel helper if needed.
- Modify: `android/app/src/main/AndroidManifest.xml`
- Read: `android/app/src/main/kotlin/com/tntlikely/beecount/ScreenshotSourceResolver.kt`

## 范围

本任务负责把分享 URI 复制到私有 cache、从原始 URI 读取图片时间、启动短时前台服务，并把 payload 传给 Flutter 或后续集成层。本任务不实现交易创建。

## 步骤

1. 添加图片分享接收 Activity 和前台服务的 manifest 声明。
2. 确保 `ACTION_SEND image/*` 路由到分享接收 Activity，而不是必须打开主 Flutter Activity。
3. 立即把传入的 `content://` 图片复制到 App 私有 cache。
4. 可用时从原始 URI 读取 `MediaStore.DATE_ADDED`、`DATE_TAKEN` 和 EXIF 时间。
5. UsageStats 查询必须使用截图生成时间，不能使用分享时间或 cache 文件时间。
6. 尽快启动前台服务，并显示“正在识别账单”通知。
7. 收到成功或失败回调后停止服务。
8. 使用 `D:\app\Android\sdk\platform-tools\adb.exe devices` 在 Android 模拟器或真机上验证。

## 完成标准

- 分享流程不依赖长期后台服务。
- 前台服务通知是短时通知。
- UsageStats 推断不使用 cache 文件时间戳。

## 并行说明

Task 00 完成后，可与 Task 01、Task 02、Task 03 并行执行，但 manifest 修改需要和集成任务协调。
