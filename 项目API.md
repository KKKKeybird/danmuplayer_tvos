# DanmuPlayer tvOS 项目API文档

## 📱 项目概述
DanmuPlayer tvOS 是一个功能完整的 Apple TV 弹幕播放器应用，支持 WebDAV 和 Jellyfin 双媒体服务器，集成弹弹Play API 提供智能弹幕匹配功能。项目采用现代化的 SwiftUI + MVVM 架构，使用 VLCKitSPM 和 VLCUI 构建高性能视频播放器。

## 🏗️ 技术栈说明
- **SwiftUI**: tvOS界面开发框架
- **VLCKitSPM**: VLC媒体播放器核心库，用于视频解码和播放
- **VLCUI**: VLC播放器的SwiftUI界面组件库，提供现代化的播放器UI
- **Combine**: 响应式编程框架，用于数据绑定和状态管理
- **WebDAV**: 分布式网络文件系统协议支持
- **Jellyfin API**: 开源媒体服务器API集成

## 🎯 核心功能架构

### 双服务器支持架构
项目实现了统一的媒体库抽象层，同时支持：
- **WebDAV 服务器**: 基于文件浏览的传统媒体管理
- **Jellyfin 服务器**: 基于元数据的现代媒体管理

### 统一媒体结构设计
按照"将电影和剧集都处理为类剧集结构"的设计理念：
- **电影处理**: 电影被当作只有一季一集的剧集来处理
- **剧集处理**: 保持原有的多季多集结构  
- **界面统一**: 所有媒体项目都使用相同的详情页和播放流程

### VLCUI集成架构
项目使用VLCUI库构建现代化播放器界面：
- **VLCUIVideoPlayerView**: 主要的视频播放器SwiftUI视图组件
- **VLCVideoPlayerUIView**: 底层UIKit包装的VLC播放器视图
- **响应式状态管理**: 完整的播放状态绑定和控制

## 📂 项目架构详解

### 🗂️ Models - 数据模型层

#### MediaLibraryModels - 媒体库配置
```swift
// 媒体库服务器类型枚举
enum MediaLibraryServerType: String, Codable, CaseIterable {
    case webdav = "webdav"
    case jellyfin = "jellyfin"
    var displayName: String { get }
}

// 统一媒体库配置
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

// 媒体库配置管理器
class MediaLibraryConfigManager: ObservableObject {
    @Published var configs: [MediaLibraryConfig]
    func loadConfigs()
    func saveConfigs()
    func addConfig(_ config: MediaLibraryConfig)
    func updateConfig(_ config: MediaLibraryConfig)
    func removeConfig(withId id: UUID)
    func validateConfig(_ config: MediaLibraryConfig) -> Bool
}
```

#### JellyfinModels - Jellyfin数据模型
```swift
// Jellyfin用户认证
struct JellyfinUser: Codable {
    let id: String
    let name: String
    let serverId: String
    let hasPassword: Bool
    // ... 其他属性
}

// Jellyfin媒体库
struct JellyfinLibrary: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let collectionType: String?
    let type: String
    // ... 其他属性
}

// Jellyfin媒体项目（统一的电影/剧集模型）
struct JellyfinMediaItem: Codable, Identifiable {
    let id: String
    let name: String
    let type: String // "Movie", "Series", "Season", "Episode"
    let overview: String?
    let communityRating: Double?
    let productionYear: Int?
    let genres: [String]?
    let seriesName: String?
    let indexNumber: Int? // 集数
    let parentIndexNumber: Int? // 季数
    // ... 其他属性
    
    var duration: TimeInterval? { 
        guard let ticks = runTimeTicks else { return nil }
        return TimeInterval(ticks) / 10_000_000.0
    }
}

// 剧集类型别名（统一处理）
typealias JellyfinEpisode = JellyfinMediaItem

// 字幕轨道信息
struct JellyfinSubtitleTrack: Codable {
    let index: Int
    let language: String?
    let displayTitle: String?
    let isDefault: Bool
    let isExternal: Bool
    let deliveryUrl: String?
}
```

