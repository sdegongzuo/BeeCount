#!/bin/bash
# 生产包构建脚本 - 解决 integration_test/patrol 插件在 release 构建中的编译问题

set -e

echo "🔨 开始构建生产包..."

# 1. 运行 flutter pub get (这会生成包含测试插件的 GeneratedPluginRegistrant.java)
flutter pub get

# 2. 删除 GeneratedPluginRegistrant.java，防止测试插件被编译
GENERATED_FILE="android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
if [ -f "$GENERATED_FILE" ]; then
    echo "🗑️  删除 GeneratedPluginRegistrant.java..."
    rm -f "$GENERATED_FILE"
fi

# 3. 使用 Gradle 直接构建 (不触发 flutter pub get)
echo "📦 使用 Gradle 构建 APK..."
export JAVA_HOME="D:\\app\\Android\\AndroidStudio\\jbr"
cd android
./gradlew.bat :app:assembleProdRelease --no-daemon
cd ..

# 4. 检查构建结果
APK_PATH="build/app/outputs/flutter-apk/app-prod-release.apk"
if [ -f "$APK_PATH" ]; then
    echo "✅ 构建成功！"
    echo "📱 APK 路径: $APK_PATH"
    ls -lh "$APK_PATH"
else
    echo "❌ 构建失败"
    exit 1
fi
