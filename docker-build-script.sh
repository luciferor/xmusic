#!/bin/bash
set -e

echo "=========================================="
echo "开始 Flutter APK 构建流程"
echo "=========================================="

echo ""
echo "📥 安装依赖..."
flutter pub get || {
    echo "❌ 依赖安装失败"
    exit 1
}

echo ""
echo "🧹 清理构建缓存..."
flutter clean
rm -rf android/.gradle
rm -rf android/build
rm -rf android/app/build
rm -rf build

echo ""
echo "🔧 修复插件问题..."
PLUGIN_DIR="${HOME}/.pub-cache/hosted/pub.dev/flutter_dynamic_icon-2.1.0/android"

if [ -d "$PLUGIN_DIR" ]; then
    echo "找到插件目录: $PLUGIN_DIR"
    
    if [ -f "$PLUGIN_DIR/build.gradle" ]; then
        sed -i "s/apply plugin: 'com.android.library'/apply plugin: 'com.android.library'\nandroid.namespace = 'io.github.tastelessjolt.flutterdynamicicon'/" "$PLUGIN_DIR/build.gradle"
        echo "✅ 修复 namespace"
    fi
    
    JAVA_FILE="$PLUGIN_DIR/src/main/java/io/github/tastelessjolt/flutterdynamicicon/FlutterDynamicIconPlugin.java"
    if [ -f "$JAVA_FILE" ]; then
        perl -i -0pe 's/public static void registerWith[^}]*\}//gs' "$JAVA_FILE"
        echo "✅ 修复 v1 embedding"
    fi
else
    echo "⚠️  未找到插件目录，跳过修复"
fi

echo ""
echo "🏗️  开始构建 APK..."
echo "=========================================="

# 构建 APK 并捕获输出
if flutter build apk --release --verbose 2>&1 | tee build.log; then
    echo ""
    echo "=========================================="
    echo "✅ Flutter 构建命令执行完成"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "❌ Flutter 构建命令失败"
    echo "=========================================="
    echo "最后 50 行日志："
    tail -n 50 build.log
    exit 1
fi

echo ""
echo "📋 检查构建目录结构..."
echo "----------------------------------------"
ls -la build/ 2>/dev/null || echo "build/ 目录不存在"
ls -la build/app/ 2>/dev/null || echo "build/app/ 目录不存在"
ls -la build/app/outputs/ 2>/dev/null || echo "build/app/outputs/ 目录不存在"
ls -la build/app/outputs/flutter-apk/ 2>/dev/null || echo "build/app/outputs/flutter-apk/ 目录不存在"
ls -la build/app/outputs/apk/release/ 2>/dev/null || echo "build/app/outputs/apk/release/ 目录不存在"

echo ""
echo "🔍 搜索所有 APK 文件..."
echo "----------------------------------------"
if find build -name "*.apk" -type f 2>/dev/null; then
    echo ""
    echo "✅ 找到 APK 文件"
    find build -name "*.apk" -type f -exec ls -lh {} \;
else
    echo "❌ 未找到任何 APK 文件"
    echo ""
    echo "完整 build 目录结构："
    find build -type f 2>/dev/null || echo "build 目录为空或不存在"
    exit 1
fi

echo ""
echo "=========================================="
echo "构建流程完成"
echo "=========================================="
