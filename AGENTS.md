# AGENTS.md

- 删除文件前必须先和用户确认。
- 本项目默认跑 Android，不要改成 Windows/Web 平台启动。
- Android SDK: `D:\app\Android\sdk`；如 `adb` 不在 PATH，用 `D:\app\Android\sdk\platform-tools\adb.exe`。
- 模拟器设备常用 id: `emulator-5554`；先确认：`D:\app\Android\sdk\platform-tools\adb.exe devices`。
- 重启项目：确认需要重启时执行 `powershell -ExecutionPolicy Bypass -File scripts\restart_android_dev.ps1`。
- 若工具不返回实时输出，用后台运行并查看 `flutter-run.out.log` / `flutter-run.err.log`；看到 `Built ... app-dev-debug.apk`、`Installing ...`、`Dart VM Service` 即启动成功。
- 构建依赖当前需要 `android/app/build.gradle` 中 `ndkVersion = "28.2.13676358"`。
- Windows 下 Pub Cache 在 `C:`、项目在 `D:` 时，Kotlin 可能报 `different roots`；保留 `android/gradle.properties` 中 `kotlin.incremental=false` 和 `kotlin.compiler.execution.strategy=in-process`。
- Flutter 3.41+ 使用 `CardThemeData`，不要把 `ThemeData.cardTheme` 改回 `CardTheme`。
- 后续项目文档默认使用中文。
- 在含有用户数据的 Android 真机上测试时，必须遵守 [Android 真机测试数据安全与排障经验](docs/android-real-device-test-safety.md)：禁止 `flutter test ... -d`、uninstall、`pm clear` 和 `flutter clean`，Patrol 必须使用 `--no-uninstall` 并验证 `run-as` 哨兵。

## 可复用的开发经验

- 开始开发和准备修改文件前都检查 `git status`。工作树有并行改动时，以当前任务的明确文件边界为准，不覆盖、不回退、不格式化无关文件；验证结果必须区分“目标测试失败”和“全量测试中的既有/并行失败”，按失败文件、堆栈和基线归因。
- 把 Android 分享记账视为主 Flutter Engine、Headless Engine、原生前台服务和 SQLite 共同参与的并发系统。进程内布尔值、Provider 或 Future 不能作为唯一事实来源；可恢复状态必须持久化，所有副作用提交都要校验当前 owner、generation 和未过期 lease。lease 丢失表示并发资格失效，不应增加业务失败次数。
- 后台 bootstrap 和用户主动启动是两种不同意图：后台处理完成后可以退后台，但用户主动启动一旦发生就必须取消待执行的退后台动作；处理未完成时也不能退后台。将这类竞态提取成无 Android 依赖的纯策略并覆盖状态组合测试。
- 业务错误、证据冲突和关键字段缺失必须分开建模。`sync_extraction_conflict` 只表示规则证据冲突；只要金额和时间完整可靠，不能因此阻断建账。只有真正缺少关键字段时才进入待确认，技术失败则进入独立失败路径。
- Flutter/Android 插件变更不能只验证 debug。`dev_dependencies` 仍可能进入 `GeneratedPluginRegistrant.java` 并破坏 release 编译；调整 `integration_test`、Patrol、Gradle 或插件注册时，同时验证 release 编译，并保留当前两个 release stub，除非已有经过验证的替代方案。
- 通用 UI 组件新增能力时默认关闭，通过显式参数只向目标场景开放，避免改变现有调用方。分类相关页面继续使用一级/二级层级数据，不用 leaf-only 列表替代现有体验；从新增或管理页面返回后，测试真实导航返回和数据刷新，不依赖特定平台返回按钮。
- 含用户数据的真机验证必须预先准备恢复路径，而不是测试失败后临时补救：先构建 `lib/main.dart`，把恢复 APK 固化到不会被其他 target 覆盖的独占路径并校验 SHA-256；测试成功或失败后都分别执行生产 APK 恢复、显式启动和 `run-as` 哨兵复核。
- 构建、安装、启动、调试连接、测试通过和数据保留是六类独立证据。没有实时输出时先用日志、`pm path`、`lastUpdateTime`、`pidof` 和哨兵定位停在哪一层，不要通过重复安装、卸载、清数据或 `flutter clean` 试错。
- OCR 原文、金额、商户、外部 URI、绝对私有路径和回归样本都按敏感数据处理。普通日志、通知和测试报告只记录脱敏标识、稳定错误码与必要状态；需要保留的回归证据使用既有加密存储与备份排除机制。

## Agent skills

### Issue tracker

Issues 和 PRD 统一使用 GitHub Issues 追踪；外部 PR 不作为 triage 请求入口。详见 `docs/agents/issue-tracker.md`。

### Triage labels

本仓库使用默认的五类 triage label 词汇。详见 `docs/agents/triage-labels.md`。

### Domain docs

本仓库使用单一上下文的领域文档布局。详见 `docs/agents/domain.md`。
