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

## 开始前先确认设备状态

真机重启、锁屏或 USB 调试授权未完成时，ADB 可能显示 `offline`、`unauthorized`，也可能导致安装或启动阶段长时间没有新输出。此时先让用户完成开机、解锁和 USB 调试授权，再判断测试链路是否故障；不要通过重复安装、卸载或清数据来“解卡”。

```powershell
$adb = 'D:\app\Android\sdk\platform-tools\adb.exe'
$serial = 'DEVICE_SERIAL'

& $adb devices
& $adb -s $serial get-state
& $adb -s $serial shell getprop sys.boot_completed
```

只有设备出现在 `devices` 列表中、`get-state` 返回 `device`、`sys.boot_completed` 返回 `1` 后，才继续安装或测试。设备虽然已启动但仍锁屏时，应用界面、权限弹窗和 instrumentation 仍可能无法正常推进，因此还要由用户确认已经解锁。

如果测试过程中发生重启，本轮测试应视为被中断，不能把重启后 App 能打开当作测试通过。设备恢复并解锁后，先重新读取原哨兵；原值完整保留只能证明应用私有数据跨本次重启仍在，随后再决定是否从头重跑测试。

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

### 在任何有状态操作前固化生产恢复 APK

Flutter/Patrol 的不同 target 可能反复覆盖同一个 `build\app\outputs\flutter-apk\app-dev-debug.apk`。因此不能等测试结束后才假设该路径仍然指向 `lib/main.dart`，也不能把“重新构建应该能成功”当作恢复方案。

安全运行器应在 Patrol、测试 APK 安装或其他有状态设备操作之前完成以下动作：

1. 以 `lib/main.dart` 明确构建 production 入口 APK。
2. 检查产物存在且非空。
3. 将产物复制到本次运行独占、不会被后续构建覆盖的恢复路径。
4. 计算源文件与副本的 SHA-256，并要求二者完全一致。
5. 记录恢复 APK 的绝对路径和哈希；测试结束后不自动删除该证据。

恢复时直接使用这份预构建、已校验的 APK 执行 `adb install -r`。这样即使 Patrol 失败、构建环境在测试后损坏或公共产物路径已被测试 target 覆盖，仍有确定的 production 入口可以恢复。

## 测试夹具必须与用户数据物理隔离

仅在逻辑上使用“测试账本”不够安全。真机 C2 应让测试夹具拥有独立的数据命名空间，并保证生产路径在未启用夹具时完全不变：

- 使用独立 SQLite 文件，不打开用户的 production 数据库；
- 使用独立附件与缩略图目录；
- 独立创建测试账本、账户、分类和规则种子；
- 禁用自动回归样本采集，避免测试 OCR 写入用户样本库；
- 每次运行使用新的唯一 fixture ID，不复用或主动清理历史夹具；
- fixture ID 只能通过严格白名单格式校验后参与文件名或路径构造。

如果 native `ACTION_SEND` 和 Dart 容器都需要识别同一个夹具，应选一个权威来源。当前已验证方案以编译期 `dart-define` 为权威，运行时 extra 只用于证明 Activity → ForegroundService → Dart 的链路相关性：两者必须完全相同，任一单独出现、格式非法或值不匹配都应立即拒绝。不能让未经校验的 runtime extra 直接参与路径拼接。

测试专用 MethodChannel、入口或调试能力只能在 debuggable 构建注册；release 构建必须显式拒绝，并用 Android 单元测试与 release Kotlin 编译共同固化这一边界。

## 恢复流程必须失败安全且互不短路

Patrol 成功不代表恢复成功，Patrol 失败也不能跳过恢复。安全运行器应把恢复放在 `finally` 中，并分别尝试：

1. 恢复 Patrol/test bundle 的原始字节，并校验哈希和 target marker；
2. 使用预先固化的 production APK 执行 `adb install -r`；
3. 显式启动 production `MainActivity`；
4. 逐字读取并核对原有 `run-as` 哨兵。

四个步骤必须各自捕获错误并继续执行，最后汇总报告全部失败项。不能因为 bundle 恢复失败就不安装主 APK，也不能因为安装失败就省略哨兵检查。恢复过程不得依赖 Patrol 结束后再次构建，不得执行 uninstall、`pm clear`、`flutter clean` 或删除命令。

运行器还应把“用户已解锁”设计为强制显式参数，并在解析项目路径、构建或调用任何有状态命令之前拒绝缺少该参数的运行。该参数不能替代实时设备门禁；随后仍需检查 `adb get-state=device`、`sys.boot_completed=1` 并读取既有哨兵。

## 安装没有新输出时如何判断

把“构建 APK”“替换安装”“启动应用”“连接 Dart VM/Patrol”看成四个独立阶段。某一阶段没有继续输出，不代表前一阶段失败，更不代表需要重新安装。先用设备上的事实定位当前阶段：

