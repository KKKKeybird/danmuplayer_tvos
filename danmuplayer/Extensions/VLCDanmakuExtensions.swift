import Foundation
import VLCKitSPM
import VLCUI
import SwiftUI

/// VLC播放器弹幕扩展
extension VLCMediaPlayer {
    // MARK: - 加载弹幕作为额外字幕轨道（不影响原始字幕）
    /// - Parameters:
    ///   - danmakuData: ASS格式弹幕数据
    ///   - format: 字幕格式
    func loadDanmakuAsSubtitle(_ danmakuData: Data, format: SubtitleFormat = .ass) {
        // 创建临时字幕文件
        let tempDir = FileManager.default.temporaryDirectory
        let subtitleFileName = "danmaku_\(UUID().uuidString).\(format.fileExtension)"
        let subtitleURL = tempDir.appendingPathComponent(subtitleFileName)
        
        do {
            // 直接写入ASS数据到临时文件
            try danmakuData.write(to: subtitleURL)
            DispatchQueue.main.async {
                DanmakuDebugLogger.shared.add("弹幕字幕文件写入成功: \(subtitleURL.lastPathComponent)")
            }
            
            // 使用addPlaybackSlave添加额外的字幕轨道，不会替换原有字幕
            // 使用.subtitle类型确保作为字幕轨道添加
            // enforce: false 表示不强制替换现有字幕
            let result = addPlaybackSlave(subtitleURL, type: .subtitle, enforce: false)
            
            if result == 0 {
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("addPlaybackSlave 成功，等待启用弹幕字幕轨道")
                }
                
                // 获取新增的字幕轨道索引并启用弹幕字幕
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.enableDanmakuSubtitleTrack()
                }
            } else {
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("addPlaybackSlave 失败，错误代码: \(result)")
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                DanmakuDebugLogger.shared.add("写入弹幕字幕临时文件失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 启用弹幕字幕轨道（查找并启用弹幕字幕）
    private func enableDanmakuSubtitleTrack() {
        // 获取所有字幕轨道
        guard let trackIndexes = videoSubTitlesIndexes as? [Int] else { return }
        guard let trackNames = videoSubTitlesNames as? [String] else { return }
        
        // 查找弹幕字幕轨道（通常是最后添加的）
        for (index, name) in zip(trackIndexes, trackNames) {
            if name.contains("danmaku") || index == trackIndexes.last {
                // 设置为当前字幕轨道（不会禁用原有视频字幕）
                currentVideoSubTitleIndex = Int32(index)
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("启用弹幕字幕轨道: \(name) (索引: \(index))")
                }
                break
            }
        }
        DispatchQueue.main.async {
            DanmakuDebugLogger.shared.add("字幕轨道列表: indexes=\(trackIndexes), names=\(trackNames)")
        }
    }
    // MARK: - 移除弹幕字幕（只移除弹幕，保留原有字幕）
    func removeDanmakuSubtitle() {
        // 记录当前的非弹幕字幕轨道
        let originalSubtitleTrack = getCurrentNonDanmakuSubtitleTrack()
        
        // 获取所有字幕轨道
        guard let trackIndexes = videoSubTitlesIndexes as? [Int] else { return }
        guard let trackNames = videoSubTitlesNames as? [String] else { return }
        
        // 查找并移除弹幕字幕轨道
        for (index, name) in zip(trackIndexes, trackNames) {
            if name.contains("danmaku") {
                // 注意：VLC可能不支持动态移除slave轨道
                // 这里我们通过设置为禁用状态来"移除"
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("找到弹幕字幕轨道: \(name) (索引: \(index))，禁用之")
                }
                break
            }
        }
        
        // 恢复原有的字幕轨道（如果有的话）
        if let originalTrack = originalSubtitleTrack {
            currentVideoSubTitleIndex = Int32(originalTrack)
            DispatchQueue.main.async {
                DanmakuDebugLogger.shared.add("已恢复原始字幕轨道: \(originalTrack)")
            }
        } else {
            // 如果没有原始字幕，则禁用字幕显示
            currentVideoSubTitleIndex = Int32(0) // 0 通常表示禁用字幕
            DispatchQueue.main.async {
                DanmakuDebugLogger.shared.add("已禁用字幕显示")
            }
        }
    }
    
    /// 获取当前的非弹幕字幕轨道
    private func getCurrentNonDanmakuSubtitleTrack() -> Int? {
        guard let trackIndexes = videoSubTitlesIndexes as? [Int] else { return nil }
        guard let trackNames = videoSubTitlesNames as? [String] else { return nil }
        
        let currentIndex = Int(currentVideoSubTitleIndex)
        
        // 如果当前轨道不是弹幕轨道，则返回它
        for (index, name) in zip(trackIndexes, trackNames) {
            if index == currentIndex && !name.contains("danmaku") {
                return index
            }
        }
        
        // 查找第一个非弹幕字幕轨道
        for (index, name) in zip(trackIndexes, trackNames) {
            if !name.contains("danmaku") && index > 0 { // 0 通常是禁用
                return index
            }
        }
        
        return nil
    }
    // MARK: - 切换弹幕字幕显示状态
    func toggleDanmakuSubtitle(_ enabled: Bool, danmakuData: Data? = nil) {
        if enabled {
            if let data = danmakuData {
                loadDanmakuAsSubtitle(data)
            }
        } else {
            removeDanmakuSubtitle()
        }
    }
    // MARK: - 获取所有字幕轨道信息（调试用）
    func printSubtitleTracksInfo() {
        guard let trackIndexes = videoSubTitlesIndexes as? [Int] else {
            print("无法获取字幕轨道索引")
            return
        }
        guard let trackNames = videoSubTitlesNames as? [String] else {
            print("无法获取字幕轨道名称")
            return
        }
        
        print("=== 字幕轨道信息 ===")
        print("当前选中轨道: \(currentVideoSubTitleIndex)")
        
        for (index, name) in zip(trackIndexes, trackNames) {
            let isActive = (index == Int(currentVideoSubTitleIndex)) ? "✓" : " "
            let isDanmaku = name.contains("danmaku") ? "[弹幕]" : ""
            print("\(isActive) \(index): \(name) \(isDanmaku)")
        }
        print("==================")
    }
}

/// 弹幕VLC集成助手
struct DanmakuVLCIntegration {
    
    /// 为VLC播放器设置弹幕支持
    /// - Parameters:
    ///   - player: VLC播放器实例
    ///   - danmakuData: 弹幕数据
    ///   - enabled: 是否启用弹幕
    static func setupDanmaku(for player: VLCMediaPlayer, danmakuData: Data?, enabled: Bool) {
        if enabled, let data = danmakuData {
            player.loadDanmakuAsSubtitle(data, format: .ass)
        } else {
            player.removeDanmakuSubtitle()
        }
    }
}
