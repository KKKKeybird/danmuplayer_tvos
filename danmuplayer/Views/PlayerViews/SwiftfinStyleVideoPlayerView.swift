/// 基于真实 Swiftfin tvOS 架构的视频播放器
import SwiftUI
import VLCKitSPM
import Foundation
import Combine
import AVFoundation

// MARK: - Player Models

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

// MARK: - Video Player View Model

/// 管理视频播放状态、弹幕加载和番剧识别
@MainActor
@available(tvOS 17.0, *)
class VideoPlayerViewModel: ObservableObject {
    @Published var series: DanDanPlayEpisode?
    @Published var candidateSeriesList: [DanDanPlayEpisode] = []
    @Published var danmakuComments: [DanmakuComment] = []
    @Published var subtitleURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSeriesSelection = false
    @Published var player: AVPlayer?

    // 弹幕设置
    @Published var danmakuSettings = DanmakuSettings()
    
    // 弹幕原始数据（用于VLC字幕加载）
    private var danmakuData: Data?
    
    // VLC字幕轨道管理器
    private var subtitleManager: VLCSubtitleTrackManager?

    private let danDanAPI = DanDanPlayAPI()
    var subtitleFiles: [WebDAVItem] = []
    
    // 播放器URL - 供外部访问
    var videoURL: URL? {
        return _videoURL
    }
    private var _videoURL: URL?
    
    // 退出播放器的闭包
    var dismiss: (() -> Void)?
    
    // Jellyfin支持
    private var jellyfinClient: JellyfinClient?
    private var jellyfinMediaItem: JellyfinMediaItem?

    init(videoURL: URL? = nil, subtitleFiles: [WebDAVItem] = []) {
        self._videoURL = videoURL
        self.subtitleFiles = subtitleFiles

        if let url = videoURL {
            setupPlayer(with: url)
            identifySeries(videoURL: url)
        }
    }
    
    /// 无参构造函数 - 用于错误情况
    convenience init() {
        self.init(videoURL: nil, subtitleFiles: [])
    }
    
    /// Jellyfin媒体项目初始化器
    init(jellyfinClient: JellyfinClient, mediaItem: JellyfinMediaItem) {
        self.jellyfinClient = jellyfinClient
        self.jellyfinMediaItem = mediaItem
        
        Task {
            await setupJellyfinPlayer()
        }
    }

    /// 设置播放器
    func setupPlayer(with url: URL) {
        self._videoURL = url
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // 自动加载字幕
        if let subtitleFile = findBestSubtitleFile() {
            loadSubtitle(subtitleFile: subtitleFile)
        }
    }
    
    /// 设置Jellyfin播放器
    func setupJellyfinPlayer() async {
        guard let client = jellyfinClient,
              let mediaItem = jellyfinMediaItem else {
            await MainActor.run {
                self.errorMessage = "Jellyfin客户端或媒体项目未设置"
            }
            return
        }
        
        guard let playbackURL = client.getPlaybackUrl(itemId: mediaItem.id) else {
            await MainActor.run {
                self.errorMessage = "无法获取播放地址"
            }
            return
        }
        
        await MainActor.run {
            self._videoURL = playbackURL
            let playerItem = AVPlayerItem(url: playbackURL)
            self.player = AVPlayer(playerItem: playerItem)
            
            // 使用Jellyfin媒体项目信息进行弹幕识别
            self.identifySeriesFromJellyfin(mediaItem: mediaItem)
        }
    }

