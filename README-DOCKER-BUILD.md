# 使用 Docker 构建 APK

## 前提条件

1. 已安装 Docker Desktop
2. Docker 服务正在运行

## 快速开始

### Windows 用户

直接双击运行：
```
build-apk-docker.bat
```

或在 PowerShell/CMD 中执行：
```bash
.\build-apk-docker.bat
```

### Linux/Mac 用户

```bash
chmod +x build-apk-docker.sh
./build-apk-docker.sh
```

## 构建流程

脚本会自动完成以下步骤：

1. **构建 Docker 镜像** - 包含 Flutter SDK、Android SDK 和所有必要工具
2. **安装依赖** - 运行 `flutter pub get`
3. **清理缓存** - 清理之前的构建产物
4. **修复插件问题** - 自动修复 `flutter_dynamic_icon` 插件的兼容性问题
5. **构建 APK** - 执行 `flutter build apk --release`
6. **输出结果** - 显示 APK 文件位置和大小

## 构建产物

成功构建后，APK 文件位于：
```
build/app/outputs/flutter-apk/app-release.apk
```

## 签名配置

### 发布版本（推荐）

如果需要构建可发布的签名版本，请确保以下文件存在：

1. `android/upload-keystore.jks` - 签名密钥文件
2. `android/key.properties` - 签名配置文件

可以使用 `gen_keystore.js` 生成密钥：
```bash
npm install
node gen_keystore.js
```

然后创建 `android/key.properties`：
```properties
storePassword=你的密码
keyPassword=你的密码
keyAlias=upload
storeFile=upload-keystore.jks
```

### 调试版本

如果没有签名配置，脚本会自动构建调试版本（不适合发布到应用商店）。

## 手动构建（高级）

如果需要更多控制，可以手动执行：

```bash
# 1. 构建镜像
docker build -t flutter-builder:latest .

# 2. 运行容器并进入交互式 shell
docker run -it --rm -v "%cd%:/app" -w /app flutter-builder:latest bash

# 3. 在容器内执行构建命令
flutter pub get
flutter clean
flutter build apk --release
```

## 常见问题

### Docker 镜像构建时间长

首次构建镜像需要下载 Flutter SDK 和 Android SDK，可能需要 10-30 分钟。
后续构建会使用缓存，速度会快很多。

### 构建失败

1. 确保 Docker 有足够的内存（建议至少 4GB）
2. 检查网络连接，确保可以访问 Google 服务
3. 查看构建日志中的错误信息

### 修改 Docker 配置

编辑 `Dockerfile` 可以自定义：
- Flutter 版本（修改 `-b stable` 为其他分支）
- Android SDK 版本
- Java 版本

## 优势

✅ **环境隔离** - 不影响本地开发环境  
✅ **可重现构建** - 每次构建环境一致  
✅ **跨平台** - Windows/Mac/Linux 都可以使用  
✅ **自动化** - 一键完成所有构建步骤  
✅ **CI/CD 友好** - 可轻松集成到 CI/CD 流程

## 与 GitHub Actions 的区别

| 特性 | Docker 本地构建 | GitHub Actions |
|------|----------------|----------------|
| 构建速度 | 快（本地资源） | 较慢（网络传输） |
| 调试便利性 | 高 | 低 |
| 成本 | 免费 | 免费（有限额） |
| 适用场景 | 开发测试 | 自动化发布 |

建议：开发阶段使用 Docker 本地构建，发布时使用 GitHub Actions。
