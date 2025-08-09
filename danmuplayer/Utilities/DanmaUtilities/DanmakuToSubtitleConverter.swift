import Foundation

/// 将弹幕转换为VLC支持的字幕格式
class DanmakuToSubtitleConverter {
    
    /// 将弹幕列表转换为SRT字幕格式
    static func convertToSRT(_ comments: [DanmakuComment]) -> String {
        var srtContent = ""
        
        for (index, comment) in comments.enumerated() {
            let startTime = formatSRTTime(comment.time)
            let endTime = formatSRTTime(comment.time + 3.0) // 每条弹幕显示3秒
            
            srtContent += "\(index + 1)\n"
            srtContent += "\(startTime) --> \(endTime)\n"
            srtContent += "\(comment.content)\n\n"
        }
        
        return srtContent
    }
    // MARK: - 将弹幕列表转换为ASS字幕格式（支持更丰富的样式）
    static func convertToASS(_ comments: [DanmakuComment], videoWidth: Int = 1920, videoHeight: Int = 1080) -> String {
        var assContent = """
        [Script Info]
        Title: Danmaku Subtitle
        ScriptType: v4.00+
        Collisions: Normal
        PlayResX: \(videoWidth)
        PlayResY: \(videoHeight)
        Timer: 100.0000

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Danmaku_Scroll,Helvetica,36,&H00FFFFFF,&H000000FF,&H00101010,&H64000000,0,0,0,0,100,100,0,0,1,2,2,1,10,10,16,1
        Style: Danmaku_Top,Helvetica,36,&H00FFFFFF,&H000000FF,&H00101010,&H64000000,0,0,0,0,100,100,0,0,1,2,2,2,10,10,16,1
        Style: Danmaku_Bottom,Helvetica,36,&H00FFFFFF,&H000000FF,&H00101010,&H64000000,0,0,0,0,100,100,0,0,1,2,2,8,10,10,16,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

        """
        
        for comment in comments {
            let startTime = formatASSTime(comment.time)
            let endTime = formatASSTime(comment.time + (comment.isScrolling ? 8.0 : 3.0))
            let style = getASSStyle(for: comment)
            let colorCode = String(format: "&H00%06X", comment.colorValue & 0xFFFFFF)

            // 将滚动与颜色写入文本字段，Effect 字段留空，提升兼容性
            let moveTag = comment.isScrolling ? "{\\move(\(videoWidth + 100),0,-100,0)}" : ""
            let colorTag = "{\\c\(colorCode)}"
            let safeText = escapeASSText(comment.content)
            let textField = "\(colorTag)\(moveTag)\(safeText)"

            assContent += "Dialogue: 0,\(startTime),\(endTime),\(style),,0,0,0,,\(textField)\n"
        }
        
        return assContent
    }
    