    /// 根据视频URL调用番剧识别
    func identifySeries(videoURL: URL) {
        isLoading = true
        errorMessage = nil

        danDanAPI.identifyEpisode(for: videoURL) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let series):
                    self.series = series
                    self.loadDanmaku()
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    /// 根据Jellyfin媒体项目信息进行番剧识别
    func identifySeriesFromJellyfin(mediaItem: JellyfinMediaItem) {
        isLoading = true
        errorMessage = nil
        
        // 使用Jellyfin的媒体信息构建识别用的文件名
        let fileName = mediaItem.name
        
        danDanAPI.identifyEpisodeByName(fileName) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let series):
                    self.series = series
                    self.loadDanmaku()
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 获取候选番剧列表
    func fetchCandidateSeriesList() {
        guard let videoURL = _videoURL else { return }

        isLoading = true
        danDanAPI.fetchCandidateEpisodeList(for: videoURL) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let seriesList):
                    self.candidateSeriesList = seriesList
                    self.showingSeriesSelection = true
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 加载识别番剧的弹幕数据
    private func loadDanmaku() {
        guard let series = series else { return }

        danDanAPI.loadDanmaku(for: series) { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    // 直接解析为统一的弹幕参数格式
                    guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: data) else {
                        print("无法解析弹幕JSON数据")
                        return
                    }
                    
                    // 处理可能为null的comments数组
                    let comments = commentResult.comments ?? []
                    let danmakuParams = comments.compactMap { $0.parsedParams }
                    
                    // 转换为DanmakuComment格式（为了兼容现有UI）
                    self.danmakuComments = danmakuParams.map { params in
                        DanmakuComment(
                            time: params.time,
                            mode: params.mode,
                            fontSize: 25,
                            colorValue: Int(params.color),
                            timestamp: params.time,
                            content: params.content
                        )
                    }
                    
                    // 如果有VLC播放器实例且弹幕已启用，加载弹幕作为字幕
                    self.loadDanmakuToVLC(data)
                    
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    /// 将弹幕数据加载到VLC播放器作为字幕
    private func loadDanmakuToVLC(_ danmakuData: Data) {
        // 这个方法会被VLC播放器视图调用
        // 存储弹幕数据供播放器使用
        self.danmakuData = danmakuData
    }
    
    /// VLC播放器设置弹幕的方法（不影响原始字幕）
    func setupVLCDanmaku(for vlcPlayer: VLCMediaPlayer) {
        // 初始化字幕管理器（如果还没有的话）
        if subtitleManager == nil {
            subtitleManager = VLCSubtitleTrackManager(player: vlcPlayer)
        }
        
        // 使用智能字幕管理器处理弹幕
        subtitleManager?.toggleDanmaku(danmakuSettings.isEnabled, danmakuData: danmakuData)
        
        // 调试信息（开发阶段可用）
        #if DEBUG
        if let debugInfo = subtitleManager?.getSubtitleTracksDebugInfo() {
            print(debugInfo)
        }
        #endif
    }
    
    private func colorToInt(_ color: Color) -> Int {
        // 简化的颜色转换，返回白色作为默认值
        // 实际项目中可能需要更精确的颜色提取
        return 0xFFFFFF
    }
    
    /// 清理资源
    func cleanup() {
        subtitleManager = nil
        danmakuData = nil
        player?.pause()
        player = nil
    }

    /// 加载字幕文件
    func loadSubtitle(subtitleFile: WebDAVItem) {
        // 这里可以实现字幕文件的加载逻辑
        // 对于WebDAV，需要获取字幕文件的URL
    }

    /// 查找最佳匹配的字幕文件
    private func findBestSubtitleFile() -> WebDAVItem? {
        guard let videoURL = _videoURL else { return nil }
        let videoBaseName = (videoURL.lastPathComponent as NSString).deletingPathExtension.lowercased()

        // 优先选择与视频文件名最匹配的字幕
        return subtitleFiles.first { subtitle in
            let subtitleBaseName = (subtitle.name as NSString).deletingPathExtension.lowercased()
            return subtitleBaseName.contains(videoBaseName) || videoBaseName.contains(subtitleBaseName)
        }
    }

    // MARK: - 播放控制方法
    
    /// 播放/暂停切换
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    /// 快进指定秒数
    func seekForward(seconds: Double = 10) {
        guard let player = player else { return }
        seekTo(offset: seconds, from: player.currentTime())
    }
    
    /// 快退指定秒数  
    func seekBackward(seconds: Double = 10) {
        guard let player = player else { return }
        seekTo(offset: -seconds, from: player.currentTime())
    }
    
    /// 跳转到指定时间
    func seekTo(time: CMTime) {
        guard let player = player else { return }
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    /// 从指定时间偏移跳转
    private func seekTo(offset: Double, from currentTime: CMTime) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }
        
        let newTime = CMTimeAdd(currentTime, CMTimeMakeWithSeconds(offset, preferredTimescale: 1000))
        
        // 确保不超出视频范围
        let clampedTime: CMTime
        if CMTimeCompare(newTime, .zero) < 0 {
            clampedTime = .zero
        } else if CMTimeCompare(newTime, duration) > 0 {
            clampedTime = duration
        } else {
            clampedTime = newTime
        }
        
        seekTo(time: clampedTime)
    }
    
