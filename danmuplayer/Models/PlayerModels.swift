/// 播放器Model层 - 数据模型和业务逻辑
import Foundation

// MARK: - 数据模型

/// 媒体源类型
enum MediaSourceType {
    case webDAV
    case jellyfin
    case local
}

/// 统一的播放器数据源协议
protocol UnifiedPlayerDataSource {
    var displayTitle: String { get }
    var episodeTitle: String? { get }
    var videoURL: URL { get }
    var subtitleFiles: [SubtitleFile] { get }
    var mediaType: MediaSourceType { get }
}

/// 统一的字幕文件协议
protocol SubtitleFile {
    var name: String { get }
    var url: URL? { get }
    var language: String? { get }
}

// MARK: - WebDAV数据模型

/// WebDAV数据源适配器
@available(tvOS 17.0, *)
struct WebDAVDataSource: UnifiedPlayerDataSource {
    let videoItem: WebDAVItem
    let webDAVSubtitleFiles: [WebDAVItem]
    let videoURL: URL
    
    var displayTitle: String {
        return (videoItem.name as NSString).deletingPathExtension
    }
    
    var episodeTitle: String? {
        return videoItem.name
    }
    
    var subtitleFiles: [SubtitleFile] {
        return webDAVSubtitleFiles.map { WebDAVSubtitleAdapter(item: $0) }
    }
    
    var mediaType: MediaSourceType {
        return .webDAV
    }
}

/// WebDAV字幕文件适配器
struct WebDAVSubtitleAdapter: SubtitleFile {
    let item: WebDAVItem
    
    var name: String {
        return item.name
    }
    
    var url: URL? {
        return nil // WebDAV字幕需要通过客户端获取
    }
    
    var language: String? {
        // 从文件名推断语言
        let fileName = item.name.lowercased()
        if fileName.contains("zh") || fileName.contains("chi") || fileName.contains("chs") {
            return "zh"
        } else if fileName.contains("en") || fileName.contains("eng") {
            return "en"
        }
        return nil
    }
}

// MARK: - Jellyfin数据模型

/// Jellyfin数据源适配器
@available(tvOS 17.0, *)
struct JellyfinDataSource: UnifiedPlayerDataSource {
    let mediaItem: JellyfinMediaItem
    let videoURL: URL
    
    var displayTitle: String {
        return mediaItem.name ?? "未知标题"
    }
    
    var episodeTitle: String? {
        return mediaItem.seriesName
    }
    
    var subtitleFiles: [SubtitleFile] {
        return [] // Jellyfin字幕通过API处理
    }
    
    var mediaType: MediaSourceType {
        return .jellyfin
    }
}

// MARK: - 播放器配置模型

/// 播放器配置
struct PlayerConfiguration {
    let enableDanmaku: Bool
    let enableExternalSubtitles: Bool
    let enableProgressSync: Bool
    let autoIdentifySeries: Bool
    
    init(mediaType: MediaSourceType) {
        switch mediaType {
        case .webDAV:
            self.enableDanmaku = false
            self.enableExternalSubtitles = true
            self.enableProgressSync = false
            self.autoIdentifySeries = true
        case .jellyfin:
            self.enableDanmaku = true
            self.enableExternalSubtitles = false
            self.enableProgressSync = true
            self.autoIdentifySeries = true
        case .local:
            self.enableDanmaku = true
            self.enableExternalSubtitles = true
            self.enableProgressSync = false
            self.autoIdentifySeries = true
        }
    }
}
