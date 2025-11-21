# Codemagic 构建修复说明

## 问题总结
在 Codemagic 上构建 Android APK 时遇到多个问题：
1. Gradle 版本自动升级到不存在的 8.13
2. AndroidX 依赖要求更高版本的 AGP
3. Java 版本不匹配（要求 Java 17，但可能使用了 Java 21）

## 解决方案

### 1. 版本配置
- **Android Gradle Plugin**: 8.9.1
- **Gradle Wrapper**: 8.11.1
- **Kotlin**: 2.1.0
- **Java**: 17

### 2. 修改的文件

#### `android/settings.gradle.kts`
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}
```

#### `android/gradle/wrapper/gradle-wrapper.properties`
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip
```

#### `android/gradle.properties`
添加了以下配置：
```properties
# 防止 Gradle 自动升级插件版本
android.overrideVersionCheck=true
android.suppressUnsupportedCompileSdk=34,35,36
```

#### `android/app/build.gradle`
确保 Java 版本为 17：
```gradle
compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = "17"
}
```

### 3. Codemagic 配置 (`codemagic.yaml`)

关键配置：
- 指定 `java: 17` 在 environment 中
- 在构建前强制设置正确的版本号
- 使用 `flutter build apk` 而不是直接调用 Gradle

### 4. 构建流程

1. **验证 Java 版本** - 确保使用 Java 17
2. **检查配置** - 验证 Gradle 和 AGP 版本
3. **强制版本** - 在构建前使用 sed 命令强制设置正确版本
4. **构建 APK** - 使用 Flutter 命令构建

## 提交和构建

1. 提交所有修改到 Git
2. 推送到远程仓库
3. Codemagic 会自动触发构建
4. 查看构建日志确认版本设置正确

## 注意事项

- 不要手动修改 Gradle 版本到 8.13（不存在）
- 确保 Java 17 在 Codemagic 环境中可用
- 如果仍有问题，检查构建日志中的 Java 版本输出