#### DanDanPlayModels - 弹弹Play数据模型
```swift
// 弹弹Play剧集信息
struct DanDanPlayEpisode: Identifiable, Codable {
    let animeId: Int
    let animeTitle: String
    let episodeId: Int
    let episodeTitle: String
    let shift: Double? // 弹幕偏移时间
    var id: Int { episodeId }
    var displayTitle: String {
        return "\(animeTitle) - \(episodeTitle)"
    }
}

// 弹幕评论数据
struct DanmakuComment: Codable, Identifiable {
    let id: UUID = UUID()
    let time: Double
    let mode: Int // 弹幕类型: 1-滚动, 5-顶部, 4-底部
    let fontSize: Int
    let colorValue: Int
    let timestamp: TimeInterval
    let content: String
    
    var color: Color { /* 颜色转换逻辑 */ }
}
```

#### WebDAVModels - WebDAV数据模型
```swift
// WebDAV认证信息
struct Credentials {
    let username: String
    let password: String
}

// WebDAV文件项目
struct WebDAVItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?
    
    var isVideoFile: Bool { 
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm"]
        let ext = (name as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
}
```

### 🔧 Utilities - 工具层

#### Networking - 网络通信层
```swift
// 网络错误枚举
enum NetworkError: Error, LocalizedError {
    case connectionFailed
    case unauthorized  
    case invalidURL
    case invalidResponse
    case parseError
    case serverError(Int)
    case notFound
    case noData
    case authenticationFailed
    
    var localizedDescription: String { /* 错误描述 */ }
}

// WebDAV客户端
class WebDAVClient {
    let baseURL: URL
    let credentials: Credentials?
    
    init(baseURL: URL, credentials: Credentials? = nil)
    
    // 获取目录文件列表
    func fetchDirectory(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void)
    
    // 获取文件的流媒体URL
    func getStreamingURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void)
    
    // 测试WebDAV连接
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void)
}

// Jellyfin客户端
class JellyfinClient {
    let serverURL: URL
    private var authenticatedUserId: String?
    private var authToken: String?
    
    init(serverURL: URL, username: String?, password: String?)
    
    // 用户认证
    func authenticate(completion: @escaping (Result<JellyfinUser, Error>) -> Void)
    
    // 获取媒体库列表
    func getLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void)
    
    // 获取媒体库中的项目
    func getLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void)
    
    // 获取剧集列表
    func getEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
    
    // 获取播放URL
    func getPlaybackUrl(itemId: String) -> URL?
    
    // 获取图片URL  
    func getImageUrl(itemId: String, type: String = "Primary", maxWidth: Int = 600) -> URL?
    
    // 获取字幕轨道列表
    func getSubtitleTracks(for itemId: String, completion: @escaping (Result<[JellyfinSubtitleTrack], Error>) -> Void)
    
    // 获取推荐字幕URL
    func getRecommendedSubtitleURL(for itemId: String, completion: @escaping (URL?) -> Void)
}

// 弹弹Play API客户端
class DanDanPlayAPI {
    private let baseURL = "https://api.dandanplay.net"
    
    // 自动识别剧集（返回最佳匹配结果）
    func identifyEpisode(for videoURL: URL, overrideFileName: String? = nil, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void)
    
    // 获取候选剧集列表供用户手动选择
    func fetchCandidateEpisodeList(for videoURL: URL, overrideFileName: String? = nil, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void)
    
    // 加载弹幕数据
    func loadDanmakuComments(for episode: DanDanPlayEpisode, completion: @escaping (Result<[DanmakuComment], Error>) -> Void)
    
    // 加载弹幕并转换为ASS格式
    func loadDanmakuAsASS(for episode: DanDanPlayEpisode, completion: @escaping (Result<String, Error>) -> Void)
}
```

