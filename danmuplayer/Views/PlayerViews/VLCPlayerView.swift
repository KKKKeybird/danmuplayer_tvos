/// VLCUI播放器界面 - 主播放器视图
import SwiftUI
import VLCKitSPM
import VLCUI
import Combine

/// 播放器界面，接受视频原始文件名，视频Url和字幕Url，根据视频Url解析文件信息，进入后使用DanDanPlayAPI寻找字幕，加入到字幕轨中同时加载弹幕和字幕
@available(tvOS 17.0, *)
struct VLCPlayerView: View {
    // MARK: - 输入参数
    let videoURL: URL
    let originalFileName: String
    let subtitleURLs: [URL]
    let onDismiss: () -> Void
    
    // MARK: - State管理
    @StateObject private var viewModel: VLCUIPlayerViewModel
    @StateObject private var overlayTimer = TimerProxy()
    @StateObject private var displayLink = DisplayLinkDriver()
    
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isScrubbing = false
    @StateObject private var settingsStore = PlayerSettingsStore.shared
    
    // 设置视图状态
    @State private var showingSettings = false
    
    // 弹幕相关
    @State private var isDanmakuEnabled = true
    @State private var danmakuComments: [DanmakuComment] = []
    @State private var candidateEpisodes: [DanDanPlayEpisode] = []
    @State private var selectedEpisode: DanDanPlayEpisode?
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var pendingDanmakuData: Data?
    @StateObject private var danmakuLogger = DanmakuDebugLogger.shared
    @State private var showDanmakuDebug = false
    @State private var didLoadExternalSubtitles = false
    @State private var hasStartedPlayback = false
    @FocusState private var isMainFocused: Bool
    // 自绘弹幕
    @State private var overlayDanmaku: [DanmakuComment] = []

    
    // MARK: - 初始化
    
    init(videoURL: URL, originalFileName: String, subtitleURLs: [URL] = [], onDismiss: @escaping () -> Void) {
        self.videoURL = videoURL
        self.originalFileName = originalFileName
        self.subtitleURLs = subtitleURLs
        self.onDismiss = onDismiss
        
        self._viewModel = StateObject(wrappedValue: VLCUIPlayerViewModel(
            videoURL: videoURL,
            originalFileName: originalFileName
        ))
    }
    
    // MARK: - 主视图
    
