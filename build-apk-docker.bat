@echo off
setlocal enabledelayedexpansion

echo 🚀 使用 Docker 构建 APK

REM 检查 Docker 是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker 未运行，请先启动 Docker
    exit /b 1
)

REM 构建 Docker 镜像
echo 📦 构建 Docker 镜像...
docker build -t flutter-builder:latest .
if errorlevel 1 (
    echo ❌ Docker 镜像构建失败
    exit /b 1
)

REM 检查是否存在签名密钥
if exist "android\upload-keystore.jks" if exist "android\key.properties" (
    echo ✅ 找到签名配置，将构建发布版 APK
) else (
    echo ⚠️  未找到签名配置，将构建调试版 APK
    echo 提示：如需发布版本，请先配置签名密钥
)

REM 运行 Docker 容器并构建 APK
echo 🔨 开始构建 APK...
docker run --rm -v "%cd%:/app" -w /app flutter-builder:latest bash -c "set -e && echo '📥 安装依赖...' && flutter pub get && echo '🧹 清理构建缓存...' && flutter clean && rm -rf android/.gradle && rm -rf android/build && rm -rf android/app/build && echo '🔧 修复插件问题...' && PLUGIN_DIR=\"${HOME}/.pub-cache/hosted/pub.dev/flutter_dynamic_icon-2.1.0/android\" && if [ -d \"$PLUGIN_DIR\" ]; then if [ -f \"$PLUGIN_DIR/build.gradle\" ]; then sed -i \"s/apply plugin: 'com.android.library'/apply plugin: 'com.android.library'\nandroid.namespace = 'io.github.tastelessjolt.flutterdynamicicon'/\" \"$PLUGIN_DIR/build.gradle\" && echo '✅ 修复 namespace'; fi && JAVA_FILE=\"$PLUGIN_DIR/src/main/java/io/github/tastelessjolt/flutterdynamicicon/FlutterDynamicIconPlugin.java\" && if [ -f \"$JAVA_FILE\" ]; then perl -i -0pe 's/public static void registerWith[^}]*\}//gs' \"$JAVA_FILE\" && echo '✅ 修复 v1 embedding'; fi; fi && echo '🏗️  构建 APK...' && flutter build apk --release --verbose && echo '📋 构建产物列表：' && find build -name '*.apk' -type f"

if errorlevel 1 (
    echo ❌ APK 构建失败
    exit /b 1
)

REM 检查构建结果
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
if exist "%APK_PATH%" (
    echo ✅ APK 构建成功！
    echo 📦 文件位置: %APK_PATH%
    for %%A in ("%APK_PATH%") do echo 📏 文件大小: %%~zA 字节
) else (
    echo ❌ APK 构建失败，未找到输出文件
    exit /b 1
)

echo.
echo 构建完成！
pause
