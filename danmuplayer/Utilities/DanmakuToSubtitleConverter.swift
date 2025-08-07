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
    
    /// 将弹幕列表转换为ASS字幕格式（支持更丰富的样式）
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
        Style: Danmaku_Scroll,Arial,36,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,1,10,10,10,1
        Style: Danmaku_Top,Arial,36,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1
        Style: Danmaku_Bottom,Arial,36,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,8,10,10,10,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

        """
        
        for comment in comments {
            let startTime = formatASSTime(comment.time)
            let endTime = formatASSTime(comment.time + (comment.isScrolling ? 8.0 : 3.0))
            let style = getASSStyle(for: comment)
            let effect = getASSEffect(for: comment, videoWidth: videoWidth)
            let colorCode = String(format: "&H00%06X", comment.colorValue & 0xFFFFFF)
            
            // 为文本添加颜色标签
            let coloredText = "{\\\\c\(colorCode)}\(comment.content)"
            
            assContent += "Dialogue: 0,\(startTime),\(endTime),\(style),,0,0,0,\(effect),\(coloredText)\n"
        }
        
        return assContent
    }
    
    /// 将弹幕保存为字幕文件
    static func saveDanmakuAsSubtitle(_ comments: [DanmakuComment], format: SubtitleFormat, to url: URL) throws {
        let content: String
        
        switch format {
        case .srt:
            content = convertToSRT(comments)
        case .ass:
            content = convertToASS(comments)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private Helper Methods
    
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