    /// 获取当前播放时间
    func getCurrentTime() -> CMTime {
        return player?.currentTime() ?? .zero
    }
    
    /// 获取总时长
    func getDuration() -> CMTime {
        return player?.currentItem?.duration ?? .zero
    }
    
    /// 获取播放进度 (0.0 - 1.0)
    func getPlaybackProgress() -> Double {
        guard let player = player,
              let duration = player.currentItem?.duration,
              duration.seconds > 0 else { return 0.0 }
        
        let currentTime = player.currentTime()
        return currentTime.seconds / duration.seconds
    }
    
    /// 设置播放速率
    func setPlaybackRate(_ rate: Float) {
        player?.rate = rate
    }
    
    /// 获取当前播放状态
    func isPlaying() -> Bool {
        return player?.timeControlStatus == .playing
    }
    
    // MARK: - 统一数据源支持
    
    /// 便利初始化器，用于统一的数据源
    convenience init(dataSource: UnifiedPlayerDataSource) {
        // 创建DanDanPlayEpisode
        let episode = DanDanPlayEpisode(
            animeId: 0,
            animeTitle: dataSource.displayTitle,
            episodeId: 0,
            episodeTitle: dataSource.episodeTitle ?? "",
            shift: nil
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
        self.series = episode
        
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

/// 弹幕显示设置
struct DanmakuSettings {
    var isEnabled: Bool = true
    var opacity: Double = 0.8
    var fontSize: Double = 16.0
    var speed: Double = 1.0
    var maxCount: Int = 50
    var showScrolling: Bool = true
    var showTop: Bool = true
    var showBottom: Bool = true
}

// MARK: - 播放器状态管理

/// 播放器状态管理器
@MainActor
@available(tvOS 17.0, *)
class PlayerStateManager: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var isPaused: Bool = false
    @Published var isBuffering: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentDataSource: UnifiedPlayerDataSource?
    
    private var timeObserver: NSObjectProtocol?
    
    init() {
        setupObservers()
    }
    
    deinit {
        removeObservers()
    }
    
    private func setupObservers() {
        // 初始化观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .VLCMediaPlayerStateChanged,
            object: nil
        )
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
        }
    }
    
    func updateState(isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.isPaused = !isPlaying
    }
    
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
    func loadMedia(from dataSource: UnifiedPlayerDataSource) async throws
    func loadSubtitles(_ subtitleFiles: [SubtitleFile]) async throws
    func loadDanmaku(from url: URL) async throws
    func play()
    func pause()
    func stop()
    func seek(to time: TimeInterval)
}

/// 默认播放器服务实现
@available(tvOS 17.0, *)
class DefaultPlayerService: PlayerService {
    private let stateManager: PlayerStateManager
    private var vlcPlayer: VLCMediaPlayer?
    
    init(stateManager: PlayerStateManager) {
        self.stateManager = stateManager
    }
    
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
    
    func loadMedia(from dataSource: UnifiedPlayerDataSource) async throws {
        let media = VLCMedia(url: dataSource.videoURL)
        media.addOptions([
            "--network-caching": "3000",
            "--file-caching": "2000"
        ])
        
        vlcPlayer?.media = media
        
        // 根据媒体类型配置播放器
        let config = PlayerConfiguration(mediaType: dataSource.mediaType)
        try await configurePlayer(with: config, dataSource: dataSource)
    }
    
    private func configurePlayer(with config: PlayerConfiguration, dataSource: UnifiedPlayerDataSource) async throws {
        // 配置字幕
        if config.enableExternalSubtitles {
            try await loadSubtitles(dataSource.subtitleFiles)
        }
        
        // 配置弹幕
        if config.enableDanmaku {
            // 这里可以根据具体需求实现弹幕加载逻辑
            print("弹幕功能已启用")
        }
    }
    
    func loadSubtitles(_ subtitleFiles: [SubtitleFile]) async throws {
        guard let player = vlcPlayer else { return }
        
        for subtitleFile in subtitleFiles {
            guard let url = subtitleFile.url else { continue }
            
            do {
                player.addPlaybackSlave(url, type: .subtitle, enforce: false)
            } catch {
                throw PlayerError.networkError(underlying: error)
            }
        }
    }
    
