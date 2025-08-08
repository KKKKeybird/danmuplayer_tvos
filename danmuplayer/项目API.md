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
class JellyfinCache{
    func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String) // 缓存媒体库项目列表（30分钟）
    func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]? // 获取缓存的媒体库项目列表
    func cacheEpisodeMetadata(_ episode: JellyfinEpisode) // 缓存单个剧集的元数据（1小时）
    func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode? // 获取缓存的剧集元数据
    func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode]) // 批量缓存剧集元数据（用于预缓存）
    func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String) // 缓存季节列表（1小时）
    func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]? // 获取缓存的季节列表
    func cacheImage(_ image: UIImage, for imageURL: URL) // 缓存图片（7天）
    func getCachedImage(for imageURL: URL) -> UIImage? // 获取缓存的图片
    func clearAllCache() // 清理所有缓存
    func getCacheSize() -> Int64 // 获取缓存大小
    func clearLibraryItemsCache(for libraryId: String) // 清除特定媒体库项目的缓存
    func clearEpisodeMetadataCache(for episodeId: String) // 清除特定剧集的元数据缓存
    func clearSeriesEpisodesMetadataCache(for seriesId: String) // 清除特定系列的所有剧集元数据缓存
    func clearSeasonsCache(for seriesId: String) // 清除特定季节的缓存
}
//// DanDanPlayCache
class DanDanPlayCache{
    func cacheASSSubtitle(_ assContent: String, for episodeId: Int) // 缓存ASS字幕文件（2小时）
    func getCachedASSSubtitle(for episodeId: Int) -> String? // 获取缓存的ASS字幕内容
    func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileurl: String) // 缓存剧集信息（长期缓存，7天）
    func getCachedEpisodeInfo(for fileurl: String) -> DanDanPlayEpisode? // 获取缓存的剧集信息
    func clearAllCache() // 清理所有缓存
    func getCacheSize() -> Int64 // 获取弹幕数据缓存大小
    func clearEpisodeCache(episodeId: Int, episodeNumber: Int? = nil) // 清理指定剧集的相关缓存（包括弹幕和ASS字幕）
}
//// CachedAsyncImage
class AsyncImageLoader: ObservableObject {
    /// 异步图片加载器，集成Jellyfin缓存
    func updateURL(_ newURL: URL)
    func load()
    func cancel()
}
/// DanmaUtilities
//// DanmakuParser
struct DanmakuParser {
    /// 解析的弹幕数据
    struct ParsedComment {
        let time: Double        // 出现时间（秒）
        let mode: Int          // 弹幕模式：1-普通，4-底部，5-顶部
        let color: Color       // 弹幕颜色
        let userId: String     // 用户ID
        let content: String    // 弹幕内容
    }
    /// 从弹弹Play API响应解析弹幕数据（JSON格式）
    /// - Parameter data: API返回的JSON数据
    /// - Returns: 解析后的弹幕数组
    static func parseComments(from data: Data) -> [ParsedComment]
    /// 从弹弹Play API响应直接解析为DanmakuParams数组
    /// - Parameter data: API返回的JSON数据
    /// - Returns: 解析后的弹幕参数数组
    static func parseCommentParams(from data: Data) -> [CommentData.DanmakuParams]
    /// 解析单条弹幕
    /// - Parameters:
    ///   - p: 弹幕参数字符串，格式：时间,模式,颜色,用户ID
    ///   - m: 弹幕内容
    /// - Returns: 解析后的弹幕对象
    static func parseComment(p: String, m: String) -> ParsedComment?
}
//// DanmakuToSubtitleConverter
class DanmakuToSubtitleConverter {
    /// 将弹幕列表转换为ASS字幕格式（支持更丰富的样式）
    static func convertToASS(_ comments: [DanmakuComment], videoWidth: Int = 1920, videoHeight: Int = 1080) -> String
    /// 将弹幕缓存为本地字幕文件
    static func cacheDanmakuAsSubtitle(_ comments: [DanmakuComment], 
                                      format: SubtitleFormat, 
                                      episodeId: Int,
                                      episodeNumber: Int? = nil) throws -> URL
    /// 直接将弹幕保存为字幕文件（不缓存）
    static func saveDanmakuAsSubtitle(_ comments: [DanmakuComment], 
                                     format: SubtitleFormat, 
                                     to url: URL) throws
    /// 获取缓存的字幕文件URL
    static func getCachedSubtitleURL(episodeId: Int, 
                                   episodeNumber: Int? = nil, 
                                   format: SubtitleFormat) -> URL?
    /// 清除指定剧集的缓存字幕文件
    static func clearCachedSubtitles(episodeId: Int, episodeNumber: Int? = nil)
    /// 清除所有缓存的字幕文件
    static func clearAllCachedSubtitles()
    /// 获取缓存字幕文件的总大小
    static func getSubtitleCacheSize() -> Int64
    /// 从弹幕数据生成并缓存字幕文件（便捷方法）
    static func generateAndCacheSubtitle(from danmakuData: Data, 
                                       episodeId: Int, 
                                       format: SubtitleFormat = .srt,
                                       episodeNumber: Int? = nil) throws -> URL?
}
////VLCSubtitleTrackManager
class VLCSubtitleTrackManager {
    /// 安全地添加弹幕字幕轨道
    func addDanmakuTrack(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
    /// 移除弹幕轨道，恢复原始字幕
    func removeDanmakuTrack()
    /// 从缓存的弹幕数据添加字幕轨道（便捷方法）
    func addDanmakuTrackFromCache(episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
    /// 切换弹幕显示状态
    func toggleDanmaku(_ enabled: Bool, danmakuData: Data? = nil, episodeId: Int? = nil, episodeNumber: Int? = nil)
    /// 获取字幕轨道调试信息
    func getSubtitleTracksDebugInfo() -> String
    /// 清理资源（在播放结束或切换视频时调用）
    func cleanup()
}
//// DanDanPlayConfig
struct DanDanPlayConfig {
    static let appId: String = "YOUR_APP_ID"
    private static let appSecret: String = "YOUR_APP_SECRET"
    static var secretKey: String
    /// 检查是否已配置API密钥
    static var isConfigured: Bool
    /// 验证配置有效性
    /// - Returns: 配置状态和错误信息
    static func validateConfiguration() -> (isValid: Bool, errorMessage: String?)
}
/// Networking
//// DanDanPlayAPI
class DanDanPlayAPI{
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
}
//// WebDAVClient
class WebDAVClient{
    // MARK: - 发起请求获取目录文件列表
    /// - Parameters:
    ///   - path: 目录相对路径
    ///   - completion: 回调WebDAVItem数组或错误
    func fetchDirectory(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void)
    // MARK: - 获取文件的流媒体URL
    /// - Parameters:
    ///   - path: 文件路径
    ///   - completion: 返回可用于流媒体播放的URL或错误
    func getStreamingURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void)
    // MARK: - 测试WebDAV连接
    /// - Parameter completion: 返回连接是否成功
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void)
}
//// WebDAVParser
class WebDAVParser: NSObject, XMLParserDelegate{
    // MARK: - 解析XML数据
    /// - Parameter data: XML数据
    /// - Returns: WebDAVItem数组
    func parseDirectoryResponse(_ data: Data) throws -> [WebDAVItem]
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:])
    func parser(_ parser: XMLParser, foundCharacters string: String)
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
}
/// FileInfoExtractor
struct FileInfoExtractor {
    /// 文件匹配信息
    struct FileMatchInfo {
        let fileName: String
        let fileHash: String
        let fileSize: Int64
        let videoDuration: Double // 视频时长（秒）
    }
    /// 计算文件的MD5哈希值
    /// DanDanPlay API要求使用文件前16MB的MD5哈希
    static func calculateFileHash(for url: URL) -> String?
    /// 获取文件大小
    static func getFileSize(for url: URL) -> Int64?
    /// 获取视频时长
    static func getVideoDuration(for url: URL) -> Double?
    /// 提取文件的完整匹配信息
    static func extractFileInfo(from url: URL) -> FileMatchInf
}
/// XMLParserHelper
class XMLParserHelper {
    /// 从WebDAV PROPFIND响应中提取资源类型
    static func extractResourceType(from xmlString: String) -> Bool
    /// 解析WebDAV日期格式
    static func parseWebDAVDate(_ dateString: String) -> Date?
    /// 清理和解码URL路径
    static func cleanPath(_ path: String) -> String
    /// 从href路径中提取文件名
    static func extractFileName(from href: String) -> String
    /// 验证XML元素是否为有效的WebDAV响应项（只保留目录和视频文件）
    static func isValidWebDAVItem(href: String, displayName: String, isDirectory: Bool = false) -> Bool
    /// 检查文件是否为视频文件
    static func isVideoFile(fileName: String) -> Bool
    /// 解析文件大小字符串
    static func parseFileSize(_ sizeString: String) -> Int64?
    /// 获取支持的视频文件扩展名列表（用于调试或UI显示）
    static func getSupportedVideoExtensions() -> [String]
}