#### CacheUtilities - 缓存管理层
```swift
// Jellyfin多级缓存管理
class JellyfinCache {
    static let shared: JellyfinCache
    
    // 媒体库项目缓存（30分钟）
    func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String)
    func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]?
    
    // 剧集元数据缓存（1小时）
    func cacheEpisodeMetadata(_ episode: JellyfinEpisode)
    func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode?
    func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode])
    
    // 季节列表缓存（1小时）  
    func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String)
    func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]?
    
    // 图片缓存（7天）
    func cacheImage(_ image: UIImage, for imageURL: URL)
    func getCachedImage(for imageURL: URL) -> UIImage?
    
    // 缓存管理
    func clearAllCache()
    func getCacheSize() -> Int64
}

// 弹弹Play缓存管理
class DanDanPlayCache {
    static let shared: DanDanPlayCache
    
    // ASS字幕内容缓存（2小时）
    func cacheASSSubtitle(_ assContent: String, for episodeId: Int)
    func getCachedASSSubtitle(for episodeId: Int) -> String?
    
    // 剧集信息缓存（7天）
    func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileURL: URL)
    func getCachedEpisodeInfo(for fileURL: URL) -> DanDanPlayEpisode?
    
    // 弹幕评论缓存
    func cacheDanmakuComments(_ comments: [DanmakuComment], for episodeId: Int)
    func getCachedDanmakuComments(for episodeId: Int) -> [DanmakuComment]?
    
    // 缓存清理
    func clearAllCache()
    func getCacheSize() -> Int64
}
```

#### DanmaUtilities - 弹幕工具层
```swift
// 弹幕解析器
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
    
    // 解析单条弹幕参数字符串
    static func parseComment(p: String, m: String) -> ParsedComment?
}

// 弹幕转字幕转换器
class DanmakuToSubtitleConverter {
    enum SubtitleFormat {
        case srt
        case ass
    }
    
    // 弹幕转SRT字幕
    static func convertToSRT(_ comments: [DanmakuComment]) -> String
    
    // 弹幕转ASS字幕  
    static func convertToASS(_ comments: [DanmakuComment], videoWidth: Int = 1920, videoHeight: Int = 1080) -> String
    
    // 缓存弹幕为本地字幕文件
    static func cacheDanmakuAsSubtitle(_ comments: [DanmakuComment], format: SubtitleFormat, episodeId: Int, episodeNumber: Int? = nil) throws -> URL
    
    // 获取缓存字幕文件URL
    static func getCachedSubtitleURL(episodeId: Int, episodeNumber: Int? = nil, format: SubtitleFormat) -> URL?
    
    // 清理缓存字幕
    static func clearAllCachedSubtitles()
    static func getSubtitleCacheSize() -> Int64
}

// VLC弹幕字幕轨道管理器
class VLCSubtitleTrackManager {
    private var player: VLCMediaPlayer
    
    init(player: VLCMediaPlayer)
    
    // 添加弹幕字幕轨道（ASS格式）
    func addDanmakuTrack(from danmakuData: Data, episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
    
    // 移除弹幕轨道，恢复原始字幕
    func removeDanmakuTrack()
    
    // 从缓存添加弹幕字幕轨道
    func addDanmakuTrackFromCache(episodeId: Int, format: SubtitleFormat = .ass, episodeNumber: Int? = nil) -> Bool
    
    // 切换弹幕显示状态
    func toggleDanmaku(_ enabled: Bool, danmakuData: Data? = nil, episodeId: Int? = nil, episodeNumber: Int? = nil)
    
    // 清理资源
    func cleanup()
}
```

### 🎬 ViewModels - 视图模型层