    func loadDanmaku(from url: URL) async throws {
        guard let player = vlcPlayer else { return }
        
        do {
            // 调用VLC弹幕加载扩展
            try await player.loadDanmakuAsSubtitle(from: url)
        } catch {
            throw PlayerError.networkError(underlying: error)
        }
    }
    
    func play() {
        vlcPlayer?.play()
        stateManager.isPlaying = true
        stateManager.isPaused = false
    }
    
    func pause() {
        vlcPlayer?.pause()
        stateManager.isPlaying = false
        stateManager.isPaused = true
    }
    
    func stop() {
        vlcPlayer?.stop()
        stateManager.isPlaying = false
        stateManager.isPaused = true
        stateManager.currentTime = 0
    }
    
    func seek(to time: TimeInterval) {
        let vlcTime = VLCTime(int: Int32(time * 1000))
        vlcPlayer?.time = vlcTime
        stateManager.currentTime = time
    }
}

// MARK: - 播放器错误类型

enum PlayerError: LocalizedError {
    case unableToGetPlaybackURL
    case invalidDataSource
    case mediaLoadFailed(String)
    case subtitleLoadFailed(String)
    case danmakuLoadFailed(String)
    case networkError(underlying: Error)
    case configurationError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .unableToGetPlaybackURL:
            return "无法获取播放地址"
        case .invalidDataSource:
            return "无效的数据源"
        case .mediaLoadFailed(let message):
            return "媒体加载失败: \(message)"
        case .subtitleLoadFailed(let message):
            return "字幕加载失败: \(message)"
        case .danmakuLoadFailed(let message):
            return "弹幕加载失败: \(message)"
        case .networkError(let underlying):
            return "网络错误: \(underlying.localizedDescription)"
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .unknownError:
            return "未知错误"
        }
    }
}

// MARK: - 播放进度处理器

class ProgressHandler: ObservableObject {
    @Published var seconds: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var scrubbedProgress: Double = 0
    
    private var player: VLCMediaPlayer?
    private var progressTimer: Timer?
    
    init() {}
    
    func startTracking(player: VLCMediaPlayer) {
        self.player = player
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateProgress()
        }
    }
    
    func stopTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
        player = nil
    }
    
    private func updateProgress() {
        guard let player = player else { return }
        
        let currentSeconds = TimeInterval(player.time.intValue) / 1000.0
        let totalDuration = TimeInterval(player.media?.length.intValue ?? 0) / 1000.0
        
        DispatchQueue.main.async {
            self.seconds = currentSeconds
            self.duration = totalDuration
            
            if totalDuration > 0 {
                self.scrubbedProgress = currentSeconds / totalDuration
            }
        }
    }
}

