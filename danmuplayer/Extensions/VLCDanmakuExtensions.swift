import Foundation
import VLCKitSPM
import SwiftUI

/// VLC播放器弹幕扩展
extension VLCMediaPlayer {
    
    /// 加载弹幕作为额外字幕轨道（不影响原始字幕）
    /// - Parameters:
    ///   - danmakuData: 弹幕XML或JSON数据
    ///   - format: 字幕格式
    func loadDanmakuAsSubtitle(_ danmakuData: Data, format: SubtitleFormat = .ass) {
        // 直接解析为统一的弹幕参数格式
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: danmakuData) else {
            print("无法解析弹幕JSON数据")
            return
        }
        
        // 处理可能为null的comments数组
        let comments = commentResult.comments ?? []
        let danmakuParams = comments.compactMap { $0.parsedParams }
        
        guard !danmakuParams.isEmpty else {
            print("没有解析到弹幕数据")
            return
        }
        
        // 创建临时字幕文件
        let tempDir = FileManager.default.temporaryDirectory
        let subtitleFileName = "danmaku_\(UUID().uuidString).\(format.fileExtension)"
        let subtitleURL = tempDir.appendingPathComponent(subtitleFileName)
        
        do {
            // 将弹幕参数转换为DanmakuComment格式（为了兼容字幕转换器）
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
            
            try DanmakuToSubtitleConverter.saveDanmakuAsSubtitle(danmakuComments, format: format, to: subtitleURL)
            
            // 使用addPlaybackSlave添加额外的字幕轨道，不会替换原有字幕
            // 使用.subtitle类型确保作为字幕轨道添加
            // enforce: false 表示不强制替换现有字幕
            let result = addPlaybackSlave(subtitleURL, type: .subtitle, enforce: false)
            
            if result == 0 {
                print("成功加载 \(comments.count) 条弹幕作为额外字幕轨道")
                
                // 获取新增的字幕轨道索引并启用弹幕字幕
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.enableDanmakuSubtitleTrack()
                }
            } else {
                print("弹幕字幕轨道添加失败，错误代码: \(result)")
            }
            
        } catch {
            print("加载弹幕字幕失败: \(error)")
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
                print("已启用弹幕字幕轨道: \(name) (索引: \(index))")
                break
            }
        }
    }
    
    /// 移除弹幕字幕（只移除弹幕，保留原有字幕）
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
                print("找到弹幕字幕轨道: \(name) (索引: \(index))")
                break
            }
        }
        
        // 恢复原有的字幕轨道（如果有的话）
        if let originalTrack = originalSubtitleTrack {
            currentVideoSubTitleIndex = Int32(originalTrack)
            print("已恢复原始字幕轨道: \(originalTrack)")
        } else {
            // 如果没有原始字幕，则禁用字幕显示
            currentVideoSubTitleIndex = Int32(0) // 0 通常表示禁用字幕
            print("已禁用字幕显示")
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
    
    /// 切换弹幕字幕显示状态
    func toggleDanmakuSubtitle(_ enabled: Bool, danmakuData: Data? = nil) {
        if enabled {
            if let data = danmakuData {
                loadDanmakuAsSubtitle(data)
            }
        } else {
            removeDanmakuSubtitle()
        }
    }
    
    /// 获取所有字幕轨道信息（调试用）
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