#### 媒体库管理视图模型
```swift
// 主媒体库视图模型
class MediaLibraryViewModel: ObservableObject {
    @Published var mediaLibraries: [MediaLibrary] = []
    @Published var connectionStatus: [UUID: Bool] = [:]
    let configManager = MediaLibraryConfigManager()
    
    func refreshLibraries()
    func removeLibrary(withId id: UUID)
    func testAllConnections()
    func testConnection(for libraryId: UUID)
}

// WebDAV文件浏览视图模型
class FileBrowserViewModel: ObservableObject {
    @Published var items: [WebDAVItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingVideoPlayer = false
    @Published var selectedVideoItem: WebDAVItem?
    
    private let client: WebDAVClient
    private let config: MediaLibraryConfig
    
    enum SortOption: CaseIterable {
        case name, date, size
        var displayName: String { /* 显示名称 */ }
        var systemImage: String { /* 系统图标 */ }
    }
    
    func loadDirectory(path: String? = nil)
    func testWebDAVConnection()
    func createChildViewModel(for item: WebDAVItem) -> FileBrowserViewModel
    func playVideo(item: WebDAVItem)
    func getVideoStreamingURL(for item: WebDAVItem, completion: @escaping (Result<URL, Error>) -> Void)
    func findSubtitleFiles(for videoItem: WebDAVItem) -> [WebDAVItem]
    func sortItems(by option: SortOption)
    
    // 媒体播放准备
    func prepareMediaForPlayback(item: WebDAVItem, completion: @escaping (URL, [URL]) -> Void)
}

// Jellyfin媒体库视图模型
class JellyfinMediaLibraryViewModel: ObservableObject {
    @Published var libraries: [JellyfinLibrary] = []
    @Published var mediaItems: [JellyfinMediaItem] = []
    @Published var seasons: [JellyfinMediaItem] = []
    @Published var episodes: [JellyfinEpisode] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedLibrary: JellyfinLibrary?
    @Published var selectedSeries: JellyfinMediaItem?
    @Published var selectedSeason: JellyfinMediaItem?
    @Published var currentLevel: BrowsingLevel = .libraries
    @Published var isAuthenticated = false
    @Published var isPerformingDetailedTest = false
    @Published var connectionTestResults: [String] = []
    @Published var showingLibrarySelection = false
    
    enum BrowsingLevel {
        case libraries, mediaItems, seasons, episodes
    }
    
    private let client: JellyfinClient
    private let config: MediaLibraryConfig
    
    var jellyfinClient: JellyfinClient { return client }
    
    // 认证和媒体库管理
    func authenticate()
    func showLibrarySelection()
    func selectLibrary(_ library: JellyfinLibrary)
    func selectSeries(_ series: JellyfinMediaItem)
    func selectSeason(_ season: JellyfinMediaItem)
    func goBack()
    func refresh()
    
    // 媒体处理
    func getImageUrl(for item: JellyfinMediaItem, type: String = "Primary", maxWidth: Int = 600) -> URL?
    func prepareMediaForPlayback(item: JellyfinMediaItem, completion: @escaping (URL, [URL]) -> Void)
    func validatePlayability(for item: JellyfinMediaItem) -> Bool
    func getEpisodes(for seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
    
    // 统一剧集结构处理
    func getEpisodesForUnifiedStructure(for item: JellyfinMediaItem, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void)
    
    // 连接诊断
    func diagnoseConnection() -> String
    func performDetailedConnectionTest() async
}
```

### 🖥️ Views - 用户界面层

#### MediaLibraryViews - 媒体库主界面
```swift
// 媒体库列表主页
struct MediaLibraryListView: View {
    @StateObject private var viewModel = MediaLibraryViewModel()
    @State private var showingAddConfig = false
    @State private var editingConfig: MediaLibraryConfig?
    
    // 显示所有配置的媒体库，支持添加、编辑、删除
    // 显示连接状态指示器
    // 点击进入对应的媒体库界面
}

// 媒体库配置界面  
struct MediaLibraryConfigView: View {
    let configManager: MediaLibraryConfigManager
    let editingConfig: MediaLibraryConfig?
    
    // 支持配置WebDAV和Jellyfin两种服务器类型
    // 表单验证和连接测试
    // Jellyfin自动媒体库选择
}
```

