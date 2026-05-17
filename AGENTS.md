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
