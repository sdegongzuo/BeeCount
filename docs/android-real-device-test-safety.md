# Android 真机测试数据安全与排障经验

本文记录在保留用户真实账本数据的 Android 真机上运行 Flutter/Patrol 集成测试时的安全约束、已验证路径和事故教训。

## 不可违反的安全约束

- 禁止对含有用户数据的真机执行 `adb uninstall`、`adb shell pm clear`或任何等价操作。
- 禁止在该真机上使用 `flutter test <integration_test> -d <device>`。
- 禁止使用 `flutter clean`。它不直接清除手机数据，但会删除本地构建产物，破坏可追溯的 APK/测试环境，也不是解决真机安装问题的安全手段。
- 主 APK 只能使用 `adb install -r`替换安装；测试 APK 只能使用 `adb install -r -t`替换安装。
- Patrol 只走已确认保留应用的 `patrol test --no-uninstall ...` 路径。

## 为什么不能在含数据真机上运行 `flutter test ... -d`

Flutter 3.41 的 Android `integration_test` 设备运行链路在收尾时会调用 `integration_test_device.kill`。该步骤对 Android 的语义不是单纯终止进程，而是调用 uninstall 移除被测应用。Android 卸载会一并删除应用私有数据，因此即使测试本身全部通过，收尾阶段仍可能造成不可恢复的数据丢失。

结论：`flutter test ... -d` 可用于无真实数据的专用测试机/模拟器，不能用于日常使用且需要保留数据的真机。

## 验证前后必须有数据哨兵

测试前用 `run-as` 在应用私有目录写入一个唯一哨兵文件，测试后再读取并校验原值。这可以证明本次测试链路没有卸载或清空应用数据。

```powershell
$adb = 'D:\app\Android\sdk\platform-tools\adb.exe'
$serial = 'DEVICE_SERIAL'
$pkg = 'com.tntlikely.beecount.dev.debug'
$sentinel = 'beecount-real-device-sentinel-20260714'

& $adb -s $serial shell "run-as $pkg sh -c 'printf %s $sentinel > files/codex_data_sentinel'"
& $adb -s $serial shell "run-as $pkg cat files/codex_data_sentinel"
# 运行安全测试后再执行同一条 cat，输出必须完全相同。
```

`run-as` 哨兵只能证明“本次测试前后的私有数据未被整体清除”。它不能证明历史事故发生前的旧数据仍存在，也不能替代对 SQLite 表数量、关键记录或备份的独立检查。

## 安全的 Patrol 路径

对含数据真机，使用 Patrol CLI 并显式传入 `--no-uninstall`：

```powershell
C:\Users\example\AppData\Local\Pub\Cache\bin\patrol.bat test `
  --no-uninstall `
  --target patrol_test/billing_job_android_upgrade_test.dart `
  -d DEVICE_SERIAL `
  --flavor dev `
  --no-generate-bundle
```

Patrol CLI 会协调 Dart 端 `PatrolAppService`、应用 APK、Android Test APK 和 instrumentation runner。不要脱离 CLI 直接运行 `adb shell am instrument`：单独的 instrumentation 进程可能一直等待 Dart 端 Patrol handshake，表现为无测试结果、反复连接或持续卡住。如果 Patrol 90 秒内没有产生结果，应停止并保留 handshake/instrumentation 日志排查，不要无限等待。

## 区分集成测试 APK 和生产入口 APK

以 `integration_test/...` 或 `patrol_test/...` 为 target 构建的 app APK 是集成测试容器，其 Dart 入口不是 `lib/main.dart`。即使 package id 与开发包一致，它也不能作为日常使用的生产入口。

测试结束后必须重新构建 `lib/main.dart` 并替换安装：

```powershell
flutter build apk --debug --flavor dev -t lib/main.dart
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL install -r build\app\outputs\flutter-apk\app-dev-debug.apk
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL shell am start -n com.tntlikely.beecount.dev.debug/com.tntlikely.beecount.MainActivity
```

若需手动安装 Patrol 生成的测试 APK，只能使用：

```powershell
D:\app\Android\sdk\platform-tools\adb.exe -s DEVICE_SERIAL install -r -t <已确认的-test.apk-精确路径>
```

## 本次事故的边界与教训

本次排查过程中，主应用包曾被测试工具移除。重新安装后可以确认后续哨兵在安全测试前后保留，但无法借此证明被移除前的旧数据已保留；Android 卸载通常会删除该包的私有数据。因此事故后的“App 能启动”、“新哨兵存在”都不能被当作旧数据安全的证据。

核心教训：

1. 先确认测试工具的安装与收尾语义，再把它用在含数据真机。
2. 以“前置哨兵 + 安全运行器 + 后置哨兵”作为一个不可拆分的验证单元。
3. 所有 APK 替换都显式写出 `-r`，测试 APK 再加 `-t`，不依赖工具的隐式默认。
4. 测试完成后恢复 `lib/main.dart` 生产入口，并再次校验哨兵。
