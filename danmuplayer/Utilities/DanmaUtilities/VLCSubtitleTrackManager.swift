import Foundation
import VLCKitSPM
import SwiftUI

/// VLC字幕轨道管理器
class VLCSubtitleTrackManager {
    
    private weak var player: VLCMediaPlayer?
    private var danmakuTrackIndex: Int?
    private var originalSubtitleTrackIndex: Int?
    
    init(player: VLCMediaPlayer) {
        self.player = player
        // 记录初始的字幕轨道状态
        self.recordInitialSubtitleState()
    }
    
    /// 记录初始字幕状态
    private func recordInitialSubtitleState() {
        guard let player = player else { return }
        
        let currentIndex = Int(player.currentVideoSubTitleIndex)
        if currentIndex > 0 { // 0 表示禁用字幕
            originalSubtitleTrackIndex = currentIndex
        }
    }
    
    /// 安全地添加弹幕字幕轨道
    func addDanmakuTrack(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool {
        guard let player = player else { return false }
        
        // 先记录当前的字幕状态
        recordCurrentSubtitleState()
        
        // 解析弹幕数据
        let comments = DanmakuParser.parseComments(from: danmakuData)
        guard !comments.isEmpty else {
            print("没有弹幕数据可添加")
            return false
        }
        
        // 优先使用缓存的字幕文件
        var subtitleURL: URL?
        
        // 1. 先检查是否有缓存的字幕文件
        if let cachedURL = DanmakuToSubtitleConverter.getCachedSubtitleURL(episodeId: episodeId, episodeNumber: episodeNumber, format: format) {
            subtitleURL = cachedURL
            print("使用缓存的字幕文件: \(cachedURL.path)")
        } else {
            // 2. 没有缓存，生成并缓存字幕文件
            do {
                let danmakuComments = comments.map { parsedComment in
                    DanmakuComment(
                        time: parsedComment.time,
                        mode: parsedComment.mode,
                        fontSize: 25,
                        colorValue: colorToInt(parsedComment.color),
                        timestamp: Date().timeIntervalSince1970,
                        content: parsedComment.content
                    )
                }
                
                subtitleURL = try DanmakuToSubtitleConverter.cacheDanmakuAsSubtitle(
                    danmakuComments, 
                    format: format, 
                    episodeId: episodeId, 
                    episodeNumber: episodeNumber
                )
                print("生成并缓存新的字幕文件: \(subtitleURL?.path ?? "unknown")")
            } catch {
                print("生成字幕文件失败: \(error)")
                return false
            }
        }
        
        // 3. 使用字幕文件添加到 VLC
        guard let finalURL = subtitleURL else {
            print("无法获取字幕文件URL")
            return false
        }
        // 3. 使用字幕文件添加到 VLC
        guard let finalURL = subtitleURL else {
            print("无法获取字幕文件URL")
            return false
        }
        
        // 添加为额外的字幕轨道（不替换现有字幕）
        let result = player.addPlaybackSlave(finalURL, type: .subtitle, enforce: false)
        
        if result == 0 {
            print("弹幕轨道添加成功，共 \(comments.count) 条弹幕")
            
            // 延迟获取新添加的轨道索引
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.findAndActivateDanmakuTrack()
            }
            
            return true
        } else {
            print("弹幕轨道添加失败，错误代码: \(result)")
            return false
        }
    }
    
    /// 移除弹幕轨道，恢复原始字幕
    func removeDanmakuTrack() {
        guard let player = player else { return }
        
        // 如果有原始字幕，恢复它
        if let originalIndex = originalSubtitleTrackIndex {
            player.currentVideoSubTitleIndex = Int32(originalIndex)
            print("已恢复原始字幕轨道: \(originalIndex)")
        } else {
            // 否则禁用字幕
            player.currentVideoSubTitleIndex = Int32(0)
            print("已禁用字幕显示")
        }
        
        // 清除弹幕轨道记录
        danmakuTrackIndex = nil
    }
    