@available(tvOS 17.0, *)
struct SwiftfinStyleVideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    @State private var isPresentingOverlay: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var currentProgressHandler: ProgressHandler = ProgressHandler()
    @State private var isPlaying: Bool = false
    @State private var currentOverlayType: OverlayType = .main
    @State private var confirmCloseWorkItem: DispatchWorkItem?
    
    @State private var isSliderFocused: Bool = false
    @StateObject private var overlayTimer: TimerProxy = .init()
    @Environment(\.dismiss) private var dismiss

    enum OverlayType {
        case main
        case confirmClose
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // VLC 播放器背景
                Color.black.ignoresSafeArea()
                
                // VLC 播放器视图
                VLCPlayerViewRepresentable(
                    player: $vlcPlayer,
                    progressHandler: $currentProgressHandler,
                    isPlaying: $isPlaying,
                    videoURL: viewModel.videoURL
                )
                .ignoresSafeArea()
                .onAppear(perform: setupPlayer)
                .onDisappear(perform: cleanupPlayer)
                
                                // 弹幕覆盖层
                if viewModel.danmakuSettings.isEnabled {
                    DanmakuOverlayLayer(
                        comments: viewModel.danmakuComments,
                        settings: viewModel.danmakuSettings,
                        currentTime: currentProgressHandler.seconds
                    )
                    .allowsHitTesting(false)
                }
                
                // Swiftfin 风格的覆盖层
                SwiftfinOverlay()
                    .environmentObject(overlayTimer)
                    .environmentObject(viewModel)
                    .environment(\.isPresentingOverlay, $isPresentingOverlay)
                    .environment(\.isScrubbing, $isScrubbing)
                    .environment(\.currentOverlayType, $currentOverlayType)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onPlayPauseCommand {
            handlePlayPausePress()
        }
        .onExitCommand {
            handleMenuPress()
        }
    }
    
    // MARK: - Swiftfin Overlay
    
    @ViewBuilder
    private func SwiftfinOverlay() -> some View {
        ZStack {
            switch currentOverlayType {
            case .main:
                SwiftfinMainOverlay()
            case .confirmClose:
                SwiftfinConfirmCloseOverlay()
            }
        }
        .isVisible(isPresentingOverlay)
        .animation(.linear(duration: 0.1), value: currentOverlayType)
        .onChange(of: isPresentingOverlay) { _, isPresenting in
            if !isPresenting {
                currentOverlayType = .main
            }
        }
        .onChange(of: currentOverlayType) { _, newType in
            if newType == .confirmClose {
                overlayTimer.pause()
            } else if isPresentingOverlay {
                overlayTimer.start(5)
            }
        }
        .onChange(of: overlayTimer.isActive) { _, isActive in
            guard !isActive else { return }
            
            withAnimation(.linear(duration: 0.3)) {
                isPresentingOverlay = false
            }
        }
        .onChange(of: viewModel.danmakuSettings.isEnabled) { _, isEnabled in
            // 当弹幕开关状态改变时，更新VLC字幕
            if let player = vlcPlayer {
                viewModel.setupVLCDanmaku(for: player)
            }
        }
    }
    
    @ViewBuilder
    private func SwiftfinMainOverlay() -> some View {
        VStack {
            // 顶部栏
            SwiftfinTopBarView()
                .padding(.top, 60)
                .padding(.horizontal, 90)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.9), location: 0),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .isVisible(!isScrubbing && isPresentingOverlay)
            
            Spacer()
            
            // 底部控制栏
            SwiftfinBottomBarView()
                .padding(.horizontal, 90)
                .padding(.bottom, 90)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.8), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .isVisible(isScrubbing || isPresentingOverlay)
        }
        .environmentObject(overlayTimer)
    }
    
    @ViewBuilder
    private func SwiftfinConfirmCloseOverlay() -> some View {
        VStack(spacing: 30) {
            Text("确认退出播放？")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 40) {
                Button("取消") {
                    currentOverlayType = .main
                }
                .buttonStyle(.bordered)
                
                Button("退出") {
                    vlcPlayer?.stop()
                    viewModel.dismiss?() ?? dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(60)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Top Bar View
    
    @ViewBuilder
    private func SwiftfinTopBarView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Button {
                    vlcPlayer?.stop()
                    viewModel.dismiss?() ?? dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white)
                        .padding()
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                
                Text(viewModel.series?.displayTitle ?? "视频播放")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                Spacer()
                
                SwiftfinBarActionButtons()
            }
            
            if let subtitle = viewModel.series?.episodeTitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.leading, 56)
            }
        }
    }
    
    // MARK: - Bottom Bar View
    
    @ViewBuilder
    private func SwiftfinBottomBarView() -> some View {
        VStack(spacing: 20) {
            // 标题和操作按钮
            HStack {
                Text(viewModel.series?.displayTitle ?? "视频播放")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                SwiftfinBarActionButtons()
            }
            
            // 进度条
            SwiftfinSlider(
                value: $currentProgressHandler.scrubbedProgress,
                isEditing: $isScrubbing,
                isFocused: $isSliderFocused
            ) { isEditing in
                if isEditing {
                    overlayTimer.pause()
                } else {
                    overlayTimer.start(5)
                }
            }
            .frame(height: 60)
            
            // 时间显示和播放状态
            HStack(spacing: 15) {
                Text(formatTime(currentProgressHandler.seconds))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .font(.body)
                
                // 播放状态图标
                if isPlaying {
                    Image(systemName: "pause.circle")
                        .foregroundColor(.white)
                        .font(.title2)
                        .frame(maxWidth: 40, maxHeight: 40)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundColor(.white)
                        .font(.title2)
                        .frame(maxWidth: 40, maxHeight: 40)
                }
                
                Spacer()
                
                Text("-" + formatTime(currentProgressHandler.duration - currentProgressHandler.seconds))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .font(.body)
            }
        }
    }
    
    // MARK: - Bar Action Buttons
    
    @ViewBuilder
    private func SwiftfinBarActionButtons() -> some View {
        HStack(spacing: 20) {
            // 弹幕按钮
            Button {
                viewModel.danmakuSettings.isEnabled.toggle()
            } label: {
                Image(systemName: viewModel.danmakuSettings.isEnabled ? "bubble.left.fill" : "bubble.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 选集按钮
            Button {
                viewModel.fetchCandidateSeriesList()
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 倍速菜单
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button("\(rate, specifier: "%.2g")x") {
                        vlcPlayer?.rate = Float(rate)
                    }
                }
            } label: {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Player Setup & Control
    
    private func setupPlayer() {
        guard let url = viewModel.videoURL else { return }
        
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        player.media = media
        
        // VLC 配置
        player.scaleFactor = 0
        player.audio?.volume = 100
        player.videoCropGeometry = nil
        player.videoAspectRatio = nil
        
        self.vlcPlayer = player
        self.currentProgressHandler.startTracking(player: player)
        
        // 设置弹幕（如果有的话）
        viewModel.setupVLCDanmaku(for: player)
        
        // 自动播放并显示控制界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            player.play()
            isPlaying = true
            showOverlayTemporarily()
        }
    }
    
    private func cleanupPlayer() {
        overlayTimer.stop()
        currentProgressHandler.stopTracking()
        vlcPlayer?.stop()
        vlcPlayer = nil
    }
    
    // MARK: - Remote Control Handlers
    
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up, .down:
            handleArrowPress()
        case .left:
            handleLeftArrowPress()
        case .right:
            handleRightArrowPress()
        @unknown default:
            break
        }
    }
    
    private func handleMenuPress() {
        overlayTimer.start(5)
        confirmCloseWorkItem?.cancel()
        
        if isPresentingOverlay && currentOverlayType == .confirmClose {
            vlcPlayer?.stop()
            viewModel.dismiss?() ?? dismiss()
        } else {
            withAnimation {
                currentOverlayType = .confirmClose
                isPresentingOverlay = true
            }
            
            let task = DispatchWorkItem {
                withAnimation {
                    isPresentingOverlay = false
                    overlayTimer.stop()
                }
            }
            
            confirmCloseWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
        }
    }
    
    private func handlePlayPausePress() {
        guard let player = vlcPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            withAnimation(.linear(duration: 0.3)) {
                isPresentingOverlay = true
            }
        } else {
            player.play()
            isPlaying = true
            withAnimation(.linear(duration: 0.3)) {
                isPresentingOverlay = false
            }
        }
    }
    
    private func handleArrowPress() {
        if !isPresentingOverlay {
            showOverlayTemporarily()
        }
    }
    
    private func handleLeftArrowPress() {
        if !isPresentingOverlay || !isSliderFocused {
            seekBackward()
            showOverlayTemporarily()
        }
    }
    
    private func handleRightArrowPress() {
        if !isPresentingOverlay || !isSliderFocused {
            seekForward()
            showOverlayTemporarily()
        }
    }
    
    private func seekForward(seconds: Int = 10) {
        guard let player = vlcPlayer else { return }
        let newTime = player.time.intValue + Int32(seconds * 1000)
        player.time = VLCTime(int: newTime)
    }
    
    private func seekBackward(seconds: Int = 10) {
        guard let player = vlcPlayer else { return }
        let newTime = max(0, player.time.intValue - Int32(seconds * 1000))
        player.time = VLCTime(int: newTime)
    }
    
    // MARK: - Overlay Management
    
    private func showOverlayTemporarily() {
        currentOverlayType = .main
        isPresentingOverlay = true
        overlayTimer.start(5)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Swiftfin Slider

@available(tvOS 17.0, *)
struct SwiftfinSlider: UIViewRepresentable {
    @Binding var value: Float
    @Binding var isEditing: Bool
    @Binding var isFocused: Bool
    let onEditingChanged: (Bool) -> Void
    
    func makeUIView(context: Context) -> SwiftfinTVOSSlider {
        let slider = SwiftfinTVOSSlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = value
        
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        
        return slider
    }
    
    func updateUIView(_ uiView: SwiftfinTVOSSlider, context: Context) {
        if !isEditing {
            uiView.value = value
        }
        isFocused = uiView.isFocused
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: SwiftfinSlider
        
        init(_ parent: SwiftfinSlider) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: SwiftfinTVOSSlider) {
            parent.value = sender.value
        }
    }
}

