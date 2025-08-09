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
    let subtitleURLs: [URL]
    let onDismiss: () -> Void
    
    // MARK: - State管理
    @StateObject private var viewModel: VLCPlayerViewModel
    @StateObject private var overlayTimer = TimerProxy()
    
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var isOverlayVisible = true
    @State private var currentOverlayType: InformationOverlay.OverlayType = .main
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
    
    // MARK: - 初始化
    
    init(videoURL: URL, originalFileName: String, subtitleURLs: [URL] = [], onDismiss: @escaping () -> Void) {
        self.videoURL = videoURL
        self.originalFileName = originalFileName
        self.subtitleURLs = subtitleURLs
        self.onDismiss = onDismiss
        
        self._viewModel = StateObject(wrappedValue: VLCPlayerViewModel(
            videoURL: videoURL,
            originalFileName: originalFileName
        ))
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
            
            // 信息覆盖层，默认隐藏，用户操作时滑入，超时或恢复播放后滑出
            if isOverlayVisible, let player = vlcPlayer {
                InformationOverlay(
                    player: player,
                    controlDelegate: PlayerControlDelegate(
                        onDismiss: onDismiss,
                        onShowAudioTracks: { showingAudioTrackOverlay = true },
                        onShowSubtitles: { showingSubtitleOverlay = true },
                        onToggleDanmaku: handleToggleDanmaku,
                        onShowDanmakuMatch: { showingDanmakuMatchOverlay = true },
                        onShowDanmakuSettings: { showingDanmakuSettingsOverlay = true }
                    )
                )
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: isOverlayVisible)
            }
            
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
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = true
            }
            resetOverlayTimer()
        }
        .onPlayPauseCommand(perform: handlePlayPause)
        .onExitCommand(perform: onDismiss)
        
        // 浮窗展示
        .smallMenuOverlay(isPresented: $showingAudioTrackOverlay, title: "音轨选择") {
            SoundTrackPopover(
                isPresented: $showingAudioTrackOverlay,
                vlcPlayer: vlcPlayer
            )
        }
        .smallMenuOverlay(isPresented: $showingSubtitleOverlay, title: "字幕选择") {
            SubTrackPopover(
                isPresented: $showingSubtitleOverlay,
                vlcPlayer: vlcPlayer,
                externalSubtitles: getExternalSubtitles()
            )
        }
        .smallMenuOverlay(isPresented: $showingDanmakuMatchOverlay, title: "弹幕匹配") {
            DanmaSelectPopover(
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
        .smallMenuOverlay(isPresented: $showingDanmakuSettingsOverlay, title: "弹幕设置") {
            DanmaSettingPopover(settings: $danmakuSettings)
        }
    }
    
    // MARK: - 私有方法
    
    private func setupPlayer() {
        viewModel.setupPlayer { player in
            self.vlcPlayer = player
            
            // 加载所有外部字幕
            for url in subtitleURLs {
                loadExternalSubtitle(url: url)
            }
            
            // 启动覆盖层计时器
            resetOverlayTimer()
        }
    }
    
    private func setupPlayerCallbacks(_ player: VLCMediaPlayer) {
        // 设置播放器回调和状态监听
        vlcPlayer = player
        
        // 加载所有外部字幕
        for url in subtitleURLs {
            loadExternalSubtitle(url: url)
        }
        
        // 启动覆盖层计时器
        resetOverlayTimer()
    }
    
    private func cleanup() {
        vlcPlayer?.stop()
        overlayTimer.stop()
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
                    // 直接使用ASS内容，不再重新解析生成弹幕评论
                    if let danmakuData = assContent.data(using: .utf8) {
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
            // 暂停时显示覆盖层
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = true
            }
            resetOverlayTimer()
        } else {
            player.play()
            // 播放时隐藏覆盖层
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = false
            }
        }
        isPlaying = player.isPlaying
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
        for url in subtitleURLs {
            let fileName = url.lastPathComponent
            let language = extractLanguageFromFileName(fileName)
            subtitles.append(SubtitleFileInfo(
                name: fileName,
                url: url,
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
        overlayTimer.stop()
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
                let time = player.time
                currentTime = Double(time.intValue) / 1000.0
                
                if let media = player.media {
                    let mediaLength = media.length
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

// MARK: - 播放器控制委托

@available(tvOS 17.0, *)
class PlayerControlDelegate: VLCPlayerControlDelegate {
    private let onDismiss: () -> Void
    private let onShowAudioTracks: () -> Void
    private let onShowSubtitles: () -> Void
    private let onToggleDanmaku: () -> Void
    private let onShowDanmakuMatch: () -> Void
    private let onShowDanmakuSettings: () -> Void
    
    init(
        onDismiss: @escaping () -> Void,
        onShowAudioTracks: @escaping () -> Void,
        onShowSubtitles: @escaping () -> Void,
        onToggleDanmaku: @escaping () -> Void,
        onShowDanmakuMatch: @escaping () -> Void,
        onShowDanmakuSettings: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        self.onShowAudioTracks = onShowAudioTracks
        self.onShowSubtitles = onShowSubtitles
        self.onToggleDanmaku = onToggleDanmaku
        self.onShowDanmakuMatch = onShowDanmakuMatch
        self.onShowDanmakuSettings = onShowDanmakuSettings
    }
    
    func playerDidRequestAudioTrackSelection() {
        onShowAudioTracks()
    }
    
    func playerDidRequestSubtitleSelection() {
        onShowSubtitles()
    }
    
    func playerDidRequestDanmakuToggle() {
        onToggleDanmaku()
    }
    
    func playerDidRequestDanmakuMatch() {
        onShowDanmakuMatch()
    }
    
    func playerDidRequestDanmakuSettings() {
        onShowDanmakuSettings()
    }
    
    func playerDidRequestDismiss() {
        onDismiss()
    }
}
