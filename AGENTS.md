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

## Agent skills

### Issue tracker

Issues 和 PRD 统一使用 GitHub Issues 追踪；外部 PR 不作为 triage 请求入口。详见 `docs/agents/issue-tracker.md`。

### Triage labels

本仓库使用默认的五类 triage label 词汇。详见 `docs/agents/triage-labels.md`。

### Domain docs

本仓库使用单一上下文的领域文档布局。详见 `docs/agents/domain.md`。
