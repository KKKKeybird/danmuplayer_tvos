/// 播放器控制逻辑（弹幕加载、参数调整）
import Foundation
import Combine
import AVFoundation
import VLCKitSPM
import SwiftUI

/// 管理视频播放状态、弹幕加载和番剧识别
@MainActor
@available(tvOS 17.0, *)
class VideoPlayerViewModel: ObservableObject {
    @Published var series: DanDanPlaySeries?
    @Published var candidateSeriesList: [DanDanPlaySeries] = []
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

        danDanAPI.identifySeries(for: videoURL) { result in
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
        
        danDanAPI.identifySeriesByName(fileName) { result in
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
        danDanAPI.fetchCandidateSeriesList(for: videoURL) { result in
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
                    // 使用新的弹幕解析器，支持XML和JSON格式
                    let parsedComments = DanmakuParser.parseComments(from: data)
                    
                    // 转换为DanmakuComment格式
                    self.danmakuComments = parsedComments.map { parsed in
                        DanmakuComment(
                            time: parsed.time,
                            mode: parsed.mode,
                            fontSize: 25,
                            colorValue: self.colorToInt(parsed.color),
                            timestamp: Date().timeIntervalSince1970,
                            content: parsed.content
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

    /// 用户选择番剧后更新识别结果
    func updateSeriesSelection(to series: DanDanPlaySeries) {
        isLoading = true
        danDanAPI.updateSeriesSelection(series: series) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success:
                    self.series = series
                    self.loadDanmaku()
                    self.showingSeriesSelection = false
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
