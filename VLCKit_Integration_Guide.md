# VLCKit 集成指南

## 📦 添加 VLCKit 依赖

# VLCKit 集成指南

## 🚨 重要更正

**Swift Package Manager 不支持！** VLC 官方目前只支持以下两种方式：

## 📦 添加 VLCKit 依赖

### 方法一：使用 CocoaPods (官方推荐) ✅ 安装完成！

🎉 **TVVLCKit 已成功安装！**

安装状态：
- ✅ Podfile 已创建
- ✅ TVVLCKit 3.6.0 已下载并安装
- ✅ danmuplayer.xcworkspace 已生成
- ✅ 项目依赖配置完成

**重要提醒：**
🔄 **从现在开始，必须使用 `danmuplayer.xcworkspace` 而不是 `danmuplayer.xcodeproj` 来打开项目！**

安装的 TVVLCKit 版本：3.6.0
Pod 位置：`./Pods/TVVLCKit/`

### 方法二：使用 Carthage (替代方案)

如果不想使用 CocoaPods，可以使用 Carthage：

1. 安装 Carthage：
   ```bash
   brew install carthage
   ```

2. 创建 `Cartfile`：
   ```
   binary "https://code.videolan.org/videolan/VLCKit/raw/master/Packaging/TVVLCKit.json" ~> 3.6.0
   ```

3. 安装依赖：
   ```bash
   carthage update
   ```

4. 手动将 framework 链接到项目中，并添加以下系统依赖：
   - AudioToolbox.framework
   - AVFoundation.framework
   - CFNetwork.framework
   - CoreFoundation.framework
   - CoreMedia.framework
   - CoreVideo.framework
   - libbz2.tbd
   - libc++.tbd
   - libiconv.tbd
   - OpenGLES.framework
   - QuartzCore.framework
   - Security.framework
   - VideoToolbox.framework
   - UIKit.framework

### 方法三：手动集成

1. 下载 TVVLCKit framework：
   ```bash
   https://get.videolan.org/vlc-ios/3.6.0/TVVLCKit-binary.zip
   ```

2. 将 framework 拖拽到项目中

3. 在项目设置中添加以下链接库：
   - `libc++.tbd`
   - `libz.tbd`
   - `libbz2.tbd`
   - `libiconv.tbd`
   - `CoreFoundation.framework`
   - `VideoToolbox.framework`
   - `AudioToolbox.framework`
   - `OpenGLES.framework`
   - `QuartzCore.framework`
   - `CoreVideo.framework`
   - `CoreMedia.framework`
   - `AVFoundation.framework`
   - `Security.framework`
   - `CFNetwork.framework`
   - `MobileCoreServices.framework`

## 🚀 VLCKit 的优势

### ✅ 支持的格式
- **视频格式**: MP4, MKV, AVI, MOV, FLV, WEBM, OGV, 3GP, ASF, WMV, MP2V
- **音频格式**: MP3, AAC, OGG, FLAC, APE, WMA, AC3, DTS
- **字幕格式**: SRT, ASS, SSA, VTT, SUB, IDX
- **流媒体**: HTTP, HTTPS, RTSP, RTMP, HLS, DASH

### ✅ 播放控制功能
- 精确的快进/快退控制 (按住加速)
- 可变播放速率 (0.25x - 4.0x)
- 音轨和字幕选择
- 章节导航
- 音量控制和静音
- 画面比例调整

### ✅ tvOS 特性
- 完整的遥控器支持
- 手势控制
- 画中画模式
- AirPlay 支持
- HDR 和杜比视界支持

## 🎮 遥控器控制映射

```swift
// 左右键：快进/快退
case .left:  seekBackward(seconds: 10)
case .right: seekForward(seconds: 10)

// 上下键：显示/隐藏控制面板
case .up:   showControls()
case .down: hideControls()

// 播放/暂停键
onPlayPauseCommand: togglePlayPause()

// Menu 键：退出或返回
onExitCommand: exitOrGoBack()

// 按住左右键：加速快进快退
// VLC 内置支持，速度会递增
```

## 🛠️ 集成到现有项目

### 1. 更新 VideoPlayerContainer

```swift
// 替换现有的 VideoPlayerView
VLCVideoPlayerView(
    viewModel: VideoPlayerViewModel(
        videoURL: videoURL,
        subtitleFiles: subtitleFiles
    )
)
```

### 2. 更新 VideoPlayerViewModel

添加 VLC 特定的方法：
```swift
// VLC 播放器控制
func setVLCPlayer(_ player: VLCMediaPlayer) {
    self.vlcPlayer = player
}

func loadVLCSubtitle(subtitleFile: WebDAVItem) {
    // 实现 VLC 字幕加载
}
```

## 📊 VLCKit vs AVPlayer 对比

| 特性 | VLCKit | AVPlayer |
|-----|-------|----------|
| 支持格式 | 100+ | 有限 |
| 字幕支持 | 完整 | 基础 |
| 网络流 | 强大 | 基础 |
| 自定义控制 | 完全 | 受限 |
| 性能 | 优秀 | 优秀 |
| 包大小 | ~50MB | 系统内置 |

## 🚨 注意事项

1. **包大小**: VLCKit 会增加约 50MB 的应用大小
2. **审核**: 确保遵循 App Store 审核指南
3. **许可**: VLC 使用 LGPL 许可，需要遵循相关条款
4. **性能**: 在较旧的设备上可能需要优化

## 🔧 调试技巧

```swift
// 启用 VLC 日志
VLCLibrary.shared()?.debugLevel = VLCLogLevel.debug

// 监听播放状态
player.delegate = self

// 错误处理
func mediaPlayerStateChanged(_ aNotification: Notification) {
    // 处理状态变化
}
```

使用 VLCKit 后，您将获得：
- ✅ 完整的左右键快进快退功能
- ✅ 按住加速功能 
- ✅ 更多视频格式支持
- ✅ 更好的字幕支持
- ✅ 专业级的播放控制