#### WebDAVLibraryViews - WebDAV文件浏览界面
```swift
// WebDAV文件列表界面
struct FileListView: View {
    @StateObject private var viewModel: FileBrowserViewModel
    @State private var sortOption: FileBrowserViewModel.SortOption = .name
    @State private var showingSortMenu = false
    @State private var showingVideoPlayer = false
    
    // 文件浏览器视图，支持目录导航
    // 文件类型图标区分
    // 排序选项（名称、日期、大小）
    // 点击视频文件自动查找字幕并进入播放器
    
    private func handleItemTap(_ item: WebDAVItem) {
        if item.isDirectory {
            // 进入子目录
            navigationPath.append(item)
        } else if item.isVideoFile {
            // 播放视频，自动匹配字幕
            selectedVideoItem = item
            showingVideoPlayer = true
        }
    }
}

// WebDAV排序选择浮窗
struct WebDAVSortView: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    let onApply: (() -> Void)?
    
    // 提供排序方式选择界面
}

// WebDAV视频播放器包装器
struct WebDAVVideoPlayerWrapper: View {
    let videoItem: WebDAVItem
    let viewModel: FileBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var playerContainer: VLCPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 负责准备WebDAV视频播放
    // 自动查找匹配的字幕文件
    // 使用统一的VLCPlayerContainer创建播放器
}
```

#### JellyfinLibraryViews - Jellyfin媒体库界面
```swift
// Jellyfin媒体库主页
struct JellyfinMediaLibraryView: View {
    let config: MediaLibraryConfig
    @StateObject private var viewModel: JellyfinMediaLibraryViewModel
    @State private var selectedItem: JellyfinMediaItem?
    @State private var showingMediaDetail = false
    @State private var sortOption: SortOption = .recentlyWatched
    
    enum SortOption: String, CaseIterable {
        case recentlyWatched = "最近观看"
        case dateAdded = "添加时间" 
        case name = "名称"
        case releaseDate = "上映时间"
        case rating = "评分"
        
        var systemImage: String { /* 对应图标 */ }
    }
    
    // 显示Jellyfin媒体库的海报墙
    // 统一处理电影和剧集显示
    // 支持多种排序方式
    // 点击海报进入详情页面
}

// Jellyfin认证界面
struct JellyfinAuthenticationView: View {
    let isLoading: Bool
    let errorMessage: String?
    let isPerformingDetailedTest: Bool
    let connectionTestResults: [String]
    let onAuthenticate: () -> Void
    let onPerformDetailedTest: () async -> Void
    
    // 显示认证状态和连接测试结果
    // 提供重试按钮
}

// 媒体项目海报卡片
struct MediaItemCard: View {
    let item: JellyfinMediaItem
    let imageUrl: URL?
    let onTap: () -> Void
    
    // 统一的海报卡片组件
    // 支持电影和剧集的元数据显示
    // 播放进度指示器
}
```

#### JellyfinMediaItemViews - Jellyfin媒体详情界面
```swift
// Jellyfin媒体详情页面
struct JellyfinMediaDetailView: View {
    let item: JellyfinMediaItem
    let viewModel: JellyfinMediaLibraryViewModel
    
    @State private var episodes: [JellyfinEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: JellyfinMediaItem?
    @State private var showingVideoPlayer = false
    
    // 统一的媒体详情界面
    // 上方显示海报、元数据和简介
    // 下方显示剧集列表（电影显示为单集）
    // 直接在详情页处理播放逻辑
    // 支持统一剧集结构的电影和剧集
    
    private func loadEpisodesForUnifiedStructure() {
        viewModel.getEpisodesForUnifiedStructure(for: item) { result in
            // 处理统一的剧集结构加载
            // 电影自动转换为虚拟第1季第1集
            // 剧集保持原有结构
        }
    }
    
    private func playItem(_ mediaItem: JellyfinMediaItem) {
        // 验证可播放性
        guard viewModel.validatePlayability(for: mediaItem) else { return }
        
        // 预处理媒体（包括获取字幕）
        viewModel.prepareMediaForPlayback(item: mediaItem) { playbackURL, subtitleURLs in
            DispatchQueue.main.async {
                self.selectedItem = mediaItem
                self.showingVideoPlayer = true
            }
        }
    }
}

// 剧集卡片组件
struct EpisodeCard: View {
    let episode: JellyfinEpisode
    let viewModel: JellyfinMediaLibraryViewModel
    let onPlay: (JellyfinMediaItem) -> Void
    
    // 统一的剧集卡片显示
    // 支持电影和剧集的不同显示模式
    // 播放进度指示器
}

// Jellyfin视频播放器包装器
struct JellyfinVideoPlayerWrapper: View {
    let item: JellyfinMediaItem
    let viewModel: JellyfinMediaLibraryViewModel
    let onDismiss: () -> Void
    
    @State private var playerContainer: VLCPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 负责Jellyfin视频播放准备
    // 自动获取和缓存字幕
    // 使用统一的VLCPlayerContainer创建播放器
    
    private func generateFileName() -> String {
        // 为弹幕匹配生成合适的文件名
        // 电影：直接使用电影名称  
        // 剧集：组合剧集名称和集数信息
    }
}
```

