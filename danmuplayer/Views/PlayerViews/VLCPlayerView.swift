/// VLC播放器界面 - 主播放器视图
import SwiftUI
import VLCKitSPM
import VLCUI

/// 播放器界面，接受视频原始文件名，视频Url和字幕Url，根据视频Url解析文件信息，进入后使用DanDanPlayAPI寻找字幕，加入到字幕轨中同时加载弹幕和字幕
@available(tvOS 17.0, *)
struct VLCPlayerView: View {
    // MARK: - 输入参数
    let videoURL: URL
    let originalFileName: String
    let subtitleURL: URL?
    let onDismiss: () -> Void
    
    // MARK: - State管理
    @StateObject private var viewModel: VLCPlayerViewModel
    @StateObject private var danmakuManager: DanmakuManager
    @StateObject private var overlayTimer = TimerProxy()
    
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var isOverlayVisible = true
    @State private var currentOverlayType: OverlayType = .information
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isScrubbing = false
    
    // 浮窗状态
    @State private var showingAudioTrackOverlay = false
    @State private var showingSubtitleOverlay = false
    @State private var showingDanmakuMatchOverlay = false
    @State private var showingDanmakuSettingsOverlay = false
    
    // 弹幕相关
    @State private var isDanmakuEnabled = true
    @State private var danmakuComments: [DanmakuComment] = []
    @State private var candidateEpisodes: [DanDanPlayEpisode] = []
    @State private var selectedEpisode: DanDanPlayEpisode?
    @State private var danmakuSettings = DanmakuSettings()
    
    enum OverlayType {
        case information
        case audioTrack
        case subtitle
        case danmakuMatch
        case danmakuSettings
    }
    
    // MARK: - 初始化
    
    init(videoURL: URL, originalFileName: String, subtitleURL: URL? = nil, onDismiss: @escaping () -> Void) {
        self.videoURL = videoURL
        self.originalFileName = originalFileName
        self.subtitleURL = subtitleURL
        self.onDismiss = onDismiss
        
        self._viewModel = StateObject(wrappedValue: VLCPlayerViewModel(
            videoURL: videoURL,
            originalFileName: originalFileName
        ))
        self._danmakuManager = StateObject(wrappedValue: DanmakuManager())
    }
    
    // MARK: - 主视图
    
