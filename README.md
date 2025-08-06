# DanmuPlayer tvOS

[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://developer.apple.com/tvos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

一个适用于 Apple TV 的弹幕播放器应用，支持 WebDAV 和 Jellyfin 媒体库管理、弹弹Play API 集成和实时弹幕显示。

## ✨ 核心特性

🎬 **双媒体服务器支持** - 同时支持 WebDAV 文件服务器和 Jellyfin 媒体服务器  
🎭 **智能弹幕匹配** - 集成弹弹Play API，自动识别动漫并加载弹幕  
📱 **现代化界面** - 专为 tvOS 优化的用户界面，支持遥控器操作  
🎯 **灵活配置** - 支持多服务器管理，用户可自由选择连接方式  
⚡ **流畅播放** - 无需下载，直接播放网络视频内容

## 🎯 功能说明

1. **主页媒体库选择页面** ✅
   - 支持多个 WebDAV 和 Jellyfin 服务器配置
   - 智能服务器类型检测和标识
   - 媒体库配置持久化存储
   - 连接状态实时检测

2. **双服务器类型支持** ✅
   - **WebDAV 模式**：传统文件浏览器界面
   - **Jellyfin 模式**：现代媒体库海报墙界面
   - 用户可在配置时选择服务器类型

3. **文件列表界面** ✅
   - 内部文件浏览功能
   - 右上角排序选项（名称、日期、大小）
   - 文件类型图标区分

4. **媒体库界面** ✅
   - Jellyfin 媒体库海报展示
   - 电影和电视剧分类浏览
   - 季度和集数智能组织
   - 观看进度和收藏状态显示

5. **自动番剧识别** ✅
   - 点击视频文件自动调用弹弹Play API
   - 支持基于文件名和Jellyfin元数据的识别
   - 自动加载对应弹幕数据

6. **视频播放功能** ✅
   - 流媒体播放视频文件
   - 支持WebDAV直链和Jellyfin转码流
   - 自动加载同目录字幕文件
   - tvOS 大屏幕优化界面

7. **弹幕系统** ✅
   - 实时弹幕渲染
   - 可调节透明度、字体大小、滚动速度
   - 支持滚动、顶部、底部弹幕类型

8. **番剧识别列表** ✅
   - 手动调用番剧识别列表 API
   - 用户可选择正确的番剧匹配
   - 更新识别结果和弹幕匹配

## 📚 API 参考
弹弹Play API 说明文档：https://doc.dandanplay.com/open/

## 🏗️ 项目架构

### 技术栈
- **平台**：tvOS 17.0+
- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI
- **架构模式**：MVVM
- **数据绑定**：Combine
- **视频播放**：AVFoundation

### 核心组件

#### 网络层
- `WebDAVClient`：WebDAV 协议实现
- `JellyfinClient`：Jellyfin API 客户端
- `DanDanPlayAPI`：弹弹Play API 封装
- `NetworkError`：统一错误处理

#### 数据模型
- `MediaLibraryConfig`：媒体库配置（支持双服务器类型）
- `MediaLibraryServerType`：服务器类型枚举
- `JellyfinModels`：Jellyfin API 数据模型集合
- `DanmakuComment`：弹幕数据模型
- `DanDanPlaySeries`：番剧信息模型
- `Credentials`：认证信息模型
- `WebDAVItem`：WebDAV 文件项模型

#### 视图模型
- `MediaLibraryViewModel`：媒体库管理
- `FileBrowserViewModel`：文件浏览逻辑
- `VideoPlayerViewModel`：视频播放控制

#### 视图组件
- `MediaLibraryListView`：媒体库选择主页
- `MediaLibraryConfigView`：媒体库配置界面（支持双服务器类型）
- `FileListView`：WebDAV 文件浏览界面
- `MediaLibraryHomeView`：Jellyfin 媒体库主页
- `MediaDetailView`：媒体详情页面
- `VideoPlayerView`：视频播放器
- `DanmakuSettingsView`：弹幕设置面板

## 🎮 使用流程

### WebDAV 模式
1. **配置媒体库**：选择 WebDAV 类型，添加服务器地址和认证信息
2. **浏览文件**：进入媒体库，浏览视频文件目录
3. **播放视频**：点击视频文件自动识别番剧并开始播放

### Jellyfin 模式
1. **配置媒体库**：选择 Jellyfin 类型，添加服务器地址和用户凭据
2. **浏览内容**：进入媒体库，查看电影和电视剧海报墙
3. **选择播放**：点击媒体项目查看详情，选择集数播放

### 通用功能
4. **调整弹幕**：使用设置面板自定义弹幕显示效果
5. **手动选择番剧**：如识别错误，可手动选择正确的番剧

## 🚀 技术特性

- **双服务器支持**：灵活选择 WebDAV 或 Jellyfin 媒体服务器
- **统一播放体验**：两种服务器类型都支持完整的弹幕功能
- **智能媒体识别**：根据服务器类型采用不同的媒体信息提取策略
- **流媒体播放**：无需下载，直接播放网络视频
- **实时弹幕**：高性能弹幕渲染系统
- **自动字幕**：智能识别并加载字幕文件
- **响应式UI**：适配 Apple TV 遥控器操作
- **错误恢复**：完善的网络异常处理机制

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
   - 在 Xcode 中打开 `danmuplayer/Utilities/DanDanPlayConfig.swift`
   - 替换占位符为您的真实 API 密钥：
   ```swift
   static let appId: String = "你的AppId"
   private static let appSecret: String = "你的AppSecret"
   ```
   - **获取 API 密钥**：发送邮件至 kaedei@dandanplay.net，主题为"弹弹play开放平台申请"

4. **配置媒体服务器**（二选一或都配置）
   
   **WebDAV 服务器配置：**
   - 服务器地址：如 `http://192.168.1.100:8080/dav`
   - 用户名和密码（如果需要认证）
   
   **Jellyfin 服务器配置：**
   - 服务器地址：如 `http://192.168.1.100:8096`
   - Jellyfin 用户名和密码

4. **选择目标设备**
   - 在 Xcode 中选择 Apple TV 模拟器或真机
   - 确保选择了正确的 tvOS 部署目标

5. **构建和运行**
   - 点击 Xcode 中的 Run 按钮 (⌘+R)
   - 或使用快捷键 ⌘+B 仅构建项目

6. **运行测试**
   - 在 Xcode 中使用 ⌘+U 运行测试套件
   - 或在 Test Navigator 中运行特定测试

### 开发规范

- 使用 MVVM 架构模式
- 保持 API 密钥安全，不要硬编码到源代码中
- 编写单元测试覆盖核心功能
- 使用有意义的提交信息
- 遵循 Swift 编码规范和最佳实践

## 🔐 安全注意事项

1. **API 密钥管理**
   - 不要将真实的 AppId 和 AppSecret 提交到公开仓库
   - 使用环境变量或安全的配置管理
   - 发布前进行代码混淆
   - 建议在本地开发时使用单独的配置文件

2. **申请 DanDanPlay API 密钥**
   - 邮箱：kaedei@dandanplay.net
   - 主题：弹弹play开放平台申请
   - 说明：tvOS应用开发用途

## 📂 项目结构

```
danmuplayer_tvos/
├── danmuplayer/                         # 主应用目录
│   ├── danmuplayerApp.swift            # 应用入口
│   ├── ContentView.swift               # 主视图
│   ├── Assets.xcassets/                # 应用资源文件
│   ├── Models/                         # 数据模型
│   │   ├── Credentials.swift
│   │   ├── DanDanPlaySeries.swift
│   │   ├── DanmakuComment.swift
│   │   ├── JellyfinModels.swift
│   │   ├── MediaLibraryConfig.swift
│   │   ├── MediaLibraryConfigManager.swift
│   │   └── WebDAVItem.swift
│   ├── Networking/                     # 网络层
│   │   ├── DanDanPlayAPI.swift
│   │   ├── JellyfinClient.swift
│   │   ├── NetworkError.swift
│   │   ├── WebDAVClient.swift
│   │   └── WebDAVParser.swift
│   ├── Utilities/                      # 工具类
│   │   ├── DanDanPlayCache.swift
│   │   ├── DanDanPlayConfig.swift
│   │   ├── DanmakuParser.swift
│   │   ├── FileInfoExtractor.swift
│   │   └── XMLParserHelper.swift
│   ├── ViewModels/                     # 视图模型
│   │   ├── FileBrowserViewModel.swift
│   │   ├── MediaLibraryViewModel.swift
│   │   └── VideoPlayerViewModel.swift
│   └── Views/                          # 用户界面
│       ├── DanmakuSettingsView.swift
│       ├── FileListView.swift
│       ├── MediaDetailView.swift
│       ├── MediaLibraryConfigView.swift
│       ├── MediaLibraryHomeView.swift
│       ├── MediaLibraryListView.swift
│       ├── SeriesSelectionView.swift
│       ├── VideoPlayerContainer.swift
│       └── VideoPlayerView.swift
├── danmuplayerTests/                   # 单元测试
│   └── danmuplayerTests.swift
├── danmuplayerUITests/                 # UI 测试
│   ├── danmuplayerUITests.swift
│   └── danmuplayerUITestsLaunchTests.swift
├── danmuplayer.xcodeproj/              # Xcode 项目文件
├── Package.swift                       # Swift Package 配置
└── README.md                          # 项目说明文档
```

## 📖 相关文档

- [DanDanPlay API 文档](https://doc.dandanplay.com/open/) - 弹弹Play 开放平台 API 说明
- [Jellyfin API 文档](https://api.jellyfin.org/) - Jellyfin 媒体服务器 API 参考
- [Apple tvOS 开发指南](https://developer.apple.com/tvos/) - Apple 官方 tvOS 开发文档
- [SwiftUI 框架文档](https://developer.apple.com/xcode/swiftui/) - SwiftUI 用户界面框架
- [AVFoundation 文档](https://developer.apple.com/av-foundation/) - 音视频播放框架

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。请在提交前确保：

1. 代码符合 Swift 编码规范
2. 已测试核心功能正常工作
3. 更新相关文档
4. 不包含敏感信息（如 API 密钥）

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。