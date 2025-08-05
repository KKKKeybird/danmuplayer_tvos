# DanmuPlayer tvOS

[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://developer.apple.com/tvos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

一个适用于 Apple TV 的弹幕播放器应用，支持 WebDAV 媒体库管理、弹弹Play API 集成和实时弹幕显示。

## 🎯 功能说明

1. **主页媒体库选择页面** ✅
   - 支持多个 WebDAV 地址配置
   - 媒体库配置持久化存储
   - 连接状态实时检测

2. **文件列表界面** ✅
   - 内部文件浏览功能
   - 右上角排序选项（名称、日期、大小）
   - 文件类型图标区分

3. **自动番剧识别** ✅
   - 点击视频文件自动调用弹弹Play API
   - 基于文件名识别番剧
   - 自动加载对应弹幕数据

4. **视频播放功能** ✅
   - 流媒体播放视频文件
   - 自动加载同目录字幕文件
   - tvOS 大屏幕优化界面

5. **弹幕系统** ✅
   - 实时弹幕渲染
   - 可调节透明度、字体大小、滚动速度
   - 支持滚动、顶部、底部弹幕类型

6. **番剧识别列表** ✅
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
- `DanDanPlayAPI`：弹弹Play API 封装
- `NetworkError`：统一错误处理

#### 数据模型
- `MediaLibraryConfig`：媒体库配置
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
- `FileListView`：文件浏览界面
- `VideoPlayerView`：视频播放器
- `DanmakuSettingsView`：弹幕设置面板

## 🎮 使用流程

1. **配置媒体库**：添加 WebDAV 服务器地址和认证信息
2. **浏览文件**：进入媒体库，浏览视频文件目录
3. **播放视频**：点击视频文件自动识别番剧并开始播放
4. **调整弹幕**：使用设置面板自定义弹幕显示效果
5. **手动选择番剧**：如识别错误，可手动选择正确的番剧

## 🚀 技术特性

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
│   │   ├── MediaLibraryConfig.swift
│   │   ├── MediaLibraryConfigManager.swift
│   │   └── WebDAVItem.swift
│   ├── Networking/                     # 网络层
│   │   ├── DanDanPlayAPI.swift
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
│       ├── MediaLibraryConfigView.swift
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