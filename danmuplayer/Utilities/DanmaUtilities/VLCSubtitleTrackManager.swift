import Foundation
import VLCKitSPM
import VLCUI
import SwiftUI

/// VLCUI字幕轨道管理器
class VLCUISubtitleTrackManager {
    
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
        
        // 直接解析为统一的弹幕参数格式
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: danmakuData) else {
            print("无法解析弹幕JSON数据")
            return false
        }
        
        // 处理可能为null的comments数组
        let comments = commentResult.comments ?? []
        let danmakuParams = comments.compactMap { $0.parsedParams }
        
        guard !danmakuParams.isEmpty else {
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
                let danmakuComments = danmakuParams.map { params in
                    DanmakuComment(
                        time: params.time,
                        mode: params.mode,
                        fontSize: 25,
                        colorValue: Int(params.color),
                        timestamp: params.time,
                        content: params.content
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
        
        // 3. 使用字幕文件添加到 VLCUI
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
    
    /// 查找并激活弹幕轨道
    private func findAndActivateDanmakuTrack() {
        guard let player = player else { return }
        
        guard let trackIndexes = player.videoSubTitlesIndexes as? [Int],
              let trackNames = player.videoSubTitlesNames as? [String] else {
            print("无法获取字幕轨道信息")
            return
        }
        
        // 查找弹幕轨道（通常是最后添加的）
        for (index, name) in zip(trackIndexes, trackNames) {
            if name.contains("danmaku") || index == trackIndexes.last {
                danmakuTrackIndex = index
                player.currentVideoSubTitleIndex = Int32(index)
                print("激活弹幕轨道: \(name) (索引: \(index))")
                break
            }
        }
    }
    
    /// 记录当前字幕状态
    private func recordCurrentSubtitleState() {
        guard let player = player else { return }
        
        let currentIndex = Int(player.currentVideoSubTitleIndex)
        if currentIndex > 0 && originalSubtitleTrackIndex == nil {
            originalSubtitleTrackIndex = currentIndex
        }
    }
    
    /// 移除弹幕轨道并恢复原始字幕
    func removeDanmakuTrack() {
        guard let player = player else { return }
        
        // 恢复原始字幕轨道
        if let originalIndex = originalSubtitleTrackIndex {
            player.currentVideoSubTitleIndex = Int32(originalIndex)
            print("恢复原始字幕轨道: \(originalIndex)")
        } else {
            // 如果没有原始字幕，则禁用字幕
            player.currentVideoSubTitleIndex = 0
            print("禁用字幕显示")
        }
        
        // 清除弹幕轨道索引
        danmakuTrackIndex = nil
    }
    
    /// 获取当前字幕轨道信息
    func getCurrentSubtitleInfo() -> (index: Int, name: String)? {
        guard let player = player else { return nil }
        
        let currentIndex = Int(player.currentVideoSubTitleIndex)
        guard let trackNames = player.videoSubTitlesNames as? [String],
              currentIndex < trackNames.count else {
            return nil
        }
        
        return (currentIndex, trackNames[currentIndex])
    }
    
    /// 切换字幕轨道
    func switchSubtitleTrack(to index: Int) -> Bool {
        guard let player = player else { return false }
        
        guard let trackIndexes = player.videoSubTitlesIndexes as? [Int],
              index < trackIndexes.count else {
            return false
        }
        
        player.currentVideoSubTitleIndex = Int32(index)
        print("切换到字幕轨道: \(index)")
        return true
    }
    
    /// 获取所有可用字幕轨道
    func getAllSubtitleTracks() -> [(index: Int, name: String)] {
        guard let player = player else { return [] }
        
        guard let trackIndexes = player.videoSubTitlesIndexes as? [Int],
              let trackNames = player.videoSubTitlesNames as? [String] else {
            return []
        }
        
        return zip(trackIndexes, trackNames).map { (index: $0, name: $1) }
    }
    
    /// 检查是否有弹幕轨道
    func hasDanmakuTrack() -> Bool {
        return danmakuTrackIndex != nil
    }
    
    /// 获取弹幕轨道索引
    func getDanmakuTrackIndex() -> Int? {
        return danmakuTrackIndex
    }
    
    /// 获取原始字幕轨道索引
    func getOriginalSubtitleTrackIndex() -> Int? {
        return originalSubtitleTrackIndex
    }
}