    /// 对ASS文本做必要转义，避免分隔符/控制符破坏行格式
    private static func escapeASSText(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\n", with: "\\N")
        s = s.replacingOccurrences(of: "\r", with: "")
        s = s.replacingOccurrences(of: ",", with: "，")
        s = s.replacingOccurrences(of: "{", with: "(")
        s = s.replacingOccurrences(of: "}", with: ")")
        return s
    }
    // MARK: - 将弹幕缓存为本地字幕文件
    static func cacheDanmakuAsSubtitle(_ comments: [DanmakuComment], 
                                      format: SubtitleFormat, 
                                      episodeId: Int,
                                      episodeNumber: Int? = nil) throws -> URL {
        let content: String
        
        switch format {
        case .srt:
            content = convertToSRT(comments)
        case .ass:
            content = convertToASS(comments)
        }
        
        // 复用 DanDanPlayCache 的缓存目录
        let cacheURL = getDanmakuSubtitleCacheDirectory()
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        
        // 生成缓存文件名
        let fileName = generateSubtitleCacheFileName(episodeId: episodeId, episodeNumber: episodeNumber, format: format)
        let fileURL = cacheURL.appendingPathComponent(fileName)
        
        // 写入缓存文件
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        print("弹幕字幕已缓存到: \(fileURL.path)")
        return fileURL
    }
    // MARK: - 直接将弹幕保存为字幕文件（不缓存）
    static func saveDanmakuAsSubtitle(_ comments: [DanmakuComment], 
                                     format: SubtitleFormat, 
                                     to url: URL) throws {
        let content: String
        
        switch format {
        case .srt:
            content = convertToSRT(comments)
        case .ass:
            content = convertToASS(comments)
        }
        
        // 写入文件
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    // MARK: - 获取缓存的字幕文件URL
    static func getCachedSubtitleURL(episodeId: Int, 
                                   episodeNumber: Int? = nil, 
                                   format: SubtitleFormat) -> URL? {
        let cacheURL = getDanmakuSubtitleCacheDirectory()
        let fileName = generateSubtitleCacheFileName(episodeId: episodeId, episodeNumber: episodeNumber, format: format)
        let fileURL = cacheURL.appendingPathComponent(fileName)
        
        if isSubtitleCacheValid(at: fileURL) {
            return fileURL
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            // 文件过期，删除它
            try? FileManager.default.removeItem(at: fileURL)
            print("缓存字幕文件已过期，已删除: \(fileName)")
        }
        return nil
    }
    // MARK: - 清除指定剧集的缓存字幕文件
    static func clearCachedSubtitles(episodeId: Int, episodeNumber: Int? = nil) {
        let cacheURL = getDanmakuSubtitleCacheDirectory()
        let fileManager = FileManager.default
        
        // 清除所有格式的缓存文件
        for format in [SubtitleFormat.srt, SubtitleFormat.ass] {
            let fileName = generateSubtitleCacheFileName(episodeId: episodeId, episodeNumber: episodeNumber, format: format)
            let fileURL = cacheURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
                print("已清除缓存字幕: \(fileName)")
            }
        }
    }
    // MARK: - 清除所有缓存的字幕文件
    static func clearAllCachedSubtitles() {
        let cacheURL = getDanmakuSubtitleCacheDirectory()
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheURL, 
                                                          includingPropertiesForKeys: nil, 
                                                          options: .skipsHiddenFiles)
            for file in files {
                if file.pathExtension == "srt" || file.pathExtension == "ass" {
                    try fileManager.removeItem(at: file)
                    print("已清除缓存字幕: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("清除缓存字幕失败: \(error)")
        }
    }
    // MARK: - 获取缓存字幕文件的总大小
    static func getSubtitleCacheSize() -> Int64 {
        let cacheURL = getDanmakuSubtitleCacheDirectory()
        var totalSize: Int64 = 0
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheURL, 
                                                                  includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in files {
                if fileURL.pathExtension == "srt" || fileURL.pathExtension == "ass" {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
        } catch {
            print("计算字幕缓存大小失败: \(error)")
        }
        
        return totalSize
    }
    
    // MARK: - Private Helper Methods
    
    /// 获取弹幕字幕缓存目录（复用 DanDanPlayCache 的主缓存目录）
    private static func getDanmakuSubtitleCacheDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("DanDanPlayCache").appendingPathComponent("Subtitles")
    }
    
    /// 生成字幕缓存文件名（使用 episodeId 以与弹幕缓存保持一致）
    private static func generateSubtitleCacheFileName(episodeId: Int, 
                                                    episodeNumber: Int?, 
                                                    format: SubtitleFormat) -> String {
        var fileName = "subtitle_\(episodeId)"
        
        if let episode = episodeNumber {
            fileName += "_ep\(episode)"
        }
        
        return "\(fileName).\(format.fileExtension)"
    }
    
    /// 检查字幕缓存文件是否存在且未过期（与弹幕数据同步过期）
    private static func isSubtitleCacheValid(at url: URL, maxAge: TimeInterval = 24 * 3600) -> Bool { // 默认24小时过期，与弹幕缓存一致
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modificationDate)
                return age < maxAge
            }
        } catch {
            print("检查字幕缓存文件失败: \(error)")
        }
        
        return false
    }
    
    /// 从弹幕数据生成并缓存字幕文件（便捷方法）
    static func generateAndCacheSubtitle(from danmakuData: Data, 
                                       episodeId: Int, 
                                       format: SubtitleFormat = .srt,
                                       episodeNumber: Int? = nil) throws -> URL? {
        // 直接解析为统一的弹幕参数格式
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: danmakuData) else {
            print("无法解析弹幕JSON数据")
            return nil
        }
        
        // 处理可能为null的comments数组
        let comments = commentResult.comments ?? []
        let danmakuParams = comments.compactMap { $0.parsedParams }
        
        // 转换为DanmakuComment类型（为了兼容现有的字幕生成方法）
        let danmakuComments = danmakuParams.map { params in
            DanmakuComment(
                time: params.time,
                mode: params.mode,
                fontSize: 25, // 默认字体大小
                colorValue: Int(params.color),
                timestamp: params.time,
                content: params.content
            )
        }
        
        // 生成并缓存字幕文件
        return try cacheDanmakuAsSubtitle(danmakuComments, format: format, episodeId: episodeId, episodeNumber: episodeNumber)
    }
    
    private static func formatSRTTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds - floor(seconds)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, milliseconds)
    }
    
    private static func formatASSTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        
        return String(format: "%d:%02d:%05.2f", hours, minutes, secs)
    }
    
    private static func getASSStyle(for comment: DanmakuComment) -> String {
        if comment.isTop {
            return "Danmaku_Top"
        } else if comment.isBottom {
            return "Danmaku_Bottom"
        } else {
            return "Danmaku_Scroll"
        }
    }
    
    private static func getASSEffect(for comment: DanmakuComment, videoWidth: Int) -> String {
        if comment.isScrolling {
            // 滚动效果：从右边滑到左边
            return "scroll up;{\\move(\(videoWidth + 100), 0, -100, 0)}"
        } else {
            return ""
        }
    }
}

enum SubtitleFormat {
    case srt
    case ass
    
    var fileExtension: String {
        switch self {
        case .srt: return "srt"
        case .ass: return "ass"
        }
    }
}
