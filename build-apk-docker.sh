#!/bin/bash

set -e

echo "🚀 使用 Docker 构建 APK"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker 未运行，请先启动 Docker${NC}"
    exit 1
fi

# 构建 Docker 镜像
echo -e "${YELLOW}📦 构建 Docker 镜像...${NC}"
docker build -t flutter-builder:latest .

# 检查是否存在签名密钥
KEYSTORE_FILE="android/upload-keystore.jks"
KEY_PROPERTIES="android/key.properties"

if [ -f "$KEYSTORE_FILE" ] && [ -f "$KEY_PROPERTIES" ]; then
    echo -e "${GREEN}✅ 找到签名配置，将构建发布版 APK${NC}"
    SIGNING_CONFIGURED=true
else
    echo -e "${YELLOW}⚠️  未找到签名配置，将构建调试版 APK${NC}"
    echo -e "${YELLOW}提示：如需发布版本，请先配置签名密钥${NC}"
    SIGNING_CONFIGURED=false
fi

# 运行 Docker 容器并构建 APK
echo -e "${YELLOW}🔨 开始构建 APK...${NC}"
docker run --rm \
    -v "$(pwd):/app" \
    -w /app \
    flutter-builder:latest \
    bash -c "
        set -e
        echo '📥 安装依赖...'
        flutter pub get
        
        echo '🧹 清理构建缓存...'
        flutter clean
        rm -rf android/.gradle
        rm -rf android/build
        rm -rf android/app/build
        
        echo '🔧 修复插件问题...'
        PLUGIN_DIR=\"\${HOME}/.pub-cache/hosted/pub.dev/flutter_dynamic_icon-2.1.0/android\"
        if [ -d \"\$PLUGIN_DIR\" ]; then
            if [ -f \"\$PLUGIN_DIR/build.gradle\" ]; then
                sed -i \"s/apply plugin: 'com.android.library'/apply plugin: 'com.android.library'\nandroid.namespace = 'io.github.tastelessjolt.flutterdynamicicon'/\" \"\$PLUGIN_DIR/build.gradle\"
                echo '✅ 修复 namespace'
            fi
            
            JAVA_FILE=\"\$PLUGIN_DIR/src/main/java/io/github/tastelessjolt/flutterdynamicicon/FlutterDynamicIconPlugin.java\"
            if [ -f \"\$JAVA_FILE\" ]; then
                perl -i -0pe 's/public static void registerWith[^}]*\}//gs' \"\$JAVA_FILE\"
                echo '✅ 修复 v1 embedding'
            fi
        fi
        
        echo '🏗️  构建 APK...'
        flutter build apk --release --verbose
        
        echo '📋 构建产物列表：'
        find build -name '*.apk' -type f
    "

# 检查构建结果
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo -e "${GREEN}✅ APK 构建成功！${NC}"
    echo -e "${GREEN}📦 文件位置: $APK_PATH${NC}"
    echo -e "${GREEN}📏 文件大小: $APK_SIZE${NC}"
    
    # 显示 APK 信息
    if command -v aapt &> /dev/null; then
        echo -e "\n${YELLOW}📱 APK 信息：${NC}"
        aapt dump badging "$APK_PATH" | grep -E "package:|application-label:|sdkVersion:|targetSdkVersion:"
    fi
else
    echo -e "${RED}❌ APK 构建失败，未找到输出文件${NC}"
    exit 1
fi
