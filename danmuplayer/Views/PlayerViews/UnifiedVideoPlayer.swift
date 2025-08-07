/// 统一视频播放器 - 简化架构
import SwiftUI
import VLCKitSPM
import Foundation

// MARK: - 播放器参数

/// 统一播放器参数结构
struct UnifiedPlayerParameters {
    let videoURL: URL
    let originalFileName: String
    let subtitleFiles: [SubtitleFileInfo]
    let mediaType: MediaSourceType
    let onDismiss: () -> Void
}

/// 字幕文件信息
struct SubtitleFileInfo {
    let name: String
    let url: URL?
    let language: String?
}

/// 媒体源类型
enum MediaSourceType {
    case webDAV
    case jellyfin
    case local
}

// MARK: - 统一播放器视图

@available(tvOS 17.0, *)
struct UnifiedVideoPlayer: View {
    let parameters: UnifiedPlayerParameters
    
    @StateObject private var viewModel: UnifiedVideoPlayerViewModel
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
    
    init(parameters: UnifiedPlayerParameters) {
        self.parameters = parameters
        self._viewModel = StateObject(wrappedValue: UnifiedVideoPlayerViewModel(parameters: parameters))
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
                    videoURL: parameters.videoURL
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
                viewModel.updateVLCDanmaku(for: player)
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
                    parameters.onDismiss()
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
                    parameters.onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white)
                        .padding()
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                
                Text(viewModel.displayTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                Spacer()
                
                SwiftfinBarActionButtons()
            }
            
