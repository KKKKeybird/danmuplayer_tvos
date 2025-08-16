/// MPV播放器视图 - 使用 MPVKit 实现视频播放
import SwiftUI
import MPVKit

@available(tvOS 17.0, *)
struct MPVPlayerView: UIViewRepresentable {
    let videoURL: URL
    let originalFileName: String
    let subtitleURLs: [URL]
    let onDismiss: () -> Void
    
    func makeUIView(context: Context) -> MPVView {
        let mpvView = MPVView()
        mpvView.player.load(url: videoURL)
        // 加载字幕
        for subURL in subtitleURLs {
            mpvView.player.addSubtitle(url: subURL)
        }
        // 监听播放结束
        mpvView.player.onPlaybackEnded = {
            onDismiss()
        }
        return mpvView
    }
    
    func updateUIView(_ uiView: MPVView, context: Context) {
        // 可根据需要更新播放器状态
    }
}

// MARK: - MPVKit 扩展（假设 API，需根据实际 MPVKit 文档调整）
extension MPVView {
    var player: MPVPlayer {
        // MPVKit_GPL: MPVView 已有 player 属性
        return self.player
    }
}

extension MPVPlayer {
    func load(url: URL) {
        self.open(url)
    }
    var onPlaybackEnded: (() -> Void)? {
        get {
            return self.onPlaybackEndedHandler
        }
        set {
            self.onPlaybackEndedHandler = newValue
        }
    }
    private static var _shared: MPVPlayer?
    static var shared: MPVPlayer {
        if let instance = _shared { return instance }
        /// MPVKit播放器界面 - 主播放器视图
        import SwiftUI
        import MPVKit_GPL
        import Combine

        @available(tvOS 17.0, *)
        struct MPVPlayerView: View {
            // MARK: - 输入参数
            let videoURL: URL
            let originalFileName: String
            let subtitleURLs: [URL]
            let onDismiss: () -> Void

            // MARK: - State管理
            @StateObject private var overlayTimer = TimerProxy()
            @StateObject private var displayLink = DisplayLinkDriver()
            @StateObject private var settingsStore = PlayerSettingsStore.shared

            @State private var mpvPlayer: MPVPlayer?
            @State private var currentTime: Double = 0
            @State private var duration: Double = 0
            @State private var isPlaying = false
            @State private var isScrubbing = false
            @State private var showingSettings = false

            // 弹幕相关
            @State private var isDanmakuEnabled = true
            @State private var overlayDanmaku: [DanmakuComment] = []
            @State private var candidateEpisodes: [DanDanPlayEpisode] = []
            @State private var selectedEpisode: DanDanPlayEpisode?
            @State private var cancellables: Set<AnyCancellable> = []
            @State private var pendingDanmakuData: Data?
            @StateObject private var danmakuLogger = DanmakuDebugLogger.shared
            @State private var showDanmakuDebug = false
            @State private var didLoadExternalSubtitles = false
            @State private var hasStartedPlayback = false
            @FocusState private var isMainFocused: Bool

            // MARK: - 初始化
            init(videoURL: URL, originalFileName: String, subtitleURLs: [URL] = [], onDismiss: @escaping () -> Void) {
                self.videoURL = videoURL
                self.originalFileName = originalFileName
                self.subtitleURLs = subtitleURLs
                self.onDismiss = onDismiss
            }

            // MARK: - 主视图
            var body: some View {
                ZStack {
                    // 播放器图层
                    playerSurface

                    // 弹幕层
                    DanmakuLayerView(
                        comments: overlayDanmaku,
                        currentTime: $currentTime,
                        isPlaying: $isPlaying,
                        settings: Binding(
                            get: { settingsStore.danmakuSettings },
                            set: { settingsStore.danmakuSettings = $0 }
                        )
                    )
                    .allowsHitTesting(false)

                    // 进度条
                    if let player = mpvPlayer {
                        VStack {
                            Spacer()
                            MPVProgressBar(player: player)
                                .padding(.horizontal, 50)
                                .padding(.bottom, 50)
                        }
                    }

                    // 加载状态
                    loadingOverlay

                    // 弹幕调试浮层
                    debugOverlay
                }
                .background(Color.black)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .focusable(true)
                .focused($isMainFocused)
                .onTapGesture { handlePlayPause() }
                .onPlayPauseCommand(perform: handlePlayPause)
                .onExitCommand { onDismiss() }
                .onMoveCommand { dir in
                    guard let player = mpvPlayer else { return }
                    let currentSec: Double = currentTime
                    let mediaLengthSec: Double = duration
                    let stepSec: Double = 15.0
                    switch dir {
                    case .left:
                        let target: Double = max(0, currentSec - stepSec)
                        player.seek(to: target)
                    case .right:
                        let target: Double = min(mediaLengthSec, currentSec + stepSec)
                        player.seek(to: target)
                    case .up:
                        showingSettings = true
                    default:
                        break
                    }
                }
                .onLongPressGesture(minimumDuration: 0.8) { showingSettings = true }
                .onExitCommand(perform: {
                    cleanup()
                    onDismiss()
                })
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DanmakuDebugToggle"))) { _ in
                    withAnimation { showDanmakuDebug.toggle() }
                }
                .onAppear { isMainFocused = true }
                .fullScreenCover(isPresented: $showingSettings, onDismiss: { isMainFocused = true }) {
                    VideoPlayerSettingsView(
                        isPresented: $showingSettings,
                        mpvPlayer: mpvPlayer,
                        externalSubtitles: getExternalSubtitles(),
                        onDismiss: { },
                        videoURL: videoURL,
                        originalFileName: originalFileName,
                        onSelectEpisode: { episode in
                            selectedEpisode = episode
                            loadDanmakuForEpisode(episode)
                        },
                        isDanmakuEnabled: $settingsStore.isDanmakuEnabled,
                        danmakuSettings: $settingsStore.danmakuSettings
                    )
                    .ignoresSafeArea()
                }
            }

            // MARK: - 私有方法
            private func setupPlayer() { }

            private func setupPlayerCallbacks(_ player: MPVPlayer) {
                mpvPlayer = player
                if !didLoadExternalSubtitles {
                    for url in subtitleURLs {
                        player.addExternalSubtitle(url: url)
                    }
                    didLoadExternalSubtitles = true
                }
                if pendingDanmakuData != nil && isDanmakuEnabled {
                    pendingDanmakuData = nil
                }
            }

            private func cleanup() {
                mpvPlayer?.stop()
                mpvPlayer = nil
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
                // ...existing code...
            }

            private func loadDanmakuForEpisode(_ episode: DanDanPlayEpisode) {
                // ...existing code...
            }

            private func handleSeek(_ time: Double) {
                mpvPlayer?.seek(to: time)
            }

            private func handlePlayPause() {
                guard let player = mpvPlayer else { return }
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isPlaying = player.isPlaying
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
                if lowercased.contains("zh") || lowercased.contains("chi") || lowercased.contains("chinese") || lowercased.contains("中文") {
                    return "中文"
                } else if lowercased.contains("en") || lowercased.contains("english") || lowercased.contains("英文") {
                    return "English"
                } else if lowercased.contains("ja") || lowercased.contains("japanese") || lowercased.contains("日文") {
                    return "日本語"
                }
                return nil
            }

            private func setupPlayerStateUpdates(_ player: MPVPlayer) {
                displayLink.onFrame = {
                    guard let player = mpvPlayer else { return }
                    currentTime = player.currentTime
                    duration = player.duration
                    isPlaying = player.isPlaying
                }
                displayLink.start()
            }
        }

