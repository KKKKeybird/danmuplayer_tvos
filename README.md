# DanmuPlayer tvOS

[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://developer.apple.com/tvos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![VLCKit](https://img.shields.io/badge/VLCKit-4.0+-red.svg)](https://code.videolan.org/videolan/VLCKit)

一个功能完整的 Apple TV 弹幕播放器应用，支持 WebDAV 和 Jellyfin 双媒体服务器，集成弹弹Play API 提供智能弹幕匹配功能。

## 🎯 核心功能

### 📺 双服务器支持
- **WebDAV 服务器**: 传统文件浏览模式，支持目录导航和文件管理
- **Jellyfin 服务器**: 现代媒体库模式，提供海报墙和元数据管理
- **统一体验**: 两种服务器类型提供一致的播放和弹幕功能

### 🎬 统一媒体架构
基于"将电影和剧集都处理为类剧集结构"的设计理念：
- **电影处理**: 电影被当作只有一季一集的剧集来处理
- **剧集处理**: 保持原有的多季多集结构  
- **界面统一**: 所有媒体项目都使用相同的详情页和播放流程

### �‍♀️ 智能弹幕系统
- **自动识别**: 基于文件信息的智能弹幕匹配
- **手动选择**: 识别失败时提供候选剧集列表
- **实时渲染**: 高性能弹幕显示系统，支持滚动、顶部、底部弹幕
- **自定义设置**: 可调节透明度、字体大小、滚动速度和弹幕密度

### 📱 现代化播放器
- **VLCUI集成**: 基于SwiftUI的现代化播放器界面
- **双字幕系统**: 同时支持原生字幕和弹幕字幕轨道
- **智能字幕**: 自动识别和加载字幕文件，支持多种格式
- **响应式控制**: 适配Apple TV遥控器的直观操作体验

## ️ 技术架构

### 技术栈
- **平台**: tvOS 17.0+
- **语言**: Swift 5.9+
- **UI框架**: SwiftUI + MVVM架构
- **播放器**: VLCKitSPM + VLCUI
- **数据绑定**: Combine响应式编程
- **网络**: WebDAV协议 + Jellyfin API
- **弹幕**: 弹弹Play开放平台API

### 核心组件架构

#### 🗂️ 数据模型层 (Models)
- **MediaLibraryConfig**: 统一的媒体库配置模型，支持WebDAV和Jellyfin
- **JellyfinModels**: 完整的Jellyfin API数据模型
- **DanDanPlayModels**: 弹弹Play API数据结构
- **WebDAVModels**: WebDAV协议数据模型

#### 🔧 工具服务层 (Utilities)
- **网络客户端**: `WebDAVClient`、`JellyfinClient`、`DanDanPlayAPI`
- **缓存系统**: `JellyfinCache`、`DanDanPlayCache` 多级缓存策略
- **弹幕处理**: `DanmakuParser`、`DanmakuToSubtitleConverter`、`VLCSubtitleTrackManager`
- **文件处理**: `FileInfoExtractor`、`XMLParserHelper`

#### 🎬 视图模型层 (ViewModels)  
- **MediaLibraryViewModel**: 主媒体库管理
- **FileBrowserViewModel**: WebDAV文件浏览逻辑
- **JellyfinMediaLibraryViewModel**: Jellyfin媒体库管理

#### 🖥️ 用户界面层 (Views)
- **MediaLibraryViews**: 媒体库主界面和配置
- **WebDAVLibraryViews**: WebDAV文件浏览界面
- **JellyfinLibraryViews**: Jellyfin海报墙界面
- **JellyfinMediaItemViews**: Jellyfin媒体详情界面
- **PlayerViews**: 统一的VLC播放器界面

## 🎮 使用流程

### WebDAV 模式
1. **配置媒体库**: 添加WebDAV服务器地址和认证信息
2. **浏览目录**: 进入媒体库，浏览文件目录结构
3. **播放视频**: 点击视频文件自动识别弹幕并开始播放

### Jellyfin 模式
1. **配置媒体库**: 选择Jellyfin类型，添加服务器地址和用户凭据
2. **浏览内容**: 进入媒体库，查看电影和电视剧海报墙
3. **选择播放**: 点击媒体项目查看详情，选择集数播放

### 通用功能
4. **调整弹幕**: 使用设置面板自定义弹幕显示效果
5. **手动选择番剧**: 如识别错误，可手动选择正确的番剧
6. **字幕管理**: 自动加载字幕文件，支持多轨道切换

## 🚀 技术特性

### 🔄 统一播放架构
- **双服务器支持**: 灵活选择WebDAV或Jellyfin媒体服务器
- **统一播放体验**: 两种服务器类型都支持完整的弹幕功能  
- **智能媒体识别**: 根据服务器类型采用不同的媒体信息提取策略
- **统一播放器创建**: 所有媒体源使用相同的`VLCPlayerContainer.create()`接口

### ⚡ 高性能系统
- **流媒体播放**: 无需下载，直接播放网络视频
- **多级缓存**: 媒体库、剧集、字幕、弹幕分层缓存策略
- **实时弹幕**: 高性能弹幕渲染系统，支持数千条弹幕同时显示
- **智能预缓存**: 批量缓存剧集元数据提升响应速度

### 🎨 现代化界面
- **响应式UI**: 完全基于SwiftUI和Combine的响应式设计
- **适配优化**: 专为Apple TV遥控器优化的交互体验
- **一致性设计**: 统一的视觉风格和交互模式
- **错误恢复**: 完善的网络异常处理和用户提示

## 🚧 开发和构建

### 环境要求
- **Xcode**: 15.2+ (支持 tvOS 17.0 开发)
- **Swift**: 5.9+
- **tvOS**: 17.0+
- **macOS**: 13.0+ (开发环境)

### 构建步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/your-username/danmuplayer_tvos.git
   cd danmuplayer_tvos
   ```

2. **使用 Xcode 打开项目**
   ```bash
   # 直接用 Xcode 打开项目
   open danmuplayer.xcodeproj
   # 或者双击项目文件
   ```

3. **配置API密钥**
   - 复制配置模板：
     ```bash
     cp danmuplayer/Utilities/Config/DanDanPlaySecrets.swift.template danmuplayer/Utilities/Config/DanDanPlaySecrets.swift
     ```
   - 编辑 `DanDanPlaySecrets.swift` 文件，替换占位符为您的真实 API 密钥：
     ```swift
     static let appId: String = "你的AppId"
     static let appSecret: String = "你的AppSecret"
     ```
   - **获取 API 密钥**：发送邮件至 kaedei@dandanplay.net，主题为"弹弹play开放平台申请"
   - 详细配置说明请参考：[DanDanPlay API 配置指南](DANDANPLAY_API_SETUP.md)

4. **配置媒体服务器**（二选一或都配置）
   
   **WebDAV服务器**:
   - 支持任何标准WebDAV协议的服务器
   - 推荐: Synology NAS、QNAP NAS、Apache WebDAV
   
   **Jellyfin服务器**:
   - 安装Jellyfin媒体服务器: https://jellyfin.org/downloads/
   - 创建用户账户并导入媒体库
   - 确保服务器网络可访问

5. **选择目标设备**
   - 在Xcode中选择Apple TV模拟器或真机
   - 确保选择了正确的tvOS部署目标

6. **构建和运行**
   - 点击Xcode中的Run按钮(⌘+R)
   - 或使用快捷键⌘+B仅构建项目

7. **运行测试**
   - 在Xcode中使用⌘+U运行测试套件
   - 或在Test Navigator中运行特定测试

### 开发规范

- 使用MVVM架构模式
- 保持API密钥安全，不要硬编码到源代码中
- 编写单元测试覆盖核心功能
- 使用有意义的提交信息
- 遵循Swift编码规范和最佳实践

## 🔐 安全注意事项

### API密钥管理
- **配置分离**: 敏感的AppId和AppSecret存储在单独的配置文件中
- **版本控制排除**: `DanDanPlaySecrets.swift`已被添加到`.gitignore`，不会被提交
- **模板提供**: 提供`DanDanPlaySecrets.swift.template`模板文件供开发者使用
- **发布前混淆**: 建议在发布前对代码进行混淆以防止密钥泄露

### 申请DanDanPlay API密钥
- **申请地址**: https://doc.dandanplay.com/open/#_3-%E7%94%B3%E8%AF%B7-appid-%E5%92%8C-appsecret
- **联系邮箱**: kaedei@dandanplay.net
- **邮件主题**: 弹弹play开放平台申请
- **说明用途**: tvOS弹幕播放器应用开发

## 📖 相关文档

- [项目API文档](项目API.md) - 详细的架构和API说明
- [DanDanPlay API配置指南](DANDANPLAY_API_SETUP.md) - API密钥配置说明
- [DanDanPlay API文档](https://doc.dandanplay.com/open/) - 弹弹Play开放平台API说明
- [Apple tvOS开发指南](https://developer.apple.com/tvos/) - Apple官方tvOS开发文档
- [SwiftUI框架文档](https://developer.apple.com/xcode/swiftui/) - SwiftUI用户界面框架
- [VLCKit文档](https://code.videolan.org/videolan/VLCKit) - VLC播放器框架
- [Jellyfin API文档](https://api.jellyfin.org/) - Jellyfin媒体服务器API

## 🌟 功能亮点

### 🎯 智能识别系统
- **文件信息提取**: 自动计算文件MD5哈希，获取视频时长和大小
- **多重识别策略**: 文件匹配API + 搜索API双重保障
- **缓存优化**: 用户手动选择的结果自动缓存，避免重复识别

### 🎨 用户体验优化
- **统一交互流程**: WebDAV和Jellyfin提供完全一致的操作体验
- **智能错误处理**: 详细的错误信息和解决建议
- **响应式设计**: 流畅的动画和即时的状态反馈
- **无障碍支持**: 完整的VoiceOver和键盘导航支持

### ⚡ 性能优化
- **异步架构**: 全面的异步编程，避免界面卡顿
- **内存管理**: 智能的缓存清理和内存优化
- **网络优化**: 请求合并、重试机制和连接池管理
- **渲染优化**: 高效的弹幕渲染算法和碰撞检测

## 📂 项目结构

```
danmuplayer_tvos/
├── danmuplayer/                        # 主应用目录
│   ├── danmuplayerApp.swift           # 应用入口
│   ├── ContentView.swift              # 主视图
│   ├── Assets.xcassets/               # 应用资源文件
│   ├── Models/                        # 数据模型
│   │   ├── MediaLibraryConfig.swift
│   │   ├── JellyfinModels/
│   │   │   ├── JellyfinModels.swift
│   │   │   └── JellyfinLibraryConfig.swift
│   │   ├── DanDanPlayModels/
│   │   │   ├── DanDanPlayEpisode.swift
│   │   │   └── DanmakuComment.swift
│   │   └── WebDAVModels/
│   │       ├── Credentials.swift
│   │       └── WebDAVItem.swift
│   ├── Utilities/                     # 工具类
│   │   ├── Config/
│   │   │   ├── DanDanPlayConfig.swift
│   │   │   ├── DanDanPlaySecrets.swift.template
│   │   │   └── DanDanPlaySecrets.swift (需要创建)
│   │   ├── Networking/
│   │   │   ├── WebDAVClient.swift
│   │   │   ├── JellyfinClient.swift
│   │   │   ├── DanDanPlayAPI.swift
│   │   │   └── NetworkError.swift
│   │   ├── CacheUtilities/
│   │   │   ├── JellyfinCache.swift
│   │   │   └── DanDanPlayCache.swift
│   │   ├── DanmaUtilities/
│   │   │   ├── DanmakuParser.swift
│   │   │   ├── DanmakuToSubtitleConverter.swift
│   │   │   └── VLCSubtitleTrackManager.swift
│   │   └── FileUtilities/
│   │       ├── FileInfoExtractor.swift
│   │       └── XMLParserHelper.swift
│   ├── ViewModels/                    # 视图模型
│   │   ├── MediaLibraryViewModel.swift
│   │   ├── FileBrowserViewModel.swift
│   │   └── JellyfinMediaLibraryViewModel.swift
│   └── Views/                         # 用户界面
│       ├── MediaLibraryViews/
│       │   ├── MediaLibraryListView.swift
│       │   └── Components/
│       │       └── MediaLibraryConfigView.swift
│       ├── WebDAVLibraryViews/
│       │   ├── FileListView.swift
│       │   └── Components/
│       │       └── WebDAVVideoPlayerWrapper.swift
│       ├── JellyfinLibraryViews/
│       │   ├── JellyfinMediaLibraryView.swift
│       │   └── Components/
│       │       ├── MediaItemCard.swift
│       │       └── JellyfinAuthenticationView.swift
│       ├── JellyfinMediaItemViews/
│       │   ├── JellyfinMediaDetailView.swift
│       │   └── Components/
│       │       ├── EpisodeCard.swift
│       │       └── JellyfinVideoPlayerWrapper.swift
│       └── PlayerViews/
│           ├── VLCPlayerContainer.swift
│           ├── VLCPlayerView.swift
│           └── VideoPlayerSettingsView.swift
├── danmuplayerTests/                  # 单元测试
│   └── danmuplayerTests.swift
├── danmuplayerUITests/                # UI测试
│   ├── danmuplayerUITests.swift
│   └── danmuplayerUITestsLaunchTests.swift
├── danmuplayer.xcodeproj/             # Xcode项目文件
├── DANDANPLAY_API_SETUP.md            # API配置指南
└── README.md                          # 项目说明文档
```

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。请在提交前确保：

1. 代码符合Swift编码规范
2. 已测试核心功能正常工作
3. 更新相关文档
4. 不包含敏感信息（如API密钥）

### 开发环境设置
1. 按照构建步骤设置开发环境
2. 创建功能分支: `git checkout -b feature/your-feature`
3. 提交更改: `git commit -m 'Add some feature'`
4. 推送分支: `git push origin feature/your-feature`
5. 创建Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看[LICENSE](LICENSE)文件了解详情。

## 🙏 致谢

- [弹弹Play](https://www.dandanplay.com/) - 提供弹幕API支持
- [VLC媒体播放器](https://www.videolan.org/vlc/) - 提供强大的媒体播放引擎
- [Jellyfin](https://jellyfin.org/) - 优秀的开源媒体服务器
- Apple - 提供优秀的tvOS开发平台

---

**注意**: 本项目仅供学习和个人使用，请遵守相关法律法规和服务条款。
