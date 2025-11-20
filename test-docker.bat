@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 🧪 测试 Docker 环境

REM 检查 Docker 是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker 未运行
    pause
    exit /b 1
)

echo ✅ Docker 正在运行

REM 测试简单命令
echo.
echo 📋 测试 Docker 挂载和基本命令...
docker run --rm -v "%cd%:/app" -w /app ubuntu:22.04 bash -c "pwd && ls -la && echo '✅ 挂载成功'"

if errorlevel 1 (
    echo ❌ Docker 挂载测试失败
    pause
    exit /b 1
)

echo.
echo ✅ 所有测试通过
pause
