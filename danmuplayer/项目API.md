# danmuplayer_tvos 项目API文档

## 技术栈说明
本项目使用以下主要技术栈：
- **SwiftUI**: tvOS界面开发框架
- **VLCKitSPM**: VLC媒体播放器核心库，用于视频解码和播放
- **VLCUI**: VLC播放器的SwiftUI界面组件库，提供现代化的播放器UI
- **Combine**: 响应式编程框架，用于数据绑定和状态管理

## VLCUI集成说明
项目中的视频播放器界面使用VLCUI库来提供统一的播放体验：
- `VLCUIVideoPlayerView`: 主要的视频播放器SwiftUI视图组件
- `VLCVideoPlayerUIView`: 底层UIKit包装的VLC播放器视图
- 所有播放器相关的Overlay和控制组件都基于VLCUI进行构建

# Utilities
```swift
/// CacheUtilities
//// JellyfinCache
/// Jellyfin 媒体库和剧集多级缓存工具
class JellyfinCache {
    /// 缓存媒体库项目列表（30分钟）
    func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String)
    /// 获取缓存的媒体库项目列表
    func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]?
    /// 缓存单个剧集的元数据（1小时）
    func cacheEpisodeMetadata(_ episode: JellyfinEpisode)
    /// 获取缓存的剧集元数据
    func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode?
    /// 批量缓存剧集元数据（用于预缓存）
    func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode])
    /// 缓存季节列表（1小时）
    func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String)
    /// 获取缓存的季节列表
    func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]?
    /// 缓存图片（7天）
    func cacheImage(_ image: UIImage, for imageURL: URL)
    /// 获取缓存的图片
    func getCachedImage(for imageURL: URL) -> UIImage?
    /// 清理所有缓存
    func clearAllCache()
    /// 获取缓存大小（字节）
    /// CacheUtilities
    //// JellyfinCache
    /// Jellyfin 媒体库和剧集多级缓存工具
    class JellyfinCache {
        static let shared: JellyfinCache
        // 缓存媒体库项目列表（30分钟）
        func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String)
        func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]?
        // 缓存单个剧集元数据（1小时）
        func cacheEpisodeMetadata(_ episode: JellyfinEpisode)
        func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode?
        // 批量缓存剧集元数据
        func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode])
        // 缓存季节列表（1小时）
        func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String)
        func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]?
        // 缓存图片（7天）
        func cacheImage(_ image: UIImage, for imageURL: URL)
        func getCachedImage(for imageURL: URL) -> UIImage?
        // 清理所有缓存
        func clearAllCache()
        // 获取缓存大小（字节）
        func getCacheSize() -> Int64
        // 清除特定媒体库项目/剧集/系列/季节的缓存
        func clearLibraryItemsCache(for libraryId: String)
        func clearEpisodeMetadataCache(for episodeId: String)
        func clearSeriesEpisodesMetadataCache(for seriesId: String)
        func clearSeasonsCache(for seriesId: String)
    }
    /// 取消加载
    /// 弹弹Play字幕和剧集信息缓存工具
    class DanDanPlayCache {
        static let shared: DanDanPlayCache
        // 缓存ASS字幕内容（2小时）
        func cacheASSSubtitle(_ assContent: String, for episodeId: Int)
        func getCachedASSSubtitle(for episodeId: Int) -> String?
        // 缓存剧集信息（7天）
        func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileurl: String)
        func getCachedEpisodeInfo(for fileurl: String) -> DanDanPlayEpisode?
        // 清理所有缓存
        func clearAllCache()
        // 获取弹幕数据缓存大小（字节）
        func getCacheSize() -> Int64
        // 清理指定剧集的相关缓存（包括弹幕和ASS字幕）
        func clearEpisodeCache(episodeId: Int, episodeNumber: Int? = nil)
    }
    static func parseCommentParams(from data: Data) -> [CommentData.DanmakuParams]
    /// 弹幕解析工具
    struct DanmakuParser {
        struct ParsedComment {
            let time: Double
            let mode: Int
            let color: Color
            let userId: String
            let content: String
        }
        // 解析弹弹Play API响应为弹幕数组
        static func parseComments(from data: Data) -> [ParsedComment]
        // 解析API响应为DanmakuParams数组
        static func parseCommentParams(from data: Data) -> [CommentData.DanmakuParams]
        // 解析单条弹幕参数字符串
        static func parseComment(p: String, m: String) -> ParsedComment?
    }
    static func clearAllCachedSubtitles()
    /// 弹幕转字幕及缓存工具
    class DanmakuToSubtitleConverter {
        // 弹幕转SRT字幕
        static func convertToSRT(_ comments: [DanmakuComment]) -> String
        // 弹幕转ASS字幕
        static func convertToASS(_ comments: [DanmakuComment], videoWidth: Int = 1920, videoHeight: Int = 1080) -> String
        // 弹幕缓存为本地字幕文件
        static func cacheDanmakuAsSubtitle(_ comments: [DanmakuComment], format: SubtitleFormat, episodeId: Int, episodeNumber: Int? = nil) throws -> URL
        // 直接保存弹幕为字幕文件
        static func saveDanmakuAsSubtitle(_ comments: [DanmakuComment], format: SubtitleFormat, to url: URL) throws
        // 获取缓存字幕文件URL
        static func getCachedSubtitleURL(episodeId: Int, episodeNumber: Int? = nil, format: SubtitleFormat) -> URL?
        // 清除指定剧集的缓存字幕文件
        static func clearCachedSubtitles(episodeId: Int, episodeNumber: Int? = nil)
        // 清除所有缓存的字幕文件
        static func clearAllCachedSubtitles()
        // 获取缓存字幕文件的总大小（字节）
        static func getSubtitleCacheSize() -> Int64
        // 从弹幕数据生成并缓存字幕文件（便捷方法）
        static func generateAndCacheSubtitle(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .srt, episodeNumber: Int? = nil) throws -> URL?
    }
    func cleanup()
    /// VLC 弹幕字幕轨道管理
    class VLCSubtitleTrackManager {
        // 添加弹幕字幕轨道（ASS）
        func addDanmakuTrack(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
        // 移除弹幕轨道，恢复原始字幕
        func removeDanmakuTrack()
        // 从缓存添加弹幕字幕轨道
        func addDanmakuTrackFromCache(episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
        // 切换弹幕显示状态
        func toggleDanmaku(_ enabled: Bool, danmakuData: Data? = nil, episodeId: Int? = nil, episodeNumber: Int? = nil)
        // 获取字幕轨道调试信息
        func getSubtitleTracksDebugInfo() -> String
        // 清理资源（播放结束或切换视频时调用）
        func cleanup()
    }
    func identifyEpisode(for videoURL: URL, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) // 自动识别剧集（返回最佳匹配结果）
    func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void) // 获取候选剧集列表供用户手动选择
    func loadDanmakuAsASS(for episode: DanDanPlayEpisode, completion: @escaping (Result<String, Error>) -> Void) // 加载弹幕并转换为ASS格式（新版简化API）
}
//// NetworkError
enum NetworkError: Error{} // 返回网络错误
//// JellyfinClient
class JellyfinClient{
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void) // 测试连接
    func authenticate(completion: @escaping (Result<JellyfinUser, Error>) -> Void) // MARK: - 用户认证
    func getLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void) // MARK: - 获取媒体库列表
    func getLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) // MARK: - 获取媒体库中的项目
    func getSeasons(seriesId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) // MARK: - 获取系列的季节列表
    func getEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) // MARK: - 获取剧集列表
    func getPlaybackUrl(itemId: String) -> URL? // MARK: - 获取播放URL
    func getImageUrl(itemId: String, type: String = "Primary", maxWidth: Int = 600) -> URL? // MARK: - 获取图片URL
    func stopSessionKeepAlive() // MARK: - 停止会话保持
    func refreshLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void) // 强制刷新媒体库列表（跳过缓存）
    func getMergedLibraryItems(serverId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) // 获取合并后的媒体库项目（基于用户选择）
    func refreshLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) // 强制刷新媒体库项目（跳过缓存）
    func refreshEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) // 强制刷新剧集列表（跳过缓存）
    func getEpisodeDetails(episodeId: String, completion: @escaping (Result<JellyfinEpisode, Error>) -> Void) // 获取单个剧集的详细信息（优先使用缓存）
    func getCachedEpisodeMetadata(episodeId: String) -> JellyfinEpisode? // 从缓存中快速获取剧集元数据（同步方法）
    // MARK: - 字幕相关API (https://api.jellyfin.org/#tag/Subtitle/operation/GetRemoteSubtitles)
    func getSubtitleTracks(for itemId: String, completion: @escaping (Result<[JellyfinSubtitleTrack], Error>) -> Void) // 获取媒体项的可用字幕列表
    func getSubtitleURL(for itemId: String, subtitleIndex: Int, format: String = "srt") -> URL? // 获取指定字幕轨道的字幕URL
    func getRecommendedSubtitleURL(for itemId: String, completion: @escaping (URL?) -> Void) // 获取推荐的字幕轨道（优先中文字幕）
    func getAndCacheASSSubtitle(for itemId: String, completion: @escaping (URL?) -> Void) // 获取并缓存ASS字幕文件（用于播放前预处理）
}
//// WebDAVClient
class WebDAVClient{
    // MARK: - 发起请求获取目录文件列表
    /// - Parameters:
    ///   - path: 目录相对路径
    ///   - completion: 回调WebDAVItem数组或错误
    func fetchDirectory(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void)
    // MARK: - 获取文件的流媒体URL
    //// DanDanPlayAPI
    class DanDanPlayAPI {
        // 自动识别剧集（返回最佳匹配结果）
        func identifyEpisode(for videoURL: URL, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void)
        // 获取候选剧集列表供用户手动选择
        func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void)
        // 加载弹幕并转换为ASS格式
        func loadDanmakuAsASS(for episode: DanDanPlayEpisode, completion: @escaping (Result<String, Error>) -> Void)
    }
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void)
    //// JellyfinClient
    class JellyfinClient {
        let serverURL: URL
        let apiKey: String?
        let userId: String?
        let username: String?
        let password: String?
        // 测试连接
        func testConnection(completion: @escaping (Result<Bool, Error>) -> Void)
        // 用户认证
        func authenticate(completion: @escaping (Result<JellyfinUser, Error>) -> Void)
        // 获取媒体库列表
        func getLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void)
        // 获取媒体库中的项目
        func getLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
        // 获取系列的季节列表
        func getSeasons(seriesId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
        // 获取剧集列表
        func getEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
        // 获取播放URL
        func getPlaybackUrl(itemId: String) -> URL?
        // 获取图片URL
        func getImageUrl(itemId: String, type: String = "Primary", maxWidth: Int = 600) -> URL?
        // 停止会话保持
        func stopSessionKeepAlive()
        // 强制刷新媒体库列表
        func refreshLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void)
        // 获取合并后的媒体库项目
        func getMergedLibraryItems(serverId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
        // 强制刷新媒体库项目
        func refreshLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
        // 强制刷新剧集列表
        func refreshEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
        // 获取单个剧集的详细信息
        func getEpisodeDetails(episodeId: String, completion: @escaping (Result<JellyfinEpisode, Error>) -> Void)
        // 从缓存中快速获取剧集元数据
        func getCachedEpisodeMetadata(episodeId: String) -> JellyfinEpisode?
        // 获取媒体项的可用字幕列表
        func getSubtitleTracks(for itemId: String, completion: @escaping (Result<[JellyfinSubtitleTrack], Error>) -> Void)
        // 获取指定字幕轨道的字幕URL
        func getSubtitleURL(for itemId: String, subtitleIndex: Int, format: String) -> URL?
        // 获取推荐的字幕轨道
        func getRecommendedSubtitleURL(for itemId: String, completion: @escaping (URL?) -> Void)
        // 获取并缓存ASS字幕文件
        func getAndCacheASSSubtitle(for itemId: String, completion: @escaping (URL?) -> Void)
    }
    /// DanDanPlay API要求使用文件前16MB的MD5哈希
    //// WebDAVClient
    class WebDAVClient {
        let baseURL: URL
        let credentials: Credentials?
        // 获取目录文件列表
        func fetchDirectory(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void)
        // 获取文件的流媒体URL
        func getStreamingURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void)
        // 测试WebDAV连接
        func testConnection(completion: @escaping (Result<Bool, Error>) -> Void)
    }
    static func cleanPath(_ path: String) -> String
    //// WebDAVParser
    class WebDAVParser: NSObject, XMLParserDelegate {
        // 解析XML数据为WebDAVItem数组
        func parseDirectoryResponse(_ data: Data) throws -> [WebDAVItem]
        // XMLParserDelegate实现
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])
        func parser(_ parser: XMLParser, foundCharacters string: String)
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    }
}
    struct FileInfoExtractor {
        struct FileMatchInfo {
            let fileName: String
            let fileHash: String
            let fileSize: Int64
            let videoDuration: Double
        }
        // 计算文件前16MB的MD5哈希
        static func calculateFileHash(for url: URL) -> String?
        // 获取文件大小
        static func getFileSize(for url: URL) -> Int64?
        // 获取视频时长
        static func getVideoDuration(for url: URL) -> Double?
        // 提取完整文件匹配信息
        static func extractFileInfo(from url: URL) -> FileMatchInfo?
    }
    ///   - danmakuData: 弹幕数据（可选）
    class XMLParserHelper {
        // 提取资源类型
        static func extractResourceType(from xmlString: String) -> Bool
        // 解析WebDAV日期格式
        static func parseWebDAVDate(_ dateString: String) -> Date?
        // 清理和解码URL路径
        static func cleanPath(_ path: String) -> String
        // 从href路径中提取文件名
        static func extractFileName(from href: String) -> String
        // 验证是否为有效WebDAV响应项
        static func isValidWebDAVItem(href: String, displayName: String, isDirectory: Bool) -> Bool
        // 检查文件是否为视频文件
        static func isVideoFile(fileName: String) -> Bool
        // 解析文件大小字符串
        static func parseFileSize(_ sizeString: String) -> Int64?
        // 获取支持的视频文件扩展名列表
        static func getSupportedVideoExtensions() -> [String]
    }
# Models
```swift
/// DanDanPlayModels
//// DanDanPlayEpisode
struct DanDanPlayEpisode: Identifiable, Codable {
    let animeId: Int
    let animeTitle: String
    let episodeId: Int
    let episodeTitle: String
    let shift: Double?
    var id: Int
    var displayTitle: String
}
//// DanmakuComment
struct DanmakuComment: Codable, Identifiable {
    let id: UUID = UUID()
    let time: Double
    let mode: Int
    let fontSize: Int
    let colorValue: Int
    let timestamp: TimeInterval
    let content: String
    // ...编码实现与辅助属性...
}
struct DanmakuResponse: Codable {
    let count: Int
    let comments: [DanmakuComment]
}
//// JellyfinLibraryConfig
struct JellyfinLibraryConfig: Codable, Equatable {
    let serverId: String
    var selectedLibraryIds: Set<String>
    let lastUpdated: Date
    init(serverId: String, selectedLibraryIds: Set<String>)
    func shouldShowLibrary(id: String) -> Bool
    var selectedCount: Int
    mutating func addLibrary(id: String)
    mutating func removeLibrary(id: String)
    mutating func toggleLibrary(id: String)
}
class JellyfinLibraryConfigManager: ObservableObject {
    static let shared: JellyfinLibraryConfigManager
    @Published var configs: [String: JellyfinLibraryConfig]
    func getConfig(for serverId: String) -> JellyfinLibraryConfig?
    func saveConfig(_ config: JellyfinLibraryConfig, for serverId: String)
    func updateSelectedLibraries(for serverId: String, selectedIds: Set<String>)
    func getSelectedLibraryIds(for serverId: String) -> Set<String>
    func shouldShowLibrary(id: String, for serverId: String) -> Bool
    func filterLibraries(_ libraries: [JellyfinLibrary], for serverId: String) -> [JellyfinLibrary]
    func getMergedLibraryItems(from client: JellyfinClient, serverId: String, availableLibraries: [JellyfinLibrary], completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
    func clearAllConfigs()
}
//// JellyfinModels
struct JellyfinUser: Codable {
    let id: String
    let name: String
    let serverId: String
    let hasPassword: Bool
    let hasConfiguredPassword: Bool
    let hasConfiguredEasyPassword: Bool
    let enableAutoLogin: Bool?
    let lastLoginDate: String?
    let lastActivityDate: String?
    // ...CodingKeys省略...
}
struct JellyfinAuthResponse: Codable {
    let user: JellyfinUser
    let sessionInfo: JellyfinSessionInfo?
    let accessToken: String
    let serverId: String
    // ...CodingKeys省略...
}
struct JellyfinSessionInfo: Codable {
    let playState: JellyfinPlayState?
    let remoteEndPoint: String?
    let playableMediaTypes: [String]
    let id: String
    let userId: String
    let userName: String
    let client: String
    let lastActivityDate: String
    let lastPlaybackCheckIn: String?
    let deviceName: String
    let deviceType: String?
    let nowPlayingItem: JellyfinMediaItem?
    let deviceId: String
    let applicationVersion: String
    let isActive: Bool
    let supportsMediaControl: Bool
    let supportsRemoteControl: Bool
    let hasCustomDeviceName: Bool
    let serverId: String
    let supportedCommands: [String]
    // ...CodingKeys省略...
}
struct JellyfinPlayState: Codable {
    let canSeek: Bool
    let isPaused: Bool
    let isMuted: Bool
    let repeatMode: String
    let positionTicks: Int64?
    let playbackStartTimeTicks: Int64?
    // ...CodingKeys省略...
}
struct JellyfinLibrary: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let etag: String?
    let dateCreated: String?
    let canDelete: Bool?
    let canDownload: Bool?
    let sortName: String?
    let collectionType: String?
    let type: String
    let locationType: String?
    // ...CodingKeys省略...
}
struct JellyfinMediaItem: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let etag: String?
    let dateCreated: String?
    let canDelete: Bool?
    let canDownload: Bool?
    let sortName: String?
    let type: String
    let locationType: String?
    let userData: JellyfinUserData?
    let productionYear: Int?
    let status: String?
    let endDate: String?
    let overview: String?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let genres: [String]?
    let tags: [String]?
    let imageTags: [String: String]?
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let seasonName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let primaryImageAspectRatio: Double?
    // ...计算属性和CodingKeys省略...
}
struct JellyfinUserData: Codable {
    let rating: Double?
    let playedPercentage: Double?
    let unplayedItemCount: Int?
    let playbackPositionTicks: Int64?
    let playCount: Int
    let isFavorite: Bool
    let played: Bool
    let key: String?
    // ...CodingKeys省略...
}
typealias JellyfinEpisode = JellyfinMediaItem
struct JellyfinSubtitleTrack: Codable {
    let index: Int
    let language: String?
    let displayTitle: String?
    let codec: String?
    let isDefault: Bool
    let isForced: Bool
    let isExternal: Bool
    let deliveryUrl: String?
    // ...CodingKeys省略...
}
struct JellyfinItemsResponse<T: Codable>: Codable {
    let items: [T]
    let totalRecordCount: Int
    let startIndex: Int
    // ...CodingKeys省略...
}
//// MediaLibraryConfig
enum MediaLibraryServerType: String, Codable, CaseIterable {
    case webdav = "webdav"
    case jellyfin = "jellyfin"
    var displayName: String { get }
}
struct MediaLibraryConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let serverURL: String
    let serverType: MediaLibraryServerType
    let username: String?
    let password: String?
    let apiKey: String?
    let userId: String?
    func createClient() -> Any?
    func createWebDAVClient() -> WebDAVClient?
    func createJellyfinClient() -> JellyfinClient?
    var baseURL: String { get }
    var isJellyfinServer: Bool { get }
}
class MediaLibraryConfigManager: ObservableObject {
    @Published var configs: [MediaLibraryConfig]
    func loadConfigs()
    func saveConfigs()
    func addConfig(_ config: MediaLibraryConfig)
    func updateConfig(_ config: MediaLibraryConfig)
    func removeConfig(withId id: UUID)
    func validateConfig(_ config: MediaLibraryConfig) -> Bool
}
//// Credentials
struct Credentials {
    let username: String
    let password: String
}
//// WebDAVItem
struct WebDAVItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?
    static func == (lhs: WebDAVItem, rhs: WebDAVItem) -> Bool
}
```
# ViewModels
```swift
/// FileBrowserViewModel
class FileBrowserViewModel: ObservableObject {
    @Published var items: [WebDAVItem]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var showingVideoPlayer: Bool
    @Published var selectedVideoItem: WebDAVItem?
    var client: WebDAVClient { get }
    var currentDirectoryName: String { get }
    func loadDirectory(path: String? = nil)
    func testWebDAVConnection()
    func createChildViewModel(for item: WebDAVItem) -> FileBrowserViewModel
    func playVideo(item: WebDAVItem)
    func getVideoStreamingURL(for item: WebDAVItem, completion: @escaping (Result<URL, Error>) -> Void)
    func findSubtitleFiles(for videoItem: WebDAVItem) -> [WebDAVItem]
    func sortItems(by option: SortOption)
    enum SortOption {
        case name, date, size
        var displayName: String { get }
        var systemImage: String { get }
    }
    // private func sortItems(_ items: [WebDAVItem], by option: SortOption) -> [WebDAVItem]
    // private func isVideoFile(_ fileName: String) -> Bool
    // private func findBestSubtitleURL(for videoItem: WebDAVItem) -> URL?
    // private func isSubtitleFile(_ fileName: String) -> Bool
    // private func hasMatchingBaseName(videoFile: String, subtitleFile: String) -> Bool
    // private func constructWebDAVURL(for item: WebDAVItem) -> URL?
}
/// JellyfinMediaLibraryViewModel
class JellyfinMediaLibraryViewModel: ObservableObject {
    @Published var libraries: [JellyfinLibrary]
    @Published var mediaItems: [JellyfinMediaItem]
    @Published var seasons: [JellyfinMediaItem]
    @Published var episodes: [JellyfinEpisode]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var selectedLibrary: JellyfinLibrary?
    @Published var selectedSeries: JellyfinMediaItem?
    @Published var selectedSeason: JellyfinMediaItem?
    @Published var currentLevel: BrowsingLevel
    @Published var isAuthenticated: Bool
    @Published var isPerformingDetailedTest: Bool
    @Published var connectionTestResults: [String]
    @Published var showingLibrarySelection: Bool
    var jellyfinClient: JellyfinClient { get }
    func authenticate()
    func showLibrarySelection()
    func selectLibrary(_ library: JellyfinLibrary)
    func selectSeries(_ series: JellyfinMediaItem)
    func selectSeason(_ season: JellyfinMediaItem)
    func goBack()
    func refresh()
    func getImageUrl(for item: JellyfinMediaItem, type: String = "Primary", maxWidth: Int = 600) -> URL?
    func prepareMediaForPlayback(item: JellyfinMediaItem, completion: @escaping (URL, [URL]) -> Void)
    func validatePlayability(for item: JellyfinMediaItem) -> Bool
    func getEpisodes(for seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
    func getEpisodesForUnifiedStructure(for item: JellyfinMediaItem, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
    func diagnoseConnection() -> String
    func performDetailedConnectionTest() async
    enum BrowsingLevel {
        case libraries, series, seasons, episodes
    }
    // private func performAuthentication()
    // private func loadLibraries()
    // private func loadMergedMediaItems()
    // private func loadMediaItems(from library: JellyfinLibrary)
    // private func loadSeasons(for seriesId: String)
    // private func loadEpisodes(for seriesId: String, seasonId: String? = nil)
    // private func addTestResult(_ testName: String, test: () async throws -> String) async
}
/// MediaLibraryViewModel
class MediaLibraryViewModel: ObservableObject {
    @Published var mediaLibraries: [MediaLibrary]
    @Published var connectionStatus: [UUID: Bool]
    func refreshLibraries()
    func removeLibrary(withId id: UUID)
    func testAllConnections()
    func testConnection(for libraryId: UUID)
    // private func testLibraryConnection(_ library: MediaLibrary) async -> Bool
    // private func testWebDAVConnection(_ library: MediaLibrary) async -> Bool
    // private func testJellyfinConnection(_ library: MediaLibrary) async -> Bool
}
```
# 统一媒体结构设计

## 核心理念
按照项目API的定义："将电影和剧集都处理为类剧集结构"，我们实现了统一的媒体处理架构：

### 统一处理逻辑
- **电影处理**: 电影被当作只有一季一集的剧集来处理
- **剧集处理**: 保持原有的多季多集结构
- **界面统一**: 所有媒体项目都使用相同的详情页和播放流程

### 虚拟剧集创建
通过 `getEpisodesForUnifiedStructure()` 方法：
- 电影自动转换为 `Episode` 类型
- 设置为第1季第1集 (`parentIndexNumber: 1, indexNumber: 1`)
- 保持电影的所有元数据信息

### 架构优势
1. **统一体验**: 用户操作流程完全一致
2. **代码简化**: 移除大量条件判断代码
3. **易于维护**: 单一处理流程，减少bug产生
4. **扩展性强**: 新增媒体类型只需适配统一结构

# Views
## MediaLibraryViews
### MediaLibraryListView: 入口界面，可配置媒体库，进入媒体库
#### Components.MediaLibraryConfig: 配置媒体库界面
## WebDAVLibraryViews:
### FileListView: WebDAV库界面，文件浏览器视图，可查看WebDAV内视频文件，点击视频文件后在视频文件附近寻找字幕文件，传入视频原始文件名，视频流媒体Url和字幕Url进入播放界面
#### Overlays.WebDAVSortSelectionPopover: 排序方式选择浮窗
#### Components.WebDAVStateViews: WebDAV库各类状态视图
## JellyfinLibraryViews
### JellyfinMediaLibraryView: Jellyfin库界面，海报墙视图
- 显示选择的Jellyfin媒体库内所有文件，将电影和剧集都处理为类剧集结构
- 点击海报进入对应的JellyfinMediaDetailView详情页面
- 简化架构：移除直接播放逻辑，专注于媒体展示和导航功能
#### Overlays.JellyfinSortSelectionPopover: 排序方式选择浮窗
#### Components.JellyfinAuthenticationView: Jellyfin认证视图
#### Components.MediaItemCard: 海报卡片组件
#### Components.StateViews: Jellyfin库各类状态视图
## JellyfinMediaItemViews
### JellyfinMediaDetailView: Jellyfin媒体详情界面，直接负责播放逻辑调用
- 剧集信息视图：上方显示背景和元数据，下方给出季节选项并在其下方横向显示对应剧集图片与标题
- 直接播放调用：在详情页内直接处理播放逻辑，点击后传入视频原始文件名，视频流媒体Url和字幕Url进入播放界面  
- 电影项目：上方显示背景和元数据，下方显示播放按钮，点击后直接进入播放界面
- 架构优势：遵循单一职责原则，播放逻辑集中在媒体详情页，避免多层回调传递
#### Components.EpisodeCard: Jellyfin媒体集卡片组件
## PlayerViews (基于VLCUI构建)
### VLCPlayerContainer: 视频播放生成容器，负责创建和管理VLC播放器实例

**统一创建方法**：
- `VLCPlayerContainer.create(videoURL, originalFileName, subtitleURL?, onDismiss)`: 统一的播放器创建方法
  - videoURL: 视频播放URL
  - originalFileName: 原始文件名
  - subtitleURL: 字幕文件URL（可选）
  - onDismiss: 关闭回调

**字幕管理责任分离**：
- **JellyfinMediaLibraryViewModel**: 负责Jellyfin字幕的获取、缓存和ASS转换
- **FileBrowserViewModel**: 负责WebDAV字幕文件的查找和匹配
- **VLCPlayerContainer**: 只负责播放器的创建和管理，不涉及具体的字幕逻辑
- **统一接口**: 所有媒体源都使用相同的创建方法 `create(videoURL:originalFileName:subtitleURL:onDismiss:)`
- **简化架构**: 移除不必要的媒体源区分，专注于核心播放功能
- **便捷方法**: 提供向后兼容的便捷创建方法
- **错误处理**: 集成加载状态管理和错误处理
### VLCPlayerView: 播放器界面，使用VLCUI库构建，接受视频原始文件名，视频Url和字幕Url，根据视频Url解析文件信息，进入后使用DanDanPlayAPI寻找字幕，加入到字幕轨中同时加载弹幕和字幕
- 基于VLCUIVideoPlayerView构建现代化播放器界面
- 集成弹幕系统和字幕管理
- 支持实时播放状态监控和控制
#### VLCUI组件:
##### VLCUIVideoPlayerView: VLCUI主播放器SwiftUI视图组件
##### VLCVideoPlayerUIView: 底层UIKit包装的VLC播放器视图，处理VLC播放器的底层交互
#### Overlays.DanmakuOverlayLayer: 弹幕显示覆盖层，与VLCUI播放器协同工作
#### Overlays.InformationOverlay: 进度条覆盖层，配有视频音频轨选择按钮，字幕选择按钮，弹幕开关按钮，弹幕匹配按钮，弹幕设置按钮，基于VLCUI的控制接口
#### Overlays.SoundTrackPopover: 音轨选择浮窗，利用VLCUI的音轨管理功能
#### Overlays.SubTrackPopover: 视频字幕选择浮窗，支持VLCUI的字幕轨道切换
#### Overlays.DanmaSelectPopover: 弹幕匹配浮窗，将当前播放视频Url传入DanDanPlayAPI获取全部剧集可能列表，用户选择后重新加载弹幕轨并播放
#### Overlays.DanmaSettingPopover: 弹幕设置浮窗，可以设置弹幕字体大小，速度，同屏最多弹幕密度，弹幕透明度

# VLCUI集成架构说明

## 播放器架构层级
1. **VLCPlayerContainer**: 容器层，负责播放器实例的创建和生命周期管理
2. **VLCPlayerView**: 主播放器视图，集成弹幕和控制逻辑
3. **VLCUIVideoPlayerView**: VLCUI SwiftUI包装层
4. **VLCVideoPlayerUIView**: UIKit底层播放器视图
5. **VLCMediaPlayer**: VLC播放器核心

## VLCUI优势
- **现代化界面**: 基于SwiftUI的声明式UI设计
- **状态管理**: 响应式的播放状态绑定
- **扩展性**: 易于集成自定义控件和覆盖层
- **性能**: 优化的渲染管线和内存管理
- **兼容性**: 完全兼容VLCKitSPM的所有功能

## 播放器工厂模式
项目使用工厂模式创建不同类型的播放器：
- `VLCPlayerContainer.create()`: 统一的播放器创建方法，适用于所有媒体源

# 交互跳转逻辑:
MediaLibraryViews->WebDAVLibraryViews->PlayerViews
MediaLibraryViews->JellyfinLibraryViews->JellyfinMediaDetailView->PlayerViews

# 播放逻辑架构说明

## 设计原则
按照项目API的定义，播放逻辑应该在各自的详情页面中直接调用，而不是通过回调传递：

### WebDAV播放流程
FileListView -> 直接调用播放器 -> PlayerViews

### Jellyfin播放流程  
JellyfinMediaLibraryView -> JellyfinMediaDetailView -> 直接调用播放器 -> PlayerViews

## 架构优势
1. **单一职责**: 每个视图专注于自己的核心功能
2. **降低耦合**: 减少回调链，简化组件间依赖关系  
3. **易于维护**: 播放逻辑集中管理，便于调试和扩展
4. **符合API设计**: 严格遵循项目API文档的架构定义