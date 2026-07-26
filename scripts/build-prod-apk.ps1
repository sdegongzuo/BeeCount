# 生产包构建脚本 - 解决 integration_test/patrol 插件在 release 构建中的编译问题
param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

Write-Host "🔨 开始构建生产包..." -ForegroundColor Green

# 1. 运行 flutter pub get
Write-Host "📦 运行 flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get 失败"
}

# 2. 删除 GeneratedPluginRegistrant.java
$generatedFile = "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
if (Test-Path $generatedFile) {
    Write-Host "🗑️  删除 GeneratedPluginRegistrant.java..." -ForegroundColor Yellow
    Remove-Item $generatedFile -Force
}

# 3. 使用 Gradle 直接构建
Write-Host "📦 使用 Gradle 构建 APK..." -ForegroundColor Yellow
$env:JAVA_HOME = "D:\app\Android\AndroidStudio\jbr"
Push-Location android
try {
    & .\gradlew.bat :app:assembleProdRelease --no-daemon
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle 构建失败"
    }
} finally {
    Pop-Location
}

# 4. 检查构建结果
$apkPath = "build\app\outputs\flutter-apk\app-prod-release.apk"
if (Test-Path $apkPath) {
    $apkInfo = Get-Item $apkPath
    Write-Host "✅ 构建成功！" -ForegroundColor Green
    Write-Host "📱 APK 路径: $apkPath" -ForegroundColor Cyan
    Write-Host "📦 文件大小: $([math]::Round($apkInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "📅 最后修改: $($apkInfo.LastWriteTime)" -ForegroundColor Cyan
} else {
    Write-Host "❌ 构建失败 - APK 未找到" -ForegroundColor Red
    exit 1
}