// MARK: - Custom TVOS Slider

@available(tvOS 17.0, *)
class SwiftfinTVOSSlider: UIControl {
    
    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 20
    
    var minimumValue: Float = 0
    var maximumValue: Float = 1
    
    private var _value: Float = 0
    var value: Float {
        get { _value }
        set {
            _value = max(minimumValue, min(maximumValue, newValue))
            updateThumbPosition()
        }
    }
    
    private var trackView: UIView!
    private var progressView: UIView!
    private var thumbView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 轨道背景
        trackView = UIView()
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        trackView.layer.cornerRadius = trackHeight / 2
        addSubview(trackView)
        
        // 进度条
        progressView = UIView()
        progressView.backgroundColor = .white
        progressView.layer.cornerRadius = trackHeight / 2
        addSubview(progressView)
        
        // 滑块
        thumbView = UIView()
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = thumbSize / 2
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOpacity = 0.3
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        thumbView.layer.shadowRadius = 4
        addSubview(thumbView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        trackView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 轨道
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: trackHeight),
            
            // 进度条
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressView.heightAnchor.constraint(equalToConstant: trackHeight),
            
            // 滑块
            thumbView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbView.heightAnchor.constraint(equalToConstant: thumbSize)
        ])
        
        updateThumbPosition()
    }
    
    private func updateThumbPosition() {
        guard trackView != nil else { return }
        
        layoutIfNeeded()
        
        let trackWidth = trackView.bounds.width - thumbSize
        let thumbX = CGFloat(value / (maximumValue - minimumValue)) * trackWidth + thumbSize / 2
        
        thumbView.center = CGPoint(x: thumbX, y: bounds.height / 2)
        
        let progressWidth = thumbX - thumbSize / 2
        progressView.frame = CGRect(
            x: 0,
            y: (bounds.height - trackHeight) / 2,
            width: progressWidth,
            height: trackHeight
        )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateThumbPosition()
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.0, y: 1.5)
                self.thumbView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } else {
                self.transform = CGAffineTransform.identity
                self.thumbView.transform = CGAffineTransform.identity
            }
        }, completion: nil)
    }
    
    override var canBecomeFocused: Bool {
        return true
    }
}