#### PlayerViews - 视频播放器界面（基于VLCUI构建）
```swift
// VLC播放器容器
struct VLCPlayerContainer: View {
    let videoURL: URL
    let originalFileName: String
    let subtitleURLs: [URL]
    let onDismiss: () -> Void
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 视频播放器容器，负责创建和管理VLC播放器实例
    // 统一的播放器创建接口
    // 集成错误处理和加载状态管理
    
    /// 统一的播放器容器创建方法
    static func create(
        videoURL: URL,
        originalFileName: String, 
        subtitleURLs: [URL] = [],
        onDismiss: @escaping () -> Void
    ) -> VLCPlayerContainer {
        return VLCPlayerContainer(
            videoURL: videoURL,
            originalFileName: originalFileName,
            subtitleURLs: subtitleURLs,
            onDismiss: onDismiss
        )
    }
}

// VLC播放器主视图
struct VLCPlayerView: View {
    let videoURL: URL
    let originalFileName: String
    let subtitleURLs: [URL]
    let onDismiss: () -> Void
    
    @StateObject private var viewModel: VLCUIPlayerViewModel
    @StateObject private var overlayTimer = TimerProxy()
    @StateObject private var displayLink = DisplayLinkDriver()
    
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var selectedEpisode: DanDanPlayEpisode?
    @State private var candidateEpisodes: [DanDanPlayEpisode] = []
    @State private var overlayDanmaku: [DanmakuComment] = []
    
    // 基于VLCUI构建的现代化播放器界面
    // 集成弹幕系统和字幕管理
    // 自动弹幕识别和加载
    // 支持手动弹幕选择
    // 完整的播放控制界面
    
    private func setupDanmaku() {
        // 使用传入的原始文件名进行弹幕识别
        DanDanPlayAPI().identifyEpisode(for: videoURL, overrideFileName: originalFileName) { result in
            switch result {
            case .success(let episode):
                selectedEpisode = episode
                loadDanmakuForEpisode(episode)
            case .failure:
                // 获取候选列表供用户手动选择
                loadCandidateEpisodes()
            }
        }
    }
}

// VLCUI SwiftUI包装器
struct VLCUIVideoPlayerView: View {
    @Binding var vlcPlayer: VLCMediaPlayer?
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isPlaying: Bool
    let videoURL: URL
    let onPlayerReady: (VLCMediaPlayer) -> Void
    
    // VLCUI的SwiftUI包装组件
    // 处理VLC播放器的生命周期管理
    // 提供响应式状态绑定
}

// 播放器设置界面
struct VideoPlayerSettingsView: View {
    @Binding var isPresented: Bool
    let vlcPlayer: VLCMediaPlayer?
    let originalFileName: String
    let videoURL: URL
    
    // 综合的播放器设置界面
    // 字幕轨道选择和管理
    // 音轨选择
    // 弹幕匹配和设置
    // 播放速度调整
}

// 弹幕覆盖层
struct DanmakuOverlayLayer: View {
    let comments: [DanmakuComment]
    let currentTime: Double
    let isPlaying: Bool
    @State private var settings = DanmakuDisplaySettings()
    
    // 高性能弹幕渲染覆盖层
    // 支持滚动、顶部、底部弹幕
    // 可调节透明度、字体大小、滚动速度
    // 弹幕碰撞检测和位置优化
}
```

## 🔄 统一播放流程架构

### 设计原则
遵循单一职责原则，播放逻辑在各自的详情页面中直接调用：

#### WebDAV播放流程
```
MediaLibraryListView → FileListView → 直接调用播放器 → VLCPlayerContainer
```