    /// 从缓存的弹幕数据添加字幕轨道（便捷方法）
    func addDanmakuTrackFromCache(episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool {
        // 先尝试获取缓存的弹幕数据
        if let cachedData = DanDanPlayCache.shared.getCachedDanmaku(for: episodeId) {
            return addDanmakuTrack(from: cachedData, episodeId: episodeId, format: format, episodeNumber: episodeNumber)
        } else {
            print("未找到剧集 \(episodeId) 的缓存弹幕数据")
            return false
        }
    }
    
    /// 切换弹幕显示状态
    func toggleDanmaku(_ enabled: Bool, danmakuData: Data? = nil, episodeId: Int? = nil, episodeNumber: Int? = nil) {
        if enabled {
            if let data = danmakuData, let epId = episodeId {
                _ = addDanmakuTrack(from: data, episodeId: epId, episodeNumber: episodeNumber)
            } else {
                print("启用弹幕需要提供弹幕数据和剧集ID")
            }
        } else {
            removeDanmakuTrack()
        }
    }
    
    /// 查找并激活弹幕轨道
    private func findAndActivateDanmakuTrack() {
        guard let player = player else { return }
        guard let trackIndexes = player.videoSubTitlesIndexes as? [Int] else { return }
        guard let trackNames = player.videoSubTitlesNames as? [String] else { return }
        
        // 查找弹幕轨道（通常是最后添加的或包含danmaku的）
        for (index, name) in zip(trackIndexes, trackNames) {
            if name.contains("danmaku") || index == trackIndexes.last {
                danmakuTrackIndex = index
                
                // 如果启用了弹幕，则激活弹幕轨道
                // 同时保持原始字幕轨道信息
                player.currentVideoSubTitleIndex = Int32(index)
                print("已激活弹幕轨道: \(name) (索引: \(index))")
                break
            }
        }
    }
    
    /// 记录当前字幕状态
    private func recordCurrentSubtitleState() {
        guard let player = player else { return }
        
        let currentIndex = Int(player.currentVideoSubTitleIndex)
        
        // 如果当前有启用的字幕且不是弹幕轨道，记录它
        if currentIndex > 0 && currentIndex != danmakuTrackIndex {
            originalSubtitleTrackIndex = currentIndex
        }
    }
    
    /// 获取字幕轨道调试信息
    func getSubtitleTracksDebugInfo() -> String {
        guard let player = player else { return "播放器不可用" }
        guard let trackIndexes = player.videoSubTitlesIndexes as? [Int] else { return "无法获取轨道索引" }
        guard let trackNames = player.videoSubTitlesNames as? [String] else { return "无法获取轨道名称" }
        
        var info = "=== 字幕轨道信息 ===\n"
        info += "当前选中: \(player.currentVideoSubTitleIndex)\n"
        info += "原始轨道: \(originalSubtitleTrackIndex ?? -1)\n"
        info += "弹幕轨道: \(danmakuTrackIndex ?? -1)\n"
        info += "轨道列表:\n"
        
        for (index, name) in zip(trackIndexes, trackNames) {
            let isActive = (index == Int(player.currentVideoSubTitleIndex)) ? "✓" : " "
            let isDanmaku = name.contains("danmaku") ? "[弹幕]" : ""
            let isOriginal = (index == originalSubtitleTrackIndex) ? "[原始]" : ""
            info += "\(isActive) \(index): \(name) \(isDanmaku)\(isOriginal)\n"
        }
        
        return info
    }
    
    /// 清理资源（在播放结束或切换视频时调用）
    func cleanup() {
        // 重置状态
        danmakuTrackIndex = nil
        originalSubtitleTrackIndex = nil
        print("VLCSubtitleTrackManager 已清理资源")
    }
    
    // MARK: - Private Helper
    
    private func colorToInt(_ color: Color) -> Int {
        // 简化实现
        return 0xFFFFFF
    }
}