```powershell
$adb = 'D:\app\Android\sdk\platform-tools\adb.exe'
$serial = 'DEVICE_SERIAL'
$pkg = 'com.tntlikely.beecount.dev.debug'

& $adb -s $serial shell pm path $pkg
& $adb -s $serial shell dumpsys package $pkg | Select-String 'versionName|lastUpdateTime'
& $adb -s $serial shell pidof $pkg
```

- `adb install -r` 返回 `Success`，或包的 `lastUpdateTime` 已更新，说明替换安装已经完成。此后没有输出，应排查启动、锁屏或调试连接，而不是再次安装。
- `pm path` 能找到 APK，只能证明包存在；它不能证明当前安装的是生产入口，也不能证明 App 已启动或测试已通过。
- `pidof` 有结果说明进程存在；没有结果时可显式执行 `am start`，但仍需结合应用界面和日志确认初始化完成。
- 使用项目重启脚本时，查看 `flutter-run.out.log` 和 `flutter-run.err.log`。出现 `Built ... app-dev-debug.apk`、`Installing ...`、`Dart VM Service` 分别对应构建、安装和 Flutter 调试连接阶段。

替换安装失败且提示签名不一致、版本降级或包冲突时必须停下排查构建产物，不能用卸载旧包或 `pm clear` 作为解决办法。`-r` 的目标是保留已有应用数据，但仍必须用安装前后的哨兵值来验证本次链路。

## 一次完整的安全验证闭环

1. 确认设备序列号、连接状态、系统启动完成，并由用户确认已解锁。
2. 读取现有数据哨兵；不存在时先创建并回读确认。
3. 确认测试夹具使用独立数据库、附件目录、规则和样本策略，且 fixture ID 已严格校验。
4. 在任何有状态设备操作前构建 `lib/main.dart`，固化并校验唯一的 production 恢复 APK。
5. 使用 `adb install -r` 替换主 APK；测试 APK 额外使用 `-t`，Patrol 始终使用 `--no-uninstall`。
6. 根据构建、安装、启动、调试连接四个阶段分别取证，不因暂时没有输出而重复执行有状态操作。
7. 无论测试成功或失败，都执行互不短路的 bundle 恢复、production APK 替换安装、MainActivity 启动和哨兵复核。
8. 再次读取哨兵并核对原值；如设备在过程中重启，还要在解锁恢复后额外复核一次。
9. 记录实际执行的设备序列号、fixture ID、恢复 APK 路径与哈希、安装结果、测试结果和前后哨兵值，不能只记录“已安装”或“App 能打开”。

## 证据分层：不要把局部通过写成真机通过

不同验证只能证明各自覆盖的边界：

- Dart 单测证明夹具策略、命名空间和运行器契约；
- Android 单测与 release 编译证明 native 参数校验和调试能力的发布边界；
- `flutter analyze` 与 APK build 证明代码可分析、可编译；
- 静态检查可以证明测试代码调用了 production `ACTION_SEND` 链路；
- 只有安全运行器在已解锁真机上实际完成 Patrol、production 恢复和前后哨兵校验，才能证明真机 C2 闭环；
- 即使真机 C2 通过，也只证明该设备、该系统状态和该 fixture 下的行为，不能外推为所有 OCR 字体、厂商系统或权限状态都稳定。

因此报告必须区分“本地验证完成”“等待真机证据”“真机闭环完成”。缺少设备证据时应明确写出 concern，不能用 APK 构建成功、应用可启动或测试代码路径看起来正确替代真机结论。

## 本次事故的边界与教训

本次排查过程中，主应用包曾被测试工具移除。重新安装后可以确认后续哨兵在安全测试前后保留，但无法借此证明被移除前的旧数据已保留；Android 卸载通常会删除该包的私有数据。因此事故后的“App 能启动”、“新哨兵存在”都不能被当作旧数据安全的证据。

核心教训：

1. 先确认测试工具的安装与收尾语义，再把它用在含数据真机。
2. 以“前置哨兵 + 安全运行器 + 后置哨兵”作为一个不可拆分的验证单元。
3. 所有 APK 替换都显式写出 `-r`，测试 APK 再加 `-t`，不依赖工具的隐式默认。
4. 测试完成后恢复 `lib/main.dart` 生产入口，并再次校验哨兵。
5. 设备重启或锁屏属于独立环境状态；先恢复并确认设备状态，再判断命令是否卡住。
6. 安装成功、进程存在、App 可启动和测试通过是四件不同的事，必须分别取证。
7. 没有实时输出时先查设备和日志，不重复执行安装，更不能用卸载或清数据排障。
8. 测试产物会覆盖公共 APK 路径；production 恢复包必须在测试前固化并校验，不能临时重建碰运气。
9. 测试数据隔离必须落到独立数据库、附件目录和样本策略，不能只靠测试记录的业务标签区分。
10. 恢复是一个独立的、失败安全的流程；每个恢复步骤都要继续执行并单独留证。
11. 编译、静态检查、模拟链路和真机 C2 是不同层级的证据，报告结论不能越级。
