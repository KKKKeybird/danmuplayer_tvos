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
    @State private var pendingDanmakuData: Data?
    @StateObject private var danmakuLogger = DanmakuDebugLogger.shared
    @State private var showDanmakuDebug = false
    @State private var didLoadExternalSubtitles = false
    @State private var hasStartedPlayback = false
    @FocusState private var isMainFocused: Bool
    // 自绘弹幕
    @State private var overlayDanmaku: [DanmakuComment] = []
    // 信息层焦点目标
    private enum OverlayFocusTarget { case top, bottom }
    @State private var overlayFocusTarget: OverlayFocusTarget = .bottom
    
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
            // 播放器图层
            playerSurface

            // 自绘弹幕层（独立于 VLC 字幕轨）
            DanmakuCanvas(
                comments: overlayDanmaku,
                currentTime: $currentTime,
                isPlaying: $isPlaying,
                settings: $danmakuSettings
            )
            .allowsHitTesting(false)
            
            // 信息覆盖层，默认隐藏，用户操作时滑入，超时或恢复播放后滑出
            if isOverlayVisible, let player = vlcPlayer {
                topOverlayView(for: player, shouldRequestFocus: overlayFocusTarget == .top)
                bottomOverlayView(for: player, shouldRequestFocus: overlayFocusTarget == .bottom)
            }
            
            // 加载状态
            loadingOverlay
            
            // 弹幕调试浮层
            // 调试浮层
            debugOverlay
        }
        .background(Color.black)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .focusable(true)
        .focused($isMainFocused)
        .onTapGesture {
            if isOverlayVisible {
                withAnimation(.easeInOut(duration: 0.25)) { isOverlayVisible = false }
            } else {
                overlayFocusTarget = .bottom
                showOverlayForInteraction()
            }
        }
        .onPlayPauseCommand(perform: handlePlayPause)
        .onMoveCommand { dir in
            switch dir {
            case .left:
                vlcPlayer?.rewind(15)
                overlayFocusTarget = .bottom
                showOverlayForInteraction()
            case .right:
                vlcPlayer?.fastForward(15)
                overlayFocusTarget = .bottom
                showOverlayForInteraction()
            case .up:
                overlayFocusTarget = .top
                showOverlayForInteraction()
            case .down:
                overlayFocusTarget = .bottom
                showOverlayForInteraction()
            default:
                showOverlayForInteraction()
            }
        }
        .onExitCommand(perform: {
            cleanup()
            onDismiss()
        })
        .onLongPressGesture(minimumDuration: 0.8) {
            withAnimation { showDanmakuDebug.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DanmakuDebugToggle"))) { _ in
            withAnimation { showDanmakuDebug.toggle() }
        }
        .onAppear { isMainFocused = true }
        
        // 浮窗展示
        .smallMenuOverlay(isPresented: $showingAudioTrackOverlay, title: "音轨选择") {
            SoundTrackPopover(
                isPresented: $showingAudioTrackOverlay,
                vlcPlayer: vlcPlayer
            )
        }
        // 当任何小弹窗显示/隐藏或播放状态变化时，主动显示覆盖层并重置计时器
        .onChange(of: showingAudioTrackOverlay) { _ in showOverlayForInteraction() }
        .onChange(of: showingSubtitleOverlay) { _ in showOverlayForInteraction() }
        .onChange(of: showingDanmakuMatchOverlay) { _ in showOverlayForInteraction() }
        .onChange(of: showingDanmakuSettingsOverlay) { _ in showOverlayForInteraction() }
        .onChange(of: isPlaying) { _ in showOverlayForInteraction() }
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
    
    // 拆分顶部/底部 overlay 以降低类型推断复杂度
    @ViewBuilder
    private func topOverlayView(for player: VLCMediaPlayer, shouldRequestFocus: Bool = false) -> some View {
        TopInformationOverlay(
            player: player,
            controlDelegate: PlayerControlDelegate(
                onDismiss: { 
                    cleanup()
                    onDismiss()
                },
                onShowAudioTracks: { showingAudioTrackOverlay = true },
                onShowSubtitles: { showingSubtitleOverlay = true },
                onToggleDanmaku: handleToggleDanmaku,
                onShowDanmakuMatch: { showingDanmakuMatchOverlay = true },
                onShowDanmakuSettings: { showingDanmakuSettingsOverlay = true }
            ),
            shouldRequestFocus: shouldRequestFocus,
            onRequestHide: { isMainFocused = true }
        )
        .transition(.move(edge: .top))
        .animation(.easeInOut(duration: 0.25), value: isOverlayVisible)
    }

    @ViewBuilder
    private func bottomOverlayView(for player: VLCMediaPlayer, shouldRequestFocus: Bool = false) -> some View {
        BottomInformationOverlay(
            player: player,
            controlDelegate: PlayerControlDelegate(
                onDismiss: { 
                    cleanup()
                    onDismiss()
                },
                onShowAudioTracks: { showingAudioTrackOverlay = true },
                onShowSubtitles: { showingSubtitleOverlay = true },
                onToggleDanmaku: handleToggleDanmaku,
                onShowDanmakuMatch: { showingDanmakuMatchOverlay = true },
                onShowDanmakuSettings: { showingDanmakuSettingsOverlay = true }
            ),
            shouldRequestFocus: shouldRequestFocus,
            onRequestHide: { isMainFocused = true }
        )
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.25), value: isOverlayVisible)
    }
    
    // MARK: - 私有方法
    
    private func setupPlayer() { }
    
    private func setupPlayerCallbacks(_ player: VLCMediaPlayer) {
        // 设置播放器回调和状态监听（推迟到下一次主线程循环，避免在视图更新阶段修改状态）
        DispatchQueue.main.async {
            vlcPlayer = player
            
            // 加载所有外部字幕（仅一次）
            if !didLoadExternalSubtitles {
                for url in subtitleURLs {
                    loadExternalSubtitle(url: url)
                }
                didLoadExternalSubtitles = true
            }
            
            // 如果有待加载的弹幕数据，播放器就绪后加载
            if let data = pendingDanmakuData, isDanmakuEnabled {
                player.loadDanmakuAsSubtitle(data, format: .ass)
                pendingDanmakuData = nil
            }

            // 启动覆盖层计时器
            resetOverlayTimer()
        }
    }
    
    private func cleanup() {
        if let player = vlcPlayer {
            player.stop()
            player.drawable = nil
            player.media = nil
        }
        vlcPlayer = nil
        overlayTimer.stop()
    }
    
    private func identifyAndLoadDanmaku() {
        viewModel.isLoading = true
        
        // 使用DanDanPlayAPI识别剧集
        // 对于远程流（如 Jellyfin/WebDAV）可能没有有效文件名，使用 originalFileName 作为回退
        DanDanPlayAPI().identifyEpisode(for: videoURL, overrideFileName: originalFileName) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let episode):
                    danmakuLogger.add("弹幕识别成功: \(episode.animeTitle) - \(episode.episodeTitle) (id=\(episode.episodeId))")
                    selectedEpisode = episode
                    loadDanmakuForEpisode(episode)
                    startPlaybackIfNeeded()
                    
                case .failure(let error):
                    danmakuLogger.add("弹幕识别失败: \(error.localizedDescription)")
                    // 获取候选列表供用户手动选择
                    loadCandidateEpisodes()
                    // 识别失败也启动播放，不阻塞观看
                    startPlaybackIfNeeded()
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
                    danmakuLogger.add("获取候选剧集成功: 共 \(episodes.count) 个")
                case .failure(let error):
                    danmakuLogger.add("获取候选剧集失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadDanmakuForEpisode(_ episode: DanDanPlayEpisode) {
        DanDanPlayAPI().loadDanmakuComments(for: episode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let comments):
                    danmakuLogger.add("弹幕加载成功：\(comments.count) 条（自绘模式）")
                    overlayDanmaku = comments
                    
                case .failure(let error):
                    danmakuLogger.add("加载弹幕失败: \(error.localizedDescription)")
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
            DispatchQueue.main.async { player.pause() }
            // 暂停时显示覆盖层
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = true
            }
            resetOverlayTimer()
        } else {
            DispatchQueue.main.async { player.play() }
            // 播放时隐藏覆盖层
            withAnimation(.easeInOut(duration: 0.3)) {
                isOverlayVisible = false
            }
        }
        isPlaying = player.isPlaying
    }

    private func startPlaybackIfNeeded() {
        guard !hasStartedPlayback, let player = vlcPlayer else { return }
        DispatchQueue.main.async { player.play() }
        hasStartedPlayback = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isOverlayVisible = false
        }
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

    private func showOverlayForInteraction() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isOverlayVisible = true
        }
        resetOverlayTimer()
    }
}

