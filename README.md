# xmusic

一个基于阿里云盘Auth2.0的音乐播放器应用，支持Android和iOS平台，提供优雅的音乐播放体验。

## 🎵 特点

- **多平台支持**：Android/iOS 双端适配
- **阿里云盘集成**：通过Auth2.0授权，直接访问阿里云盘音乐文件
- **精美UI设计**：采用现代化设计语言，流畅的动画效果
- **丰富的音乐功能**：默认阿里云盘存储目录结构，支持自建歌单，收藏歌单管理等
- **多种音频格式支持**：MP3, FLAC, AAC, WAV等
- **音频可视化**：动态音频波形展示
- **背景播放**：支持后台服务播放

注意：由于阿里云盘免费用户的网速限制和地址的有效性，首次播放可能只是下载，下载成功后可播放，加上速度上的限制。下载进程同时只能下载三个任务。希望有同道中人可以帮忙优化为后台下载。

## 🛠 技术栈

- **Flutter**：跨平台移动应用开发框架
- **Dart**：编程语言
- **GetX**：状态管理和路由管理
- **Just Audio**：音频播放库
- **Cached Network Image**：网络图片缓存
- **Flutter SVG**：SVG图片支持
- **Shared Preferences**：本地数据存储
- **Dio**：网络请求
- **Hive**：轻量级数据库
- **Animation**：动画效果支持

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/xmusic.git
cd xmusic
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 配置阿里云盘API

在项目中找到配置文件，填写阿里云盘的Client ID和Client Secret：

```dart
// lib/services/aliyun_api.dart
const String clientId = 'your-client-id';
const String clientSecret = 'your-client-secret';
const String redirectUri = 'your-redirect-uri';
```

### 4. 运行项目

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

## 📦 项目结构

```
├── android/              # Android平台代码
├── ios/                  # iOS平台代码
├── lib/                  # Flutter核心代码
│   ├── controllers/      # GetX控制器
│   ├── services/         # 服务层
│   ├── ui/               # UI层
│   │   ├── components/   # 通用组件
│   │   └── pages/        # 页面
│   ├── app.dart          # 应用入口
│   └── main.dart         # 主入口
├── assets/               # 静态资源
│   ├── audio/            # 音频文件
│   ├── fonts/            # 字体文件
│   └── images/           # 图片文件
├── pubspec.yaml          # 项目依赖
└── README.md             # 项目说明
```

## 🎨 功能特性

### 音乐播放
- 本地音乐扫描与播放
- 网络音乐在线播放
- 支持播放列表管理
- 播放模式切换（顺序/随机/单曲循环）
- 进度条拖拽调整
- 音量控制

### 阿里云盘集成
- Auth2.0授权登录
- 文件列表浏览
- 音乐文件筛选
- 在线播放与下载
- 文件夹管理

### 用户界面
- 启动页动画
- 首页推荐
- 分类列表
- 搜索功能
- 个人中心
- 主题切换

### 其他功能
- 音频可视化
- 歌词显示（支持本地和在线歌词）
- 睡眠定时器
- 耳机控制
- 通知栏控制

## 🤝 贡献指南

欢迎各位开发者贡献代码！请按照以下步骤进行：

1. Fork 仓库
2. 创建 Feat_xxx 分支
3. 提交代码
4. 创建 Pull Request

### 开发规范

- 代码风格：遵循Dart官方代码风格指南
- 提交信息：清晰明了，使用英文
- 注释：关键代码添加注释
- 测试：新功能添加测试用例

## 📄 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。

## 📞 联系方式

- 作者：荧惑
- Email：root@dsnbc.com
- 项目地址：https://github.com/luciferor/xmusic
- 安卓体验地址：https://music.dsnbc.com

## 🎨 开发工具
- vscode
### 启动页管理

```bash
# 生成启动页
dart run flutter_native_splash:create

# 恢复默认启动页
dart run flutter_native_splash:remove
```

## 🙏 致谢

感谢所有为项目做出贡献的开发者！

---

**如果喜欢这个项目，请给个 Star ⭐ 支持一下！**