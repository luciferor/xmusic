# 自动构建和签名指南

## 🚀 功能特性

### 1. 自动签名生成
- ✅ 如果没有配置 GitHub Secrets，会自动生成临时签名密钥
- ✅ 使用 `gen_keystore.js` 生成 PKCS#12 格式密钥库
- ⚠️ 临时密钥仅用于测试，不适合生产环境

### 2. 完整的 APK 信息输出
构建成功后会自动提取并输出：
- **Bundle ID** (Package Name)
- **版本号** (Version Name & Code)
- **应用名称**
- **SDK 版本** (Min & Target)
- **文件大小**
- **文件哈希** (MD5 & SHA256)
- **签名信息**
- **应用权限列表**
- **下载链接**

### 3. 多种输出方式

#### 控制台输出
在 Actions 日志中查看完整信息

#### APK 信息文件
下载 `apk-info.txt` artifact 查看详细信息

#### GitHub Summary
在 Actions 运行页面的 Summary 标签查看格式化的信息表格

## 📋 使用方法

### 方式 1: 使用临时签名（测试）

直接推送代码到 `main`、`master` 或 `dev` 分支，工作流会：
1. 自动安装 Node.js 和 node-forge
2. 运行 `gen_keystore.js` 生成临时密钥
3. 使用临时密钥签名并构建 APK
4. 输出所有应用信息

**临时签名配置：**
- 密码: `123456`
- 别名: `upload`
- 证书信息: Example User / MyCompany / CN

### 方式 2: 使用生产签名（推荐）

#### 步骤 1: 生成签名密钥

```bash
# 安装依赖
npm install node-forge

# 生成密钥
node gen_keystore.js
```

这会生成：
- `upload-keystore.p12` - 密钥库文件
- Base64 编码输出 - 用于 GitHub Secrets

#### 步骤 2: 配置 GitHub Secrets

在仓库设置中添加以下 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `KEYSTORE_BASE64` | 从 `gen_keystore.js` 输出复制 | 密钥库的 Base64 编码 |
| `KEYSTORE_PASSWORD` | `123456` (或自定义) | 密钥库密码 |
| `KEY_PASSWORD` | `123456` (或自定义) | 密钥密码 |
| `KEY_ALIAS` | `upload` (或自定义) | 密钥别名 |

**配置路径：**
```
仓库 → Settings → Secrets and variables → Actions → New repository secret
```

#### 步骤 3: 触发构建

推送代码或手动触发：
```bash
git push origin main
```

或在 GitHub Actions 页面点击 "Run workflow"

## 📥 下载 APK

### 方法 1: 从 Actions Artifacts 下载

1. 进入 [Actions](https://github.com/你的用户名/xmusic/actions) 页面
2. 点击最新的构建运行
3. 滚动到页面底部的 "Artifacts" 部分
4. 下载 `app-release` (APK 文件)
5. 下载 `apk-info` (应用信息)

### 方法 2: 查看 Summary

1. 进入 Actions 运行页面
2. 点击 "Summary" 标签
3. 查看格式化的应用信息表格
4. 点击下载链接

## 📊 输出信息示例

### 控制台输出
```
==========================================
📱 APK 信息提取
==========================================

APK 文件路径: build/app/outputs/flutter-apk/app-release.apk

📦 文件信息:
-rw-r--r-- 1 runner docker 45M Nov 20 12:00 app-release.apk
文件大小: 45M

📋 应用信息:
Bundle ID (Package Name): com.dsnbc.xmusic
Version Code: 1
Version Name: 1.0.0
应用名称: XMusic
Min SDK Version: 21
Target SDK Version: 36

📋 应用权限:
  - android.permission.INTERNET
  - android.permission.WAKE_LOCK
  - android.permission.FOREGROUND_SERVICE
  ...

🔐 签名信息:
Signer #1:
  CN=Example User, O=MyCompany, C=CN
  ...

🔑 文件哈希:
MD5: a1b2c3d4e5f6...
SHA256: 1a2b3c4d5e6f...
```

### apk-info.txt 内容
```
==========================================
APK 构建信息
==========================================

构建时间: Thu Nov 20 12:00:00 UTC 2025
构建分支: main
提交哈希: abc123def456...

文件信息:
- 路径: build/app/outputs/flutter-apk/app-release.apk
- 大小: 45M

应用信息:
- Bundle ID: com.dsnbc.xmusic
- 版本号: 1.0.0 (1)
- 应用名称: XMusic
- Min SDK: 21
- Target SDK: 36

文件哈希:
- MD5: a1b2c3d4e5f6...
- SHA256: 1a2b3c4d5e6f...

下载链接:
https://github.com/你的用户名/xmusic/actions/runs/123456789

==========================================
```

### GitHub Summary 表格

| 项目 | 值 |
|------|-----|
| **Bundle ID** | `com.dsnbc.xmusic` |
| **版本** | `1.0.0` |
| **文件大小** | 45M |
| **构建时间** | Thu Nov 20 12:00:00 UTC 2025 |

## 🔧 自定义签名配置

如果要自定义签名信息，编辑 `gen_keystore.js`：

```javascript
const alias = "your-alias";           // 修改别名
const password = "your-password";     // 修改密码
const cn = "Your Name";               // 修改证书信息
const o = "Your Company";
const c = "CN";
```

然后重新生成密钥并更新 GitHub Secrets。

## ⚠️ 注意事项

1. **临时签名的限制**
   - 每次构建生成新的密钥
   - 无法更新已安装的应用（签名不同）
   - 不适合发布到应用商店

2. **生产签名的要求**
   - 保管好密钥文件和密码
   - 不要将密钥提交到代码仓库
   - 定期备份密钥文件

3. **Artifacts 保留时间**
   - APK 文件保留 30 天
   - 构建日志保留 7 天

## 🐛 故障排查

### 构建失败
1. 查看 Actions 日志中的错误信息
2. 下载 `build-log` artifact 查看完整日志
3. 检查 Gradle 配置和依赖版本

### 签名失败
1. 确认 GitHub Secrets 配置正确
2. 检查密钥文件格式（应为 Base64 编码）
3. 验证密码和别名是否匹配

### APK 信息提取失败
1. 确认 APK 文件已生成
2. 检查 aapt 工具是否可用
3. 查看 "Extract APK information" 步骤的日志

## 📚 相关文档

- [Flutter 部署文档](https://docs.flutter.dev/deployment/android)
- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
