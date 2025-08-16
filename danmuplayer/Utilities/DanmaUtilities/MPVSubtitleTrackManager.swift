import Foundation
import MPVKit_GPL
import SwiftUI

/// MPVKit字幕轨道管理器
class MPVSubtitleTrackManager {
    private weak var player: MPVPlayer?
    private var danmakuTrackIndex: Int?
    private var originalSubtitleTrackIndex: Int?
    
    init(player: MPVPlayer) {
        self.player = player
        self.recordInitialSubtitleState()
    }
    
    /// 记录初始字幕状态
    private func recordInitialSubtitleState() {
        guard let player = player else { return }
        let currentIndex = player.currentSubtitleTrackIndex
        if currentIndex >= 0 {
            originalSubtitleTrackIndex = currentIndex
        }
    }
    
    /// 安全地添加弹幕字幕轨道
    func addDanmakuTrack(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool {
        guard let player = player else { return false }
        recordCurrentSubtitleState()
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: danmakuData) else {
            print("无法解析弹幕JSON数据")
            return false
        }
        let comments = commentResult.comments ?? []
        let danmakuParams = comments.compactMap { $0.parsedParams }
        guard !danmakuParams.isEmpty else {
            print("没有弹幕数据可添加")
            return false
        }
        var subtitleURL: URL?
        if let cachedURL = DanmakuToSubtitleConverter.getCachedSubtitleURL(episodeId: episodeId, episodeNumber: episodeNumber, format: format) {
            subtitleURL = cachedURL
            print("使用缓存的字幕文件: \(cachedURL.path)")
        } else {
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
        guard let finalURL = subtitleURL else {
            print("无法获取字幕文件URL")
            return false
        }
        // MPVKit: 添加外部字幕轨道
        player.addExternalSubtitle(url: finalURL)
        print("弹幕轨道添加成功，共 \(comments.count) 条弹幕")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.findAndActivateDanmakuTrack()
        }
        return true
    }
    
    /// 查找并激活弹幕轨道
    private func findAndActivateDanmakuTrack() {
        guard let player = player else { return }
        let tracks = player.subtitleTracks
        for (index, track) in tracks.enumerated() {
            if track.name.contains("danmaku") || index == tracks.count - 1 {
                danmakuTrackIndex = index
                player.currentSubtitleTrackIndex = index
                print("激活弹幕轨道: \(track.name) (索引: \(index))")
                break
            }
        }
    }
    
    /// 记录当前字幕状态
    private func recordCurrentSubtitleState() {
        guard let player = player else { return }
        let currentIndex = player.currentSubtitleTrackIndex
        if currentIndex >= 0 && originalSubtitleTrackIndex == nil {
            originalSubtitleTrackIndex = currentIndex
        }
    }
    
    /// 移除弹幕轨道并恢复原始字幕
    func removeDanmakuTrack() {
        guard let player = player else { return }
        if let originalIndex = originalSubtitleTrackIndex {
            player.currentSubtitleTrackIndex = originalIndex
            print("恢复原始字幕轨道: \(originalIndex)")
        } else {
            player.currentSubtitleTrackIndex = -1
            print("禁用字幕显示")
        }
        danmakuTrackIndex = nil
    }
    
    /// 获取当前字幕轨道信息
    func getCurrentSubtitleInfo() -> (index: Int, name: String)? {
        guard let player = player else { return nil }
        let currentIndex = player.currentSubtitleTrackIndex
        let tracks = player.subtitleTracks
        guard currentIndex >= 0 && currentIndex < tracks.count else {
            return nil
        }
        return (currentIndex, tracks[currentIndex].name)
    }
    
    /// 切换字幕轨道
    func switchSubtitleTrack(to index: Int) -> Bool {
        guard let player = player else { return false }
        let tracks = player.subtitleTracks
        guard index >= 0 && index < tracks.count else {
            return false
        }
        player.currentSubtitleTrackIndex = index
        print("切换到字幕轨道: \(index)")
        return true
    }
    
    /// 获取所有可用字幕轨道
    func getAllSubtitleTracks() -> [(index: Int, name: String)] {
        guard let player = player else { return [] }
        let tracks = player.subtitleTracks
        return tracks.enumerated().map { (index: $0.offset, name: $0.element.name) }
    }
    
    /// 检查是否有弹幕轨道
    func hasDanmakuTrack() -> Bool {
        return danmakuTrackIndex != nil
    }
    func getDanmakuTrackIndex() -> Int? {
        return danmakuTrackIndex
    }
    func getOriginalSubtitleTrackIndex() -> Int? {
        return originalSubtitleTrackIndex
    }
}
