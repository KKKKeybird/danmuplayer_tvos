/// 播放器ViewModel层 - 业务逻辑和状态管理
import Foundation
import SwiftUI

// MARK: - VideoPlayerViewModel扩展

@available(tvOS 17.0, *)
extension VideoPlayerViewModel {
    
    /// 便利初始化器，用于统一的数据源
    convenience init(dataSource: UnifiedPlayerDataSource) {
        // 创建DanDanPlaySeries
        let series = DanDanPlaySeries(
            animeId: 0,
            animeTitle: dataSource.displayTitle,
            episodeId: 0,
            episodeTitle: dataSource.episodeTitle ?? "",
            displayTitle: dataSource.displayTitle,
            episodeTitle: dataSource.episodeTitle ?? ""
        )
        
        // 转换字幕文件
        let webDAVSubtitleFiles = dataSource.subtitleFiles.compactMap { subtitle -> WebDAVItem? in
            // 这里需要根据实际情况转换，目前返回空数组
            return nil
        }
        
        self.init(
            videoURL: dataSource.videoURL,
            subtitleFiles: webDAVSubtitleFiles
        )
        
        // 设置系列信息
        self.series = series
        
        // 根据媒体类型设置特定配置
        configureForMediaType(dataSource.mediaType)
    }
    
    /// 根据媒体类型配置特定设置
    private func configureForMediaType(_ mediaType: MediaSourceType) {
        let config = PlayerConfiguration(mediaType: mediaType)
        
        switch mediaType {
        case .webDAV:
            configureForWebDAV(config: config)
        case .jellyfin:
            configureForJellyfin(config: config)
        case .local:
            configureForLocal(config: config)
        }
    }
    
    private func configureForWebDAV(config: PlayerConfiguration) {
        // WebDAV特有的播放器配置
        danmakuSettings.isEnabled = config.enableDanmaku
        // 启用外部字幕扫描等
    }
    
    private func configureForJellyfin(config: PlayerConfiguration) {
        // Jellyfin特有的播放器配置
        danmakuSettings.isEnabled = config.enableDanmaku
        // 启用进度同步等
    }
    
    private func configureForLocal(config: PlayerConfiguration) {
        // 本地媒体特有的播放器配置
        danmakuSettings.isEnabled = config.enableDanmaku
    }
}

// MARK: - 播放器状态管理

/// 播放器状态管理器
@MainActor
@available(tvOS 17.0, *)
class PlayerStateManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentDataSource: UnifiedPlayerDataSource?
    
    /// 设置数据源
    func setDataSource(_ dataSource: UnifiedPlayerDataSource) {
        currentDataSource = dataSource
    }
    
    /// 设置加载状态
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    /// 设置错误信息
    func setError(_ error: String?) {
        errorMessage = error
    }
    
    /// 清除错误
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - 播放器服务层

/// 播放器服务协议
protocol PlayerService {
    func loadVideoURL(for item: WebDAVItem, using client: WebDAVClient) async throws -> URL
    func loadJellyfinURL(for item: JellyfinMediaItem, using client: JellyfinClient) async throws -> URL
}

/// 默认播放器服务实现
@available(tvOS 17.0, *)
class DefaultPlayerService: PlayerService {
    
    func loadVideoURL(for item: WebDAVItem, using client: WebDAVClient) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            client.getStreamingURL(for: item.path) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func loadJellyfinURL(for item: JellyfinMediaItem, using client: JellyfinClient) async throws -> URL {
        guard let url = client.getPlaybackUrl(itemId: item.id) else {
            throw PlayerError.unableToGetPlaybackURL
        }
        return url
    }
}

// MARK: - 播放器错误类型

enum PlayerError: LocalizedError {
    case unableToGetPlaybackURL
    case invalidDataSource
    case networkError(underlying: Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .unableToGetPlaybackURL:
            return "无法获取播放地址"
        case .invalidDataSource:
            return "无效的数据源"
        case .networkError(let underlying):
            return "网络错误: \(underlying.localizedDescription)"
        case .unknownError:
            return "未知错误"
        }
    }
}