```
# Extensions
```swift
/// VLCDanmakuExtensions (使用VLCUI增强)
extension VLCMediaPlayer{
    // MARK: - 加载弹幕作为额外字幕轨道（不影响原始字幕）
    /// - Parameters:
    ///   - danmakuData: 弹幕XML或JSON数据
    ///   - format: 字幕格式
    /// - Note: 基于VLCUI库的增强实现，提供更好的字幕管理
    func loadDanmakuAsSubtitle(_ danmakuData: Data, format: SubtitleFormat = .ass)
    // MARK: - 移除弹幕字幕（只移除弹幕，保留原有字幕）
    /// - Note: 使用VLCUI的字幕轨道管理功能
    func removeDanmakuSubtitle()
    // MARK: - 切换弹幕字幕显示状态
    /// - Parameters:
    ///   - enabled: 是否启用弹幕
    ///   - danmakuData: 弹幕数据（可选）
    /// - Note: 利用VLCUI的动态字幕切换能力
    func toggleDanmakuSubtitle(_ enabled: Bool, danmakuData: Data? = nil)
    // MARK: - 获取所有字幕轨道信息（调试用）
    /// - Note: 增强的调试信息，包含VLCUI相关状态
    func printSubtitleTracksInfo()
}

/// VLCUI组件扩展
extension VLCUIVideoPlayerView {
    // MARK: - 播放器视图配置
    /// 配置VLCUI播放器的显示参数和回调
    func configure(with url: URL, onReady: @escaping (VLCMediaPlayer) -> Void)
    // MARK: - 状态监听设置
    /// 设置播放状态的实时更新绑定
    func setupPlayerStateUpdates(_ player: VLCMediaPlayer)
}

