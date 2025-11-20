@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 🚀 使用 Docker 构建 APK

REM 检查 Docker 是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker 未运行，请先启动 Docker
    pause
    exit /b 1
)

REM 构建 Docker 镜像
echo 📦 构建 Docker 镜像...
docker build -t flutter-builder:latest .
if errorlevel 1 (
    echo ❌ Docker 镜像构建失败
    pause
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
echo.
docker run --rm -v "%cd%:/app" -w /app flutter-builder:latest bash /app/docker-build-script.sh

if errorlevel 1 (
    echo.
    echo ========================================
    echo ❌ APK 构建失败
    echo ========================================
    if exist "build.log" (
        echo.
        echo 查看完整日志: build.log
        echo 最后 30 行错误日志:
        echo ----------------------------------------
        powershell -Command "Get-Content build.log -Tail 30"
    )
    pause
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
    pause
    exit /b 1
)

echo.
echo 构建完成！
pause
