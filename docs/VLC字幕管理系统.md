# VLC弹幕字幕智能管理系统

## 核心特性

### 🎯 **无冲突字幕加载**
- 弹幕作为**额外字幕轨道**添加，不替换原始视频字幕
- 使用 `addPlaybackSlave(url, type: .subtitle, enforce: false)` 确保非强制性添加
- 智能识别和保护原始字幕轨道

### 🧠 **智能轨道管理** (`VLCSubtitleTrackManager`)

#### 轨道状态记录
```swift
- originalSubtitleTrackIndex: 记录原始视频字幕轨道
- danmakuTrackIndex: 记录弹幕字幕轨道  
- 播放器初始化时自动记录现有字幕状态
```

#### 安全的弹幕切换
```swift
func toggleDanmaku(_ enabled: Bool) {
    if enabled {
        // 添加弹幕轨道（不影响原始字幕）
        addDanmakuTrack(from: danmakuData)
    } else {
        // 移除弹幕，恢复原始字幕
        removeDanmakuTrack()
    }
}
```

### 🔄 **动态轨道切换**

#### 启用弹幕时：
1. 记录当前字幕状态
2. 添加弹幕轨道作为额外轨道
3. 激活弹幕轨道显示
4. 保持原始字幕轨道信息

#### 禁用弹幕时：
1. 查找原始字幕轨道
2. 恢复原始字幕显示
3. 清除弹幕轨道引用

### 🛡️ **字幕保护机制**

#### 初始状态检测
```swift
private func recordInitialSubtitleState() {
    let currentIndex = player.videoSubTitlesIndex
    if currentIndex > 0 { // 0 表示禁用字幕
        originalSubtitleTrackIndex = currentIndex
    }
}
```

#### 轨道识别
```swift
// 通过名称和索引识别弹幕轨道
if name.contains("danmaku") || index == trackIndexes.last {
    danmakuTrackIndex = index
}
```

#### 状态恢复
```swift
private func removeDanmakuTrack() {
    if let originalIndex = originalSubtitleTrackIndex {
        player.videoSubTitlesIndex = originalIndex // 恢复原始字幕
    } else {
        player.videoSubTitlesIndex = 0 // 禁用字幕
    }
}
```

## 使用方式

### 在播放器初始化时
```swift
private func setupPlayer() {
    // ... VLC播放器配置 ...
    
    // 设置弹幕（不影响原始字幕）
    viewModel.setupVLCDanmaku(for: player)
}
```

### 动态切换弹幕
```swift
.onChange(of: viewModel.danmakuSettings.isEnabled) { _, isEnabled in
    if let player = vlcPlayer {
        viewModel.setupVLCDanmaku(for: player)
    }
}
```

## 技术优势

### 1. **兼容性保证**
- 完全兼容视频内嵌字幕
- 支持外部.srt/.ass/.vtt字幕文件
- 弹幕和字幕可以同时显示

### 2. **性能优化**  
- 使用VLC原生字幕系统，享受硬件加速
- 临时文件管理，避免内存泄漏
- 延迟轨道识别，确保添加完成

### 3. **用户体验**
- 无缝切换弹幕开关
- 保持原始字幕设置
- 调试信息便于开发

### 4. **错误处理**
- 添加失败时的回滚机制
- 轨道丢失时的恢复策略
- 完整的日志记录

## 调试功能

### 轨道信息查看
```swift
#if DEBUG
if let debugInfo = subtitleManager?.getSubtitleTracksDebugInfo() {
    print(debugInfo)
}
#endif
```

### 输出示例
```
=== 字幕轨道信息 ===
当前选中: 2  
原始轨道: 1
弹幕轨道: 2
轨道列表:
  0: 禁用 
  1: 中文字幕 [原始]
✓ 2: danmaku_uuid.ass [弹幕]
```

## 总结

这个系统确保了：
- ✅ 弹幕不会干扰原始视频字幕
- ✅ 用户可以同时看到字幕和弹幕  
- ✅ 弹幕开关不会影响字幕设置
- ✅ 智能的状态管理和错误恢复
- ✅ 使用VLC原生功能，性能最优