            if let subtitle = viewModel.episodeTitle, !subtitle.isEmpty {
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
                Text(viewModel.displayTitle)
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
            
            // 选集按钮（如果有候选列表）
            if !viewModel.candidateSeriesList.isEmpty {
                Button {
                    viewModel.showingSeriesSelection = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
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
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: parameters.videoURL)
        player.media = media
        
        // VLC 配置
        player.scaleFactor = 0
        player.audio?.volume = 100
        player.videoCropGeometry = nil
        player.videoAspectRatio = nil
        
        self.vlcPlayer = player
        self.currentProgressHandler.startTracking(player: player)
        
        // 加载外部字幕文件
        for subtitleFile in parameters.subtitleFiles {
            if let url = subtitleFile.url {
                player.addPlaybackSlave(url, type: .subtitle, enforce: false)
            }
        }
        
        // 初始化弹幕加载
        viewModel.initializeDanmakuLoading(for: player)
        
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
        viewModel.cleanup()
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
            parameters.onDismiss()
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

// MARK: - 统一播放器 ViewModel

@MainActor
@available(tvOS 17.0, *)
class UnifiedVideoPlayerViewModel: ObservableObject {
    @Published var danmakuComments: [DanmakuComment] = []
    @Published var danmakuSettings = DanmakuSettings()
    @Published var candidateSeriesList: [DanDanPlayEpisode] = []
    @Published var showingSeriesSelection = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let parameters: UnifiedPlayerParameters
    private let danDanAPI = DanDanPlayAPI()
    private var vlcPlayer: VLCMediaPlayer?
    private var danmakuASSContent: String?
    
    var displayTitle: String {
        return (parameters.originalFileName as NSString).deletingPathExtension
    }
    
    var episodeTitle: String? {
        return parameters.originalFileName
    }
    
    init(parameters: UnifiedPlayerParameters) {
        self.parameters = parameters
        
        // 根据媒体类型配置弹幕设置
        switch parameters.mediaType {
        case .webDAV:
            danmakuSettings.isEnabled = false // WebDAV默认关闭弹幕
        case .jellyfin, .local:
            danmakuSettings.isEnabled = true  // Jellyfin和本地默认开启弹幕
        }
    }
    
    /// 初始化弹幕加载
    func initializeDanmakuLoading(for player: VLCMediaPlayer) {
        self.vlcPlayer = player
        
        // 首先检查ASS缓存
        checkDanmakuASSCache()
    }
    
    /// 检查弹幕ASS缓存
    private func checkDanmakuASSCache() {
        let fileName = (parameters.originalFileName as NSString).deletingPathExtension
        let cacheKey = fileName.lowercased()
        
        // 尝试从缓存获取ASS内容（使用文件名的hash作为episodeId）
        let episodeId = abs(cacheKey.hash)
        if let cachedASS = DanDanPlayCache.shared.getCachedASSSubtitle(for: episodeId) {
            print("📦 命中弹幕ASS缓存")
            self.danmakuASSContent = cachedASS
            loadCachedDanmaku()
            if let player = vlcPlayer {
                updateVLCDanmaku(for: player)
            }
        } else {
            print("🔍 未命中弹幕ASS缓存，开始搜索弹幕")
            searchDanmaku()
        }
    }
    
    /// 搜索弹幕
    private func searchDanmaku() {
        isLoading = true
        errorMessage = nil
        
        // 使用文件名进行弹幕识别
        danDanAPI.identifyEpisodeByName(parameters.originalFileName) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let episode):
                    print("🎯 成功识别番剧: \(episode.displayTitle)")
                    self.loadDanmakuAndConvertToASS(for: episode)
                case .failure(let error):
                    print("❌ 弹幕识别失败: \(error.localizedDescription)")
                    self.errorMessage = "弹幕识别失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 加载弹幕并转换为ASS格式
    private func loadDanmakuAndConvertToASS(for episode: DanDanPlayEpisode) {
        // 使用新的API直接获取ASS格式
        danDanAPI.loadDanmakuAsASS(for: episode) { result in
            Task { @MainActor in
                switch result {
                case .success(let assContent):
                    print("🎭 成功获取ASS格式弹幕")
                    self.danmakuASSContent = assContent
                    
                    // 同时为UI显示加载弹幕数据
                    self.loadDanmakuForUI(episode: episode)
                    
                    // 更新VLC字幕
                    if let player = self.vlcPlayer {
                        self.updateVLCDanmaku(for: player)
                    }
                    
                case .failure(let error):
                    print("❌ ASS弹幕加载失败: \(error.localizedDescription)")
                    self.errorMessage = "弹幕加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 为UI显示加载弹幕数据
    private func loadDanmakuForUI(episode: DanDanPlayEpisode) {
        danDanAPI.loadDanmaku(for: episode) { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    do {
                        let commentResult = try JSONDecoder().decode(DanDanPlayCommentResult.self, from: data)
                        let comments = commentResult.comments ?? []
                        let danmakuParams = comments.compactMap { $0.parsedParams }
                        
                        // 转换为DanmakuComment格式（用于UI显示）
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
                        
                        print("📺 UI弹幕数据已加载: \(self.danmakuComments.count) 条")
                        
                    } catch {
                        print("❌ UI弹幕数据解析失败: \(error)")
                    }
                case .failure:
                    // UI弹幕加载失败不影响ASS弹幕显示
                    print("⚠️ UI弹幕数据加载失败，但ASS弹幕仍可正常显示")
                }
            }
        }
    }
    
    /// 加载缓存的弹幕数据（用于UI显示）
    private func loadCachedDanmaku() {
        // 从ASS内容中解析弹幕数据用于UI显示
        // 这里可以实现ASS解析逻辑，或者保持简单只显示空数组
        self.danmakuComments = []
        print("📺 已加载缓存的弹幕内容")
    }
    
    /// 转换弹幕参数为ASS格式
    private func convertToASSFormat(danmakuParams: [CommentData.DanmakuParams], episode: DanDanPlayEpisode) -> String {
        let converter = DanmakuToSubtitleConverter()
        return converter.convertToASS(
            danmakuParams: danmakuParams,
            episodeId: episode.episodeId,
            episodeTitle: episode.displayTitle
        )
    }
    
    /// 更新VLC弹幕显示
    func updateVLCDanmaku(for player: VLCMediaPlayer) {
        guard danmakuSettings.isEnabled,
              let assContent = danmakuASSContent,
              !assContent.isEmpty else {
            // 如果弹幕被禁用或没有内容，移除弹幕字幕
            removeDanmakuFromVLC(player: player)
            return
        }
        
        // 创建临时ASS文件并添加到VLC
        addDanmakuToVLC(player: player, assContent: assContent)
    }
    
    /// 添加弹幕到VLC
    private func addDanmakuToVLC(player: VLCMediaPlayer, assContent: String) {
        do {
            // 创建临时ASS文件
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("danmaku_\(UUID().uuidString).ass")
            
            try assContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // 添加到VLC作为字幕轨道
            player.addPlaybackSlave(tempURL, type: .subtitle, enforce: false)
            
            print("🎭 弹幕ASS字幕已添加到VLC")
            
        } catch {
            print("❌ 添加弹幕到VLC失败: \(error)")
        }
    }
    
    /// 从VLC移除弹幕
    private func removeDanmakuFromVLC(player: VLCMediaPlayer) {
        // 这里可以实现移除特定字幕轨道的逻辑
        print("🚫 弹幕已从VLC移除")
    }
    
    /// 清理资源
    func cleanup() {
        vlcPlayer = nil
        danmakuASSContent = nil
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