```
# Models
```swift
/// DanDanPlayModels
//// DanDanPlayEpisode
struct DanDanPlayEpisode: Identifiable, Codable {
    /// 表示弹弹Play识别出的剧集信息
    let animeId: Int
    let animeTitle: String
    let episodeId: Int
    let episodeTitle: String
    let shift: Double? // 弹幕偏移时间（秒），可为空
    var id: Int
    var displayTitle: String
}
//// DanmakuComment
struct DanmakuComment: Codable, Identifiable {
    let id = UUID()
    let time: Double // 显示时间（秒）
    let mode: Int // 弹幕类型：1-滚动，4-底部，5-顶部
    let fontSize: Int // 字体大小
    let colorValue: Int // 颜色值
    let timestamp: TimeInterval // 发送时间戳
    let content: String // 弹幕内容
    enum CodingKeys: String, CodingKey{}
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let pString = "\(time),\(mode),\(fontSize),\(colorValue),\(Int(timestamp))"
        try container.encode(pString, forKey: .time)
        try container.encode(content, forKey: .content)
    }
    /// 获取弹幕颜色
    var color: Color
    /// 判断是否为滚动弹幕
    var isScrolling: Bool
    /// 判断是否为顶部弹幕
    var isTop: Bool
    /// 判断是否为底部弹幕
    var isBottom: Bool
}
struct DanmakuResponse: Codable {
    let count: Int
    let comments: [DanmakuComment]
}
/// JellyfinModels
//// JellyfinLibraryConfig
struct JellyfinLibraryConfig: Codable, Equatable {
    let serverId: String // 服务器标识
    var selectedLibraryIds: Set<String> // 选择显示的媒体库ID列表
    let lastUpdated: Date
    init(serverId: String, selectedLibraryIds: Set<String>)
    /// 检查是否应该显示指定的媒体库
    func shouldShowLibrary(id: String) -> Bool
    /// 获取选择的媒体库数量
    var selectedCount: Int
    /// 添加媒体库到选择列表
    mutating func addLibrary(id: String)
    /// 从选择列表移除媒体库
    mutating func removeLibrary(id: String)
    /// 切换媒体库的选择状态
    mutating func toggleLibrary(id: String)
}
class JellyfinLibraryConfigManager: ObservableObject {
    static let shared = JellyfinLibraryConfigManager()
    @Published var configs: [String: JellyfinLibraryConfig] = [:]
    private let userDefaults = UserDefaults.standard
    private let configsKey = "JellyfinLibraryConfigs"
    /// 获取指定服务器的配置
    func getConfig(for serverId: String) -> JellyfinLibraryConfig?
    /// 保存指定服务器的配置
    func saveConfig(_ config: JellyfinLibraryConfig, for serverId: String)
    /// 更新服务器的媒体库选择
    func updateSelectedLibraries(for serverId: String, selectedIds: Set<String>)
    /// 获取选择的媒体库ID列表
    func getSelectedLibraryIds(for serverId: String) -> Set<String>
    /// 检查是否应该显示指定的媒体库
    func shouldShowLibrary(id: String, for serverId: String) -> Bool
    /// 过滤媒体库列表，只返回选择显示的媒体库
    func filterLibraries(_ libraries: [JellyfinLibrary], for serverId: String) -> [JellyfinLibrary]
    /// 获取合并后的媒体库项目
    func getMergedLibraryItems(from client: JellyfinClient,serverId: String,availableLibraries: [JellyfinLibrary],completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
    /// 清除所有配置（用于测试或重置）
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
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case hasConfiguredPassword = "HasConfiguredPassword"
        case hasConfiguredEasyPassword = "HasConfiguredEasyPassword"
        case enableAutoLogin = "EnableAutoLogin"
        case lastLoginDate = "LastLoginDate"
        case lastActivityDate = "LastActivityDate"
    }
}
struct JellyfinAuthResponse: Codable {
    let user: JellyfinUser
    let sessionInfo: JellyfinSessionInfo?
    let accessToken: String
    let serverId: String
    enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
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
    enum CodingKeys: String, CodingKey {
        case playState = "PlayState"
        case remoteEndPoint = "RemoteEndPoint"
        case playableMediaTypes = "PlayableMediaTypes"
        case id = "Id"
        case userId = "UserId"
        case userName = "UserName"
        case client = "Client"
        case lastActivityDate = "LastActivityDate"
        case lastPlaybackCheckIn = "LastPlaybackCheckIn"
        case deviceName = "DeviceName"
        case deviceType = "DeviceType"
        case nowPlayingItem = "NowPlayingItem"
        case deviceId = "DeviceId"
        case applicationVersion = "ApplicationVersion"
        case isActive = "IsActive"
        case supportsMediaControl = "SupportsMediaControl"
        case supportsRemoteControl = "SupportsRemoteControl"
        case hasCustomDeviceName = "HasCustomDeviceName"
        case serverId = "ServerId"
        case supportedCommands = "SupportedCommands"
    }
}
struct JellyfinPlayState: Codable {
    let canSeek: Bool
    let isPaused: Bool
    let isMuted: Bool
    let repeatMode: String
    let positionTicks: Int64?
    let playbackStartTimeTicks: Int64?
    enum CodingKeys: String, CodingKey {
        case canSeek = "CanSeek"
        case isPaused = "IsPaused"
        case isMuted = "IsMuted"
        case repeatMode = "RepeatMode"
        case positionTicks = "PositionTicks"
        case playbackStartTimeTicks = "PlaybackStartTimeTicks"
    }
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
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case etag = "Etag"
        case dateCreated = "DateCreated"
        case canDelete = "CanDelete"
        case canDownload = "CanDownload"
        case sortName = "SortName"
        case collectionType = "CollectionType"
        case type = "Type"
        case locationType = "LocationType"
    }
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
    // 计算属性
    var posterImageUrl: String?
    var backdropImageUrl: String?
    var duration: TimeInterval?
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case etag = "Etag"
        case dateCreated = "DateCreated"
        case canDelete = "CanDelete"
        case canDownload = "CanDownload"
        case sortName = "SortName"
        case type = "Type"
        case locationType = "LocationType"
        case userData = "UserData"
        case productionYear = "ProductionYear"
        case status = "Status"
        case endDate = "EndDate"
        case overview = "Overview"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case genres = "Genres"
        case tags = "Tags"
        case imageTags = "ImageTags"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case primaryImageAspectRatio = "PrimaryImageAspectRatio"
    }
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
    enum CodingKeys: String, CodingKey {
        case rating = "Rating"
        case playedPercentage = "PlayedPercentage"
        case unplayedItemCount = "UnplayedItemCount"
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case key = "Key"
    }
}
typealias JellyfinEpisode = JellyfinMediaItem
struct JellyfinItemsResponse<T: Codable>: Codable {
    let items: [T]
    let totalRecordCount: Int
    let startIndex: Int
    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
/// MediaLibraryModels
//// MediaLibraryConfig
enum MediaLibraryServerType: String, Codable, CaseIterable {
    case webdav = "webdav"
    case jellyfin = "jellyfin"
    var displayName: String
}
struct MediaLibraryConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let serverURL: String // 服务器地址
    let serverType: MediaLibraryServerType // 服务器类型
    let username: String?
    let password: String?
    // Jellyfin专用字段
    let apiKey: String? // Jellyfin API密钥
    let userId: String? // Jellyfin用户ID
    /// 创建对应类型的客户端
    func createClient() -> Any?
    /// 创建WebDAV客户端
    func createWebDAVClient() -> WebDAVClient?
    /// 创建Jellyfin客户端
    func createJellyfinClient() -> JellyfinClient?
    // 保持向后兼容性
    var baseURL: String { serverURL }
    var isJellyfinServer: Bool { serverType == .jellyfin }
}
//// MediaLibraryConfigManager
class MediaLibraryConfigManager: ObservableObject {
    @Published var configs: [MediaLibraryConfig] = []
    /// 从UserDefaults加载配置
    func loadConfigs()
    /// 保存配置到UserDefaults
    func saveConfigs()
    /// 添加新的媒体库配置
    func addConfig(_ config: MediaLibraryConfig)
    /// 更新现有配置
    func updateConfig(_ config: MediaLibraryConfig)
    /// 删除配置
    func removeConfig(withId id: UUID)
    /// 验证配置的有效性
    func validateConfig(_ config: MediaLibraryConfig) -> Bool
}
/// WebDAVModels
//// Credentials
struct Credentials {
    let username: String
    let password: String
}
//// WebDAVItem
struct WebDAVItem: Identifiable, Equatable {
    let id = UUID()
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
/// FileBrowserViewModel (增强VLCUI支持)
class FileBrowserViewModel: ObservableObject {
    func loadDirectory(path: String? = nil) // 加载指定路径目录文件列表
    func testWebDAVConnection() // 测试WebDAV连接
    func createChildViewModel(for item: WebDAVItem) -> FileBrowserViewModel // 创建子目录的ViewModel
    func playVideo(item: WebDAVItem) // 播放视频文件
    func createVideoPlayerContainer(for item: WebDAVItem, completion: @escaping (VLCPlayerContainer?) -> Void) // 创建基于VLCUI的视频播放器容器
    func getVideoStreamingURL(for item: WebDAVItem, completion: @escaping (Result<URL, Error>) -> Void) // 获取视频文件的流媒体URL
    func findSubtitleFiles(for videoItem: WebDAVItem) -> [WebDAVItem] // 查找同目录下的字幕文件
    func sortItems(by option: SortOption) // 支持文件排序（名称、日期、大小）
    private func isVideoFile(_ fileName: String) -> Bool // 检查文件是否为视频文件
}
/// JellyfinMediaLibraryViewModel (增强VLCUI支持)
class JellyfinMediaLibraryViewModel: ObservableObject{
    func authenticate() // MARK: - 认证并加载媒体库
    func showLibrarySelection() // MARK: - 显示媒体库选择界面
    func selectLibrary(_ library: JellyfinLibrary) // MARK: - 选择媒体库并加载内容
    func selectSeries(_ series: JellyfinMediaItem) // MARK: - 选择系列并加载季节
    func selectSeason(_ season: JellyfinMediaItem) // MARK: - 选择季节并加载剧集
    func goBack() // MARK: - 返回上一级
    func refresh() // MARK: - 刷新当前媒体库
    func getImageUrl(for item: JellyfinMediaItem, type: String = "Primary", maxWidth: Int = 600) -> URL? // MARK: - 获取媒体项目的海报图片URL
    func createVideoPlayerContainer(for item: JellyfinMediaItem, onDismiss: @escaping () -> Void) -> VLCPlayerContainer? // MARK: - 创建基于VLCUI的视频播放器容器
    @available(*, deprecated, message: "使用 createVideoPlayerContainer 替代")
    func createVideoPlayerViewModel(for item: JellyfinMediaItem) -> VideoPlayerViewModel // MARK: - 创建统一的视频播放器视图模型 (已弃用)
    func getEpisodes(for seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) // MARK: - 获取剧集列表
    func diagnoseConnection() -> String // MARK: - 诊断连接问题
    func performDetailedConnectionTest() async // MARK: - 执行详细的连接测试
}
/// MediaLibraryViewModel
class MediaLibraryViewModel: ObservableObject {
    func refreshLibraries() // MARK: - 刷新媒体库列表
    func removeLibrary(withId id: UUID) // MARK: - 删除媒体库
    func testAllConnections() // MARK: - 测试所有媒体库连接
    func testConnection(for libraryId: UUID) // MARK: - 测试特定媒体库的连接
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
#### Overlays.SortSelectionOverlay: 排序方式选择浮窗
#### Components.WebDAVStateViews: WebDAV库各类状态视图
## JellyfinLibraryViews
### JellyfinMediaLibraryView: Jellyfin库界面，海报墙视图
- 显示选择的Jellyfin媒体库内所有文件，将电影和剧集都处理为类剧集结构
- 点击海报进入对应的JellyfinMediaDetailView详情页面
- 简化架构：移除直接播放逻辑，专注于媒体展示和导航功能
#### Overlays.JellyfinSortSelectionOverlay: 排序方式选择浮窗
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
- 提供工厂方法为不同媒体源创建播放器
- 集成错误处理和加载状态管理
- 支持WebDAV、Jellyfin和本地文件播放
### VLCPlayerView: 播放器界面，使用VLCUI库构建，接受视频原始文件名，视频Url和字幕Url，根据视频Url解析文件信息，进入后使用DanDanPlayAPI寻找字幕，加入到字幕轨中同时加载弹幕和字幕
- 基于VLCUIVideoPlayerView构建现代化播放器界面
- 集成弹幕系统和字幕管理
- 支持实时播放状态监控和控制
#### VLCUI组件:
##### VLCUIVideoPlayerView: VLCUI主播放器SwiftUI视图组件
##### VLCVideoPlayerUIView: 底层UIKit包装的VLC播放器视图，处理VLC播放器的底层交互
#### Overlays.DanmakuOverlayLayer: 弹幕显示覆盖层，与VLCUI播放器协同工作
#### Overlays.InformationOverlay: 进度条覆盖层，配有视频音频轨选择按钮，字幕选择按钮，弹幕开关按钮，弹幕匹配按钮，弹幕设置按钮，基于VLCUI的控制接口
#### Overlays.SoundTrackOverlay: 音轨选择浮窗，利用VLCUI的音轨管理功能
#### Overlays.SubTrackOverlay: 视频字幕选择浮窗，支持VLCUI的字幕轨道切换
#### Overlays.DanmaSelecOverlay: 弹幕匹配浮窗，将当前播放视频Url传入DanDanPlayAPI获取全部剧集可能列表，用户选择后重新加载弹幕轨并播放
#### Overlays.DanmaSettingOverlay: 弹幕设置浮窗，可以设置弹幕字体大小，速度，同屏最多弹幕密度，弹幕透明度

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
- `VLCPlayerContainer.forWebDAV()`: WebDAV媒体播放
- `VLCPlayerContainer.forJellyfin()`: Jellyfin媒体播放  
- `VLCPlayerContainer.forLocalFile()`: 本地文件播放

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