    var body: some View {
        ZStack {
            // VLCUI播放器视图
            VLCUIVideoPlayerView(
                vlcPlayer: $vlcPlayer,
                currentTime: $currentTime,
                duration: $duration,
                isPlaying: $isPlaying,
                videoURL: videoURL,
                onPlayerReady: { player in
                    setupPlayerCallbacks(player)
                }
            )
            .onAppear {
                setupPlayer()
                identifyAndLoadDanmaku()
            }
            .onDisappear {
                cleanup()
            }
            
            // 弹幕覆盖层
            if isDanmakuEnabled && !danmakuComments.isEmpty {
                DanmakuOverlayLayer(
                    comments: danmakuComments,
                    currentTime: currentTime,
                    settings: danmakuSettings
                )
            }
            
            // 信息覆盖层
            InformationOverlay(
                isVisible: $isOverlayVisible,
                currentTime: $currentTime,
                duration: $duration,
                isPlaying: $isPlaying,
                currentOverlayType: $currentOverlayType,
                vlcPlayer: vlcPlayer,
                onSeek: handleSeek,
                onPlayPause: handlePlayPause,
                onShowAudioTracks: { showingAudioTrackOverlay = true },
                onShowSubtitles: { showingSubtitleOverlay = true },
                onToggleDanmaku: handleToggleDanmaku,
                onShowDanmakuMatch: { showingDanmakuMatchOverlay = true },
                onShowDanmakuSettings: { showingDanmakuSettingsOverlay = true },
                onDismiss: onDismiss
            )
            
            // 加载状态
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在加载...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
            }
        }
        .background(Color.black)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible.toggle()
            }
            if isOverlayVisible {
                resetOverlayTimer()
            }
        }
        .onPlayPauseCommand(perform: handlePlayPause)
        .onExitCommand(perform: onDismiss)
        
        // 浮窗展示
        .sheet(isPresented: $showingAudioTrackOverlay) {
            SoundTrackOverlay(
                isPresented: $showingAudioTrackOverlay,
                vlcPlayer: vlcPlayer
            )
        }
        .sheet(isPresented: $showingSubtitleOverlay) {
            SubTrackOverlay(
                isPresented: $showingSubtitleOverlay,
                vlcPlayer: vlcPlayer,
                externalSubtitles: getExternalSubtitles()
            )
        }
        .sheet(isPresented: $showingDanmakuMatchOverlay) {
            DanmaSelecOverlay(
                candidateEpisodes: candidateEpisodes,
                videoURL: videoURL,
                onEpisodeSelected: { episode in
                    selectedEpisode = episode
                    showingDanmakuMatchOverlay = false
                },
                onReloadDanmaku: { episode in
                    loadDanmakuForEpisode(episode)
                }
            )
        }
        .sheet(isPresented: $showingDanmakuSettingsOverlay) {
            DanmaSettingOverlay(settings: $danmakuSettings)
        }
    }
    
    // MARK: - 私有方法
    
    private func setupPlayer() {
        viewModel.setupPlayer { player in
            self.vlcPlayer = player
            
            // 加载外部字幕
            if let subtitleURL = subtitleURL {
                loadExternalSubtitle(url: subtitleURL)
            }
            
            // 启动覆盖层计时器
            resetOverlayTimer()
        }
    }
    
    private func setupPlayerCallbacks(_ player: VLCMediaPlayer) {
        // 设置播放器回调和状态监听
        vlcPlayer = player
        
        // 加载外部字幕
        if let subtitleURL = subtitleURL {
            loadExternalSubtitle(url: subtitleURL)
        }
        
        // 启动覆盖层计时器
        resetOverlayTimer()
    }
    
    private func cleanup() {
        vlcPlayer?.stop()
        overlayTimer.stop()
        danmakuManager.clearCache()
    }
    
    private func identifyAndLoadDanmaku() {
        viewModel.isLoading = true
        
        // 使用DanDanPlayAPI识别剧集
        DanDanPlayAPI().identifyEpisode(for: videoURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let episode):
                    selectedEpisode = episode
                    loadDanmakuForEpisode(episode)
                    
                case .failure(let error):
                    print("剧集识别失败: \(error)")
                    // 获取候选列表供用户手动选择
                    loadCandidateEpisodes()
                }
                viewModel.isLoading = false
            }
        }
    }
    
    private func loadCandidateEpisodes() {
        DanDanPlayAPI().fetchCandidateEpisodeList(for: videoURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let episodes):
                    candidateEpisodes = episodes
                case .failure(let error):
                    print("获取候选剧集失败: \(error)")
                }
            }
        }
    }
    
    private func loadDanmakuForEpisode(_ episode: DanDanPlayEpisode) {
        DanDanPlayAPI().loadDanmakuAsASS(for: episode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let assContent):
                    // 解析弹幕数据
                    if let danmakuData = assContent.data(using: .utf8) {
                        danmakuComments = DanmakuParser.parseComments(from: danmakuData)
                        
                        // 将弹幕添加到VLC字幕轨
                        if let player = vlcPlayer {
                            player.loadDanmakuAsSubtitle(danmakuData, format: .ass)
                        }
                    }
                    
                case .failure(let error):
                    print("加载弹幕失败: \(error)")
                }
            }
        }
    }
    
    private func loadExternalSubtitle(url: URL) {
        guard let player = vlcPlayer else { return }
        
        if player.addPlaybackSlave(url, type: .subtitle, enforce: false) == 0 {
            print("成功加载外部字幕: \(url)")
        } else {
            print("加载外部字幕失败: \(url)")
        }
    }
    
    private func handleSeek(_ time: Double) {
        vlcPlayer?.time = VLCTime(number: NSNumber(value: time * 1000)) // VLC使用毫秒
    }
    
    private func handlePlayPause() {
        guard let player = vlcPlayer else { return }
        
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        isPlaying = player.isPlaying
        resetOverlayTimer()
    }
    
    private func handleToggleDanmaku() {
        isDanmakuEnabled.toggle()
        
        guard let player = vlcPlayer else { return }
        
        if isDanmakuEnabled {
            // 重新加载弹幕
            if let episode = selectedEpisode {
                loadDanmakuForEpisode(episode)
            }
        } else {
            // 移除弹幕字幕轨
            player.removeDanmakuSubtitle()
        }
    }
    
    private func getExternalSubtitles() -> [SubtitleFileInfo] {
        var subtitles: [SubtitleFileInfo] = []
        
        if let subtitleURL = subtitleURL {
            let fileName = subtitleURL.lastPathComponent
            let language = extractLanguageFromFileName(fileName)
            
            subtitles.append(SubtitleFileInfo(
                name: fileName,
                url: subtitleURL,
                language: language
            ))
        }
        
        return subtitles
    }
    
    private func extractLanguageFromFileName(_ fileName: String) -> String? {
        let lowercased = fileName.lowercased()
        
        if lowercased.contains("zh") || lowercased.contains("chinese") || lowercased.contains("中文") {
            return "中文"
        } else if lowercased.contains("en") || lowercased.contains("english") || lowercased.contains("英文") {
            return "English"
        } else if lowercased.contains("ja") || lowercased.contains("japanese") || lowercased.contains("日文") {
            return "日本語"
        }
        
        return nil
    }
    
    private func resetOverlayTimer() {
        overlayTimer.start(interval: 5.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = false
            }
        }
    }
}