        // MARK: - 子视图分解以降低类型推断复杂度
        extension MPVPlayerView {
            @ViewBuilder
            var playerSurface: some View {
                MPVKitVideoPlayerView(
                    mpvPlayer: $mpvPlayer,
                    currentTime: $currentTime,
                    duration: $duration,
                    isPlaying: $isPlaying,
                    videoURL: videoURL,
                    onPlayerReady: { player in
                        setupPlayerCallbacks(player)
                        setupPlayerStateUpdates(player)
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

        // MARK: - MPVKit进度条组件
        @available(tvOS 17.0, *)
        struct MPVProgressBar: View {
            let player: MPVPlayer
            @State private var progress: Float = 0.0
            @State private var isVisible = false
            var body: some View {
                VStack(spacing: 8) {
                    HStack {
                        Text(formatTime(player.currentTime))
                            .foregroundColor(.white)
                            .font(.caption)
                        Spacer()
                        Text(formatTime(player.duration))
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .position(x: geometry.size.width * CGFloat(progress), y: 2)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .opacity(isVisible ? 1 : 0)
                .onAppear {
                    startProgressUpdates()
                    showProgressBar()
                }
                .onDisappear {
                    hideProgressBar()
                }
            }
            private func startProgressUpdates() {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    let currentTime = player.currentTime
                    let totalTime = player.duration
                    progress = totalTime > 0 ? Float(currentTime / totalTime) : 0.0
                }
            }
            private func showProgressBar() {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    hideProgressBar()
                }
            }
            private func hideProgressBar() {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
            private func formatTime(_ time: Double) -> String {
                let hours = Int(time) / 3600
                let minutes = (Int(time) % 3600) / 60
                let seconds = Int(time) % 60
                if hours > 0 {
                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    return String(format: "%d:%02d", minutes, seconds)
                }
            }
        }

        // MARK: - MPVKit播放器SwiftUI包装
        struct MPVKitVideoPlayerView: View {
            @Binding var mpvPlayer: MPVPlayer?
            @Binding var currentTime: Double
            @Binding var duration: Double
            @Binding var isPlaying: Bool
            let videoURL: URL
            let onPlayerReady: (MPVPlayer) -> Void
            var body: some View {
                MPVUIKitPlayerRepresentable(
                    videoURL: videoURL,
                    onPlayerReady: { player in
                        mpvPlayer = player
                        onPlayerReady(player)
                    }
                )
                .aspectRatio(16/9, contentMode: .fill)
                .background(Color.black)
                .clipped()
            }
        }

        struct MPVUIKitPlayerRepresentable: UIViewRepresentable {
            let videoURL: URL
            let onPlayerReady: (MPVPlayer) -> Void
            func makeUIView(context: Context) -> MPVUIKitPlayerUIView {
                let playerView = MPVUIKitPlayerUIView()
                playerView.setup(with: videoURL, onReady: onPlayerReady)
                return playerView
            }
            func updateUIView(_ uiView: MPVUIKitPlayerUIView, context: Context) {
                // 更新UI视图
            }
        }

        class MPVUIKitPlayerUIView: UIView {
            private var mpvPlayer: MPVPlayer?
            override init(frame: CGRect) {
                super.init(frame: frame)
                backgroundColor = .black
            }
            required init?(coder: NSCoder) {
                super.init(coder: coder)
                backgroundColor = .black
            }
            func setup(with url: URL, onReady: @escaping (MPVPlayer) -> Void) {
                let player = MPVPlayer()
                player.open(url)
                player.drawable = self
                mpvPlayer = player
                onReady(player)
            }
            override func layoutSubviews() {
                super.layoutSubviews()
                // 让视频按容器填充，保持比例
            }
        }
    }
}