#### Jellyfin播放流程  
```
MediaLibraryListView → JellyfinMediaLibraryView → JellyfinMediaDetailView → 直接调用播放器 → VLCPlayerContainer
```

### 统一播放器创建
所有媒体源都使用相同的播放器创建方法：
```swift
let player = VLCPlayerContainer.create(
    videoURL: playbackURL,
    originalFileName: fileName,
    subtitleURLs: subtitleURLs,
    onDismiss: onDismiss
)
```

### 字幕管理责任分离
- **JellyfinMediaLibraryViewModel**: 负责Jellyfin字幕的获取、缓存和ASS转换
- **FileBrowserViewModel**: 负责WebDAV字幕文件的查找和匹配  
- **VLCPlayerContainer**: 只负责播放器的创建和管理
- **VLCPlayerView**: 处理弹幕识别、加载和显示

## 🎯 核心交互流程

### 1. 媒体库配置流程
1. 用户在 `MediaLibraryListView` 添加新的媒体库配置
2. 选择服务器类型（WebDAV 或 Jellyfin）
3. 填写连接信息并进行连接测试
4. Jellyfin 类型自动显示媒体库选择界面
5. 配置保存后返回主界面

### 2. WebDAV 媒体播放流程
1. 用户选择 WebDAV 媒体库进入 `FileListView`
2. 浏览目录结构，点击视频文件
3. `FileBrowserViewModel` 自动查找同目录下的字幕文件
4. 调用 `WebDAVClient.getStreamingURL` 获取播放链接
5. 使用 `VLCPlayerContainer.create` 创建播放器
6. 播放器启动后使用 `DanDanPlayAPI` 自动识别弹幕

### 3. Jellyfin 媒体播放流程
1. 用户选择 Jellyfin 媒体库进入 `JellyfinMediaLibraryView`
2. 显示海报墙，点击媒体项目进入 `JellyfinMediaDetailView`
3. 详情页使用 `getEpisodesForUnifiedStructure` 加载统一剧集结构
4. 用户选择集数，触发 `prepareMediaForPlayback`
5. 自动获取播放URL和字幕URL
6. 使用 `VLCPlayerContainer.create` 创建播放器
7. 播放器启动后根据媒体信息自动匹配弹幕

### 4. 弹幕系统工作流程
1. 播放器启动时，`VLCPlayerView` 使用 `originalFileName` 调用弹幕识别
2. `DanDanPlayAPI.identifyEpisode` 返回最佳匹配结果
3. 如果识别失败，自动获取候选列表供用户手动选择
4. 弹幕加载成功后通过 `DanmakuOverlayLayer` 实时渲染
5. 同时使用 `VLCSubtitleTrackManager` 将弹幕添加到字幕轨道

## 🚀 技术优势

### 1. 统一架构设计
- **双服务器支持**: 同时支持传统WebDAV和现代Jellyfin服务器
- **统一媒体结构**: 电影和剧集使用相同的处理流程
- **一致用户体验**: 不同媒体源提供相同的操作体验

### 2. 高性能缓存系统
- **多级缓存策略**: 不同数据类型采用不同的缓存时长
- **智能预缓存**: 批量缓存剧集元数据提升响应速度
- **缓存清理机制**: 自动清理过期缓存，避免存储空间浪费

### 3. 现代化播放器架构
- **VLCUI集成**: 基于SwiftUI的现代化播放器界面
- **响应式设计**: 完全的状态绑定和实时更新
- **弹幕系统**: 高性能的弹幕渲染和字幕轨道管理

### 4. 智能弹幕匹配
- **自动识别**: 基于文件信息的智能弹幕匹配
- **手动选择**: 识别失败时提供候选列表
- **缓存优化**: 用户选择结果自动缓存，避免重复识别

### 5. 完善的错误处理
- **网络异常恢复**: 完整的网络错误处理和重试机制
- **连接状态监控**: 实时显示服务器连接状态
- **用户友好提示**: 详细的错误信息和解决建议

这个架构设计确保了项目的可维护性、扩展性和用户体验的一致性，为Apple TV平台提供了完整的弹幕播放解决方案。