// MARK: - 子视图分解以降低类型推断复杂度
extension VLCPlayerView {
    @ViewBuilder
    var playerSurface: some View {
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
            identifyAndLoadDanmaku()
            danmakuLogger.clear()
            danmakuLogger.add("播放器出现，开始识别弹幕：\(videoURL.lastPathComponent)")
        }
        .onDisappear {
            cleanup()
        }
    }

    @ViewBuilder
    var loadingOverlay: some View {
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

    @ViewBuilder
    var debugOverlay: some View {
        if showDanmakuDebug {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("弹幕调试")
                        .font(.headline)
                    Spacer()
                    Button("关闭") { showDanmakuDebug = false }
                }
                .foregroundColor(.white)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(danmakuLogger.logs.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let player = vlcPlayer {
                    Button("打印字幕轨信息") {
                        player.printSubtitleTracksInfo()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            .frame(maxWidth: 900)
            .position(x: UIScreen.main.bounds.width * 0.5, y: 220)
            .transition(.opacity)
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
            // 播放器就绪回调（延迟到下一次主线程循环，避免在视图更新阶段修改状态）
            DispatchQueue.main.async {
                vlcPlayer = player
                onPlayerReady(player)
                
                // 设置播放状态更新
                setupPlayerStateUpdates(player)
            }
        }
        // 使用 fill 让视频等比铺满，避免两侧出现非黑边
        .aspectRatio(16/9, contentMode: .fill)
        .background(Color.black)
        .clipped()
    }
    
    private func setupPlayerStateUpdates(_ player: VLCMediaPlayer) {
        // 使用VLCUI提供的状态绑定机制
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let player = vlcPlayer else { return }
            
            // 避免在视图更新阶段同步写入 @State，统一放到下一次主线程循环
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
        // 优化视频解码与缓存
        media.addOptions([
            "network-caching": 1000,              // 网络缓存(ms)
            "clock-jitter": 0,
            "clock-synchro": 0,
            "codec": "mediacodec_ndk,all",     // 尝试硬件解码（Android风格，VLCKit会忽略不支持项）
            "avcodec-hw": "any",                // 允许硬件加速
        ])
        player.media = media
        player.drawable = self
        
        vlcPlayer = player
        onReady(player)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 让视频按容器填充，保持比例（letterbox/pillarbox 由上层 .fill + .clipped 控制）
        vlcPlayer?.videoAspectRatio = nil
        vlcPlayer?.scaleFactor = 0 // 让 VLC 自适应
    }
}

// MARK: - 弹幕设置

struct DanmakuSettings {
    var isEnabled = true
    var opacity: Double = 0.8
    var maxLines: Int = 18
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