// MARK: - Timer Proxy

@available(tvOS 17.0, *)
class TimerProxy: ObservableObject {
    @Published private(set) var isActive: Bool = false
    private var timer: Timer?
    
    func start(_ interval: TimeInterval) {
        stop()
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.isActive = false
            self?.timer = nil
        }
    }
    
    func pause() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }
}

// MARK: - Environment Keys

@available(tvOS 17.0, *)
struct IsPresentingOverlayKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

@available(tvOS 17.0, *)
struct IsScrubbingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

@available(tvOS 17.0, *)
struct CurrentOverlayTypeKey: EnvironmentKey {
    static let defaultValue: Binding<SwiftfinStyleVideoPlayerView.OverlayType> = .constant(.main)
}

extension EnvironmentValues {
    var isPresentingOverlay: Binding<Bool> {
        get { self[IsPresentingOverlayKey.self] }
        set { self[IsPresentingOverlayKey.self] = newValue }
    }
    
    var isScrubbing: Binding<Bool> {
        get { self[IsScrubbingKey.self] }
        set { self[IsScrubbingKey.self] = newValue }
    }
    
    var currentOverlayType: Binding<SwiftfinStyleVideoPlayerView.OverlayType> {
        get { self[CurrentOverlayTypeKey.self] }
        set { self[CurrentOverlayTypeKey.self] = newValue }
    }
}

// MARK: - View Modifiers

@available(tvOS 17.0, *)
extension View {
    func isVisible(_ visible: Bool) -> some View {
        self.opacity(visible ? 1 : 0)
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    static func from(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    static func circle(size: CGFloat, color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
