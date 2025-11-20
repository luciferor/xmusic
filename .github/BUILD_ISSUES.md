# GitHub Actions 构建问题诊断

## 当前问题

### 错误信息
```
Gradle build failed to produce an .apk file.
The daemon has terminated unexpectedly on startup attempt #1 with error code: 0
```

### 可能原因

1. **Kotlin Daemon 崩溃**
   - Kotlin 编译守护进程启动失败
   - 可能是内存不足或配置问题

2. **Gradle 构建失败但没有明确错误**
   - 构建过程中断但没有抛出异常
   - 可能是插件兼容性问题

3. **没有签名配置**
   - 使用 debug 签名可能导致某些构建步骤失败

## 解决方案

### 方案 1: 调整 Gradle 配置

修改 `android/gradle.properties`：

```properties
# 增加内存
org.gradle.jvmargs=-Xmx6G -XX:MaxMetaspaceSize=2G

# 启用 daemon（GitHub Actions 环境可能需要）
org.gradle.daemon=true

# Kotlin 配置
kotlin.compiler.execution.strategy=daemon
kotlin.daemon.enabled=true
kotlin.daemon.jvmargs=-Xmx2G
```

### 方案 2: 配置签名密钥

在 GitHub Secrets 中添加：
- `KEYSTORE_BASE64` - 密钥库的 Base64 编码
- `KEYSTORE_PASSWORD` - 密钥库密码
- `KEY_PASSWORD` - 密钥密码
- `KEY_ALIAS` - 密钥别名

生成密钥：
```bash
node gen_keystore.js
```

### 方案 3: 简化构建配置

1. 移除不必要的插件
2. 更新依赖版本
3. 检查 `flutter_dynamic_icon` 插件兼容性

### 方案 4: 使用不同的构建方式

尝试使用 `--debug` 模式：
```bash
flutter build apk --debug
```

或者分步构建：
```bash
cd android
./gradlew assembleRelease --stacktrace --info
```

## 调试步骤

1. **查看完整日志**
   - 下载 `build-log` artifact
   - 搜索 "FAILURE" 或 "error:" 关键词

2. **检查 Gradle 输出**
   ```bash
   cd android
   ./gradlew assembleRelease --stacktrace --debug > gradle.log 2>&1
   ```

3. **验证环境**
   - Java 版本: 17
   - Flutter 版本: stable
   - Gradle 版本: 检查 `android/gradle/wrapper/gradle-wrapper.properties`

## 临时解决方案

如果 GitHub Actions 持续失败，可以：

1. **使用 Docker 本地构建**
   ```bash
   .\build-apk-docker.bat
   ```

2. **手动构建**
   ```bash
   flutter build apk --release
   ```

3. **使用其他 CI 服务**
   - GitLab CI
   - CircleCI
   - Codemagic (专为 Flutter 优化)

## 相关链接

- [Flutter Build APK 文档](https://docs.flutter.dev/deployment/android)
- [Gradle 配置优化](https://docs.gradle.org/current/userguide/build_environment.html)
- [Kotlin Daemon 问题](https://youtrack.jetbrains.com/issue/KT-48843)