    var body: some View {
        ZStack {
            // 播放器图层
            playerSurface

            // 硬件加速弹幕层（Core Animation）
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
            
            // 简单的VLCUI进度条
            if !viewModel.isLoading, let player = vlcPlayer {
                VStack {
                    Spacer()
                    VLCUIProgressBar(player: player)
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
        .onTapGesture {
            // 中心键/选择键点击时切换播放暂停
            handlePlayPause()
        }
        .onPlayPauseCommand(perform: handlePlayPause)
        .onExitCommand {
            // 退出键返回上一级
            onDismiss()
        }
        .onMoveCommand { dir in
            // 方向键控制播放：左右快退/快进 15 秒
            guard let player = vlcPlayer else { return }
            let currentMs: Int32 = player.time.intValue
            let mediaLengthMs: Int32 = player.media?.length.intValue ?? Int32.max
            let stepMs: Int32 = 15_000
            switch dir {
            case .left:
                let target: Int32 = max(0, currentMs - stepMs)
                player.time = VLCTime(number: NSNumber(value: target))
            case .right:
                let target: Int32 = min(mediaLengthMs, currentMs + stepMs)
                player.time = VLCTime(number: NSNumber(value: target))
            case .up:
                // 按上方向键打开设置（覆盖在播放器上层）
                showingSettings = true
            default:
                break
            }
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            // 长按进入设置（备用触发）
            showingSettings = true
        }
        .onExitCommand(perform: {
            // 退出播放器
            cleanup()
            onDismiss()
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DanmakuDebugToggle"))) { _ in
            withAnimation { showDanmakuDebug.toggle() }
        }
        .onAppear { isMainFocused = true }
        // 设置视图（全屏覆盖在播放器之上）
        .fullScreenCover(isPresented: $showingSettings, onDismiss: {
            // 恢复焦点，必要时继续播放
            isMainFocused = true
        }) {
            VideoPlayerSettingsView(
                isPresented: $showingSettings,
                vlcPlayer: vlcPlayer,
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
    
    private func setupPlayerCallbacks(_ player: VLCMediaPlayer) {
        vlcPlayer = player
        
        // 加载所有外部字幕（仅一次）
        if !didLoadExternalSubtitles {
            for url in subtitleURLs {
                loadExternalSubtitle(url: url)
            }
            didLoadExternalSubtitles = true
        }
        
        // 如果有待加载的弹幕数据，播放器就绪后加载到DanmakuCanvas
        if pendingDanmakuData != nil && isDanmakuEnabled {
            // 现在使用DanmakuCanvas，不需要加载到VLC字幕轨道
            pendingDanmakuData = nil
        }

        // 覆盖层由PlayerOverlayView自己管理
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
        // 使用播放器创建时传入的文件名，而不是自己解析URL
        DanDanPlayAPI().fetchCandidateEpisodeList(for: videoURL, overrideFileName: originalFileName) { result in
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
            player.pause()
        } else {
            player.play()
        }
        
        // 延迟一点更新状态，确保VLC状态已经改变
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPlaying = player.isPlaying
        }
    }

    private func startPlaybackIfNeeded() {
        guard !hasStartedPlayback, let player = vlcPlayer else { return }
        DispatchQueue.main.async { player.play() }
        hasStartedPlayback = true
    }
    
    private func handleToggleDanmaku() {
        isDanmakuEnabled.toggle()
        
        if isDanmakuEnabled {
            // 重新加载弹幕到DanmakuCanvas
            if let episode = selectedEpisode {
                loadDanmakuForEpisode(episode)
            }
        } else {
            // 清空DanmakuCanvas中的弹幕
            overlayDanmaku = []
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
    
    private func setupPlayerStateUpdates(_ player: VLCMediaPlayer) {
        // 使用VLCUI提供的状态绑定机制
        displayLink.onFrame = {
            guard let player = vlcPlayer else { return }
            let time = player.time
            currentTime = Double(time.intValue) / 1000.0
            if let media = player.media {
                let mediaLength = media.length
                duration = Double(mediaLength.intValue) / 1000.0
            }
            isPlaying = player.isPlaying
        }
        displayLink.start()
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

// MARK: - VLCUI 进度条组件

@available(tvOS 17.0, *)
struct VLCUIProgressBar: View {
    let player: VLCMediaPlayer
    @State private var progress: Float = 0.0
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 时间显示
            HStack {
                Text(formatTime(Double(player.time.intValue) / 1000))
                    .foregroundColor(.white)
                    .font(.caption)
                Spacer()
                Text(formatTime(Double(player.media?.length.intValue ?? 0) / 1000))
                    .foregroundColor(.white)
                    .font(.caption)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // 已播放进度
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                    
                    // 滑块
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(x: geometry.size.width * CGFloat(progress), y: 2)
                }
            }
            .frame(height: 12)
            // tvOS 不支持读取点击位置进行拖拽，使用方向键左右快进/快退
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
            let currentTime = Double(player.time.intValue)
            let totalTime = Double(player.media?.length.intValue ?? 0)
            progress = totalTime > 0 ? Float(currentTime / totalTime) : 0.0
        }
    }
    
    private func showProgressBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = true
        }
        
        // 5秒后自动隐藏
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

// MARK: - ViewModel

class VLCUIPlayerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let videoURL: URL
    private let originalFileName: String
    
    init(videoURL: URL, originalFileName: String) {
        self.videoURL = videoURL
        self.originalFileName = originalFileName
    }
    
    func setupPlayer(completion: @escaping (VLCMediaPlayer) -> Void) {
        isLoading = true
        
        // VLCUI会自动处理播放器的创建，这里只需要设置加载状态
        DispatchQueue.main.async {
            self.isLoading = false
            // 播放器创建由VLCUIVideoPlayerView处理
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
                

            }
        }
        // 使用 fill 让视频等比铺满，避免两侧出现非黑边
        .aspectRatio(16/9, contentMode: .fill)
        .background(Color.black)
        .clipped()
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

        // 不传 freetype 字体配置，使用 libvlc 的默认字体和行为
        let options: [String: Any] = [
            "network-caching": 1000,
            "clock-jitter": 0,
            "clock-synchro": 0,
            "avcodec-hw": "any"
        ]
        media.addOptions(options)
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

struct DanmakuSettings: Codable {
    var isEnabled = true
    var opacity: Double = 0.8
    var fontSize: Double = 32.0
    var displayAreaPercent: Double = 0.7  // 弹幕显示区域占屏幕高度的百分比 (0.1-1.0)
    var speed: Double = 1.6
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

// MARK: - 显示帧驱动

class DisplayLinkDriver: ObservableObject {
    private var link: CADisplayLink?
    var onFrame: (() -> Void)?
    
    func start() {
        stop()
        link = CADisplayLink(target: self, selector: #selector(handleFrame))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        link?.invalidate()
        link = nil
    }
    
    @objc private func handleFrame() {
        onFrame?()
    }
}