// MARK: - ViewModel

class VLCPlayerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let videoURL: URL
    private let originalFileName: String
    private var vlcPlayer: VLCMediaPlayer?
    
    init(videoURL: URL, originalFileName: String) {
        self.videoURL = videoURL
        self.originalFileName = originalFileName
    }
    
    func setupPlayer(completion: @escaping (VLCMediaPlayer) -> Void) {
        isLoading = true
        
        DispatchQueue.main.async {
            let player = VLCMediaPlayer()
            let media = VLCMedia(url: self.videoURL)
            player.media = media
            
            self.vlcPlayer = player
            completion(player)
            
            self.isLoading = false
        }
    }
}

// MARK: - VLCUI播放器SwiftUI包装

struct VLCUIVideoPlayerView: View {
    @Binding var vlcPlayer: VLCMediaPlayer?
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isPlaying: Bool
    let videoURL: URL
    let onPlayerReady: (VLCMediaPlayer) -> Void
    
    var body: some View {
        VLCVideoPlayerView(url: videoURL) { player in
            // 播放器就绪回调
            vlcPlayer = player
            onPlayerReady(player)
            
            // 设置播放状态更新
            setupPlayerStateUpdates(player)
        }
        .aspectRatio(16/9, contentMode: .fit)
        .background(Color.black)
    }
    
    private func setupPlayerStateUpdates(_ player: VLCMediaPlayer) {
        // 使用VLCUI提供的状态绑定机制
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let player = vlcPlayer else { return }
            
            DispatchQueue.main.async {
                if let time = player.time {
                    currentTime = Double(time.intValue) / 1000.0
                }
                
                if let media = player.media, let mediaLength = media.length {
                    duration = Double(mediaLength.intValue) / 1000.0
                }
                
                isPlaying = player.isPlaying
            }
        }
    }
}

// MARK: - VLCUI视频播放器视图

struct VLCVideoPlayerView: UIViewRepresentable {
    let url: URL
    let onPlayerReady: (VLCMediaPlayer) -> Void
    
    func makeUIView(context: Context) -> VLCVideoPlayerUIView {
        let playerView = VLCVideoPlayerUIView()
        playerView.setup(with: url, onReady: onPlayerReady)
        return playerView
    }
    
    func updateUIView(_ uiView: VLCVideoPlayerUIView, context: Context) {
        // 更新UI视图
    }
}

// MARK: - VLCUI视频播放器UI视图

class VLCVideoPlayerUIView: UIView {
    private var vlcPlayer: VLCMediaPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }
    
    func setup(with url: URL, onReady: @escaping (VLCMediaPlayer) -> Void) {
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        player.media = media
        player.drawable = self
        
        vlcPlayer = player
        onReady(player)
        
        // 开始播放
        player.play()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        vlcPlayer?.videoAspectRatio = nil // 自适应比例
    }
}

// MARK: - 弹幕管理器

class DanmakuManager: ObservableObject {
    @Published var comments: [DanmakuComment] = []
    
    func loadComments(from data: Data) {
        comments = DanmakuParser.parseComments(from: data)
    }
    
    func clearCache() {
        comments.removeAll()
    }
}

// MARK: - 弹幕设置

struct DanmakuSettings {
    var isEnabled = true
    var opacity: Double = 0.8
    var fontSize: Double = 18
    var speed: Double = 1.0
    var maxCount = 50
    var density: Double = 0.8
    var showScrolling = true
    var showTop = true
    var showBottom = true
}

// MARK: - 计时器代理

class TimerProxy: ObservableObject {
    private var timer: Timer?
    
    func start(interval: TimeInterval, action: @escaping () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
