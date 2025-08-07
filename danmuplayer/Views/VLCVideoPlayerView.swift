/// VLCKit 集成的视频播放器 - 基于 Swiftfin 设计
import SwiftUI
import VLCKitSPM
import AVFoundation

/// 基于 VLCKit 的视频播放器视图，采用 Swiftfin 的现代化设计
@available(tvOS 17.0, *)
struct VLCVideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    @State private var isPresentingOverlay: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var vlcPlayer: VLCMediaPlayer?
    @State private var currentProgressHandler: ProgressHandler = ProgressHandler()
    @State private var isPlaying: Bool = false
    @State private var overlayTimer: Timer?
    
    @FocusState private var overlayFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color.black.ignoresSafeArea()
                
                // VLC 播放器核心视图
                VLCPlayerViewRepresentable(
                    player: $vlcPlayer,
                    progressHandler: $currentProgressHandler,
                    isPlaying: $isPlaying,
                    videoURL: viewModel.videoURL
                )
                .ignoresSafeArea()
                .onTapGesture {
                    // tvOS 不支持 onTapGesture，这里保留作为占位符
                }
                
                // 弹幕覆盖层
                if viewModel.danmakuSettings.isEnabled {
                    DanmakuOverlayLayer(
                        comments: viewModel.danmakuComments,
                        settings: viewModel.danmakuSettings,
                        currentTime: currentProgressHandler.seconds
                    )
                    .allowsHitTesting(false)
                }
                
                // 播放器控制覆盖层 - Swiftfin 风格
                if isPresentingOverlay {
                    SwiftfinStyleOverlay(
                        viewModel: viewModel,
                        vlcPlayer: vlcPlayer,
                        progressHandler: currentProgressHandler,
                        isPlaying: isPlaying,
                        isScrubbing: $isScrubbing,
                        onSeek: performSeek,
                        onDismiss: {
                            viewModel.dismiss?() ?? dismiss()
                        }
                    )
                    .focused($overlayFocused)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .animation(.easeInOut(duration: 0.4), value: isPresentingOverlay)
                }
                
                // 顶部状态栏 - 显示播放信息
                if isPresentingOverlay {
                    VStack {
                        SwiftfinTopBar(
                            title: viewModel.series?.displayTitle ?? "未知视频",
                            subtitle: formatTime(currentProgressHandler.seconds) + " / " + formatTime(currentProgressHandler.duration),
                            onBack: {
                                viewModel.dismiss?() ?? dismiss()
                            }
                        )
                        .padding(.top, 60)
                        .padding(.horizontal, 80)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isPresentingOverlay)
                }
            }
        }
        .focusable(!isPresentingOverlay)
        .onMoveCommand(perform: handleMoveCommand)
        .onPlayPauseCommand(perform: handlePlayPauseCommand)
        .onExitCommand(perform: handleExitCommand)
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanupPlayer)
        .onChange(of: isScrubbing) { _, newValue in
            if !newValue, let player = vlcPlayer {
                let targetTime = Int64(currentProgressHandler.scrubbedProgress * Float(player.media?.length.intValue ?? 0))
                player.time = VLCTime(int: Int32(targetTime))
            }
        }
        .onChange(of: overlayFocused) { _, focused in
            if focused {
                resetOverlayTimer()
            }
        }
    }
    
    // MARK: - Player Setup & Cleanup
    
    private func setupPlayer() {
        guard let url = viewModel.videoURL else { return }
        
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        player.media = media
        
        // VLC 配置选项
        setupVLCOptions(player: player)
        
        self.vlcPlayer = player
        
        // 自动播放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            player.play()
            self.isPlaying = true
            self.showOverlayTemporarily()
        }
    }
    
    private func setupVLCOptions(player: VLCMediaPlayer) {
        // 基础播放配置
        player.scaleFactor = 0 // 自适应缩放
        
        // 音频配置
        player.audio?.volume = 100
        
        // 视频配置
        player.videoCropGeometry = nil // 不裁剪
        player.videoAspectRatio = nil // 保持原始比例
    }
    
    private func cleanupPlayer() {
        overlayTimer?.invalidate()
        vlcPlayer?.stop()
        vlcPlayer = nil
    }
    
    // MARK: - Player Controls
    
    private func performSeek(to position: Float) {
        guard let player = vlcPlayer,
              let mediaLength = player.media?.length.intValue else { return }
        
        let targetTime = Int64(position * Float(mediaLength))
        player.time = VLCTime(int: Int32(targetTime))
        showOverlayTemporarily()
    }
    
    private func seekForward(seconds: Int = 10) {
        guard let player = vlcPlayer else { return }
        let newTime = player.time.intValue + Int32(seconds * 1000)
        player.time = VLCTime(int: newTime)
        showOverlayTemporarily()
    }
    
    private func seekBackward(seconds: Int = 10) {
        guard let player = vlcPlayer else { return }
        let newTime = max(0, player.time.intValue - Int32(seconds * 1000))
        player.time = VLCTime(int: newTime)
        showOverlayTemporarily()
    }
    
    private func togglePlayPause() {
        guard let player = vlcPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        showOverlayTemporarily()
    }
    
    // MARK: - Remote Control Handling
    
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        if isPresentingOverlay {
            // 在控制面板显示时不处理导航
            return
        }
        
        switch direction {
        case .left:
            seekBackward(seconds: 10)
        case .right:
            seekForward(seconds: 10)
        case .up, .down:
            showOverlay()
        @unknown default:
            break
        }
    }
    
    private func handlePlayPauseCommand() {
        togglePlayPause()
    }
    
    private func handleExitCommand() {
        if isPresentingOverlay {
            hideOverlay()
        } else {
            // 退出播放器
            viewModel.dismiss?() ?? dismiss()
        }
    }
    
    // MARK: - Overlay Management
    
    private func showOverlay() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isPresentingOverlay = true
        }
        overlayFocused = true
        resetOverlayTimer()
    }
    
    private func hideOverlay() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isPresentingOverlay = false
        }
        overlayFocused = false
        overlayTimer?.invalidate()
    }
    
    private func showOverlayTemporarily() {
        showOverlay()
        resetOverlayTimer()
    }
    
    private func resetOverlayTimer() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if isPresentingOverlay && !overlayFocused && !isScrubbing {
                hideOverlay()
            }
        }
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Swiftfin Style Components

/// Swiftfin 风格的顶部状态栏
@available(tvOS 17.0, *)
struct SwiftfinTopBar: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.medium))
                    Text("返回")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.8))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

/// Swiftfin 风格的主控制覆盖层
@available(tvOS 17.0, *)
struct SwiftfinStyleOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let vlcPlayer: VLCMediaPlayer?
    @ObservedObject var progressHandler: ProgressHandler
    let isPlaying: Bool
    @Binding var isScrubbing: Bool
    let onSeek: (Float) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedControl: ControlType = .playPause
    @State private var showingSpeedMenu = false
    
    enum ControlType: CaseIterable {
        case playPause, seekBackward, seekForward, danmaku, series, speed, settings
        
        var systemImage: String {
            switch self {
            case .playPause: return "play.fill" // 动态更新
            case .seekBackward: return "gobackward.10"
            case .seekForward: return "goforward.10"
            case .danmaku: return "bubble.left.fill"
            case .series: return "list.bullet.rectangle"
            case .speed: return "speedometer"
            case .settings: return "gearshape.fill"
            }
        }
        
        var title: String {
            switch self {
            case .playPause: return "播放"
            case .seekBackward: return "快退"
            case .seekForward: return "快进"
            case .danmaku: return "弹幕"
            case .series: return "选集"
            case .speed: return "倍速"
            case .settings: return "设置"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 媒体信息区域
            if let series = viewModel.series {
                SwiftfinMediaInfoCard(series: series)
                    .padding(.horizontal, 80)
                    .padding(.bottom, 30)
            }
            
            // 进度条区域
            SwiftfinProgressSection(
                progressHandler: progressHandler,
                onSeek: onSeek
            )
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
            
            // 主控制按钮区域
            SwiftfinMainControls(
                isPlaying: isPlaying,
                onPlayPause: { togglePlayPause() },
                onSeekBackward: { seekBackward() },
                onSeekForward: { seekForward() },
                selectedControl: $selectedControl
            )
            .padding(.bottom, 30)
            
            // 次要控制按钮区域
            SwiftfinSecondaryControls(
                viewModel: viewModel,
                vlcPlayer: vlcPlayer,
                selectedControl: $selectedControl,
                showingSpeedMenu: $showingSpeedMenu
            )
            
            Spacer().frame(height: 100)
        }
        .background(
            // Swiftfin 风格的渐变背景
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.3), location: 0.3),
                    .init(color: .black.opacity(0.8), location: 0.7),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func togglePlayPause() {
        guard let player = vlcPlayer else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func seekForward() {
        guard let player = vlcPlayer else { return }
        let newTime = player.time.intValue + 10000
        player.time = VLCTime(int: newTime)
    }
    
    private func seekBackward() {
        guard let player = vlcPlayer else { return }
        let newTime = max(0, player.time.intValue - 10000)
        player.time = VLCTime(int: newTime)
    }
}

/// Swiftfin 风格的媒体信息卡片
@available(tvOS 17.0, *)
struct SwiftfinMediaInfoCard: View {
    let series: DanDanPlaySeries
    
    var body: some View {
        VStack(spacing: 16) {
            Text("当前播放")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            
            Text(series.displayTitle)
                .font(.title.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if !series.episodeTitle.isEmpty {
                Text(series.episodeTitle)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.6))
        )
    }
}

/// Swiftfin 风格的进度条区域
@available(tvOS 17.0, *)
struct SwiftfinProgressSection: View {
    @ObservedObject var progressHandler: ProgressHandler
    let onSeek: (Float) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 时间显示
            HStack {
                Text(formatTime(progressHandler.seconds))
                    .font(.title3.monospacedDigit())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatTime(progressHandler.duration))
                    .font(.title3.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // 进度条 - Swiftfin 风格
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.3))
                    .frame(height: 8)
                
                // 进度填充
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: geometry.size.width * CGFloat(progressHandler.progress))
                        .animation(.linear(duration: 0.1), value: progressHandler.progress)
                }
                .frame(height: 8)
                
                // 进度指示器
                HStack {
                    Spacer()
                        .frame(width: CGFloat(progressHandler.progress) * UIScreen.main.bounds.width * 0.6)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                }
            }
        }
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

/// Swiftfin 风格的主控制按钮
@available(tvOS 17.0, *)
struct SwiftfinMainControls: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onSeekBackward: () -> Void
    let onSeekForward: () -> Void
    @Binding var selectedControl: SwiftfinStyleOverlay.ControlType
    
    var body: some View {
        HStack(spacing: 80) {
            // 快退按钮
            SwiftfinControlButton(
                icon: "gobackward.10",
                title: "快退 10s",
                isSelected: selectedControl == .seekBackward,
                size: .medium,
                action: onSeekBackward
            )
            
            // 播放/暂停按钮 - 突出显示
            SwiftfinControlButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                title: isPlaying ? "暂停" : "播放",
                isSelected: selectedControl == .playPause,
                size: .large,
                action: onPlayPause
            )
            
            // 快进按钮
            SwiftfinControlButton(
                icon: "goforward.10",
                title: "快进 10s",
                isSelected: selectedControl == .seekForward,
                size: .medium,
                action: onSeekForward
            )
        }
    }
}

/// Swiftfin 风格的次要控制按钮
@available(tvOS 17.0, *)
struct SwiftfinSecondaryControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let vlcPlayer: VLCMediaPlayer?
    @Binding var selectedControl: SwiftfinStyleOverlay.ControlType
    @Binding var showingSpeedMenu: Bool
    
    var body: some View {
        HStack(spacing: 60) {
            SwiftfinControlButton(
                icon: viewModel.danmakuSettings.isEnabled ? "bubble.left.fill" : "bubble.left",
                title: "弹幕",
                isSelected: selectedControl == .danmaku,
                size: .small
            ) {
                viewModel.danmakuSettings.isEnabled.toggle()
            }
            
            SwiftfinControlButton(
                icon: "list.bullet.rectangle",
                title: "选集",
                isSelected: selectedControl == .series,
                size: .small
            ) {
                viewModel.fetchCandidateSeriesList()
            }
            
            // 倍速控制
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button("\(rate, specifier: "%.2g")x") {
                        vlcPlayer?.rate = Float(rate)
                    }
                }
            } label: {
                SwiftfinControlButton(
                    icon: "speedometer",
                    title: "倍速",
                    isSelected: selectedControl == .speed,
                    size: .small
                ) {
                    // Menu 会处理
                }
            }
            
            SwiftfinControlButton(
                icon: "gearshape.fill",
                title: "设置",
                isSelected: selectedControl == .settings,
                size: .small
            ) {
                // 待实现设置页面
            }
        }
    }
}

/// Swiftfin 风格的控制按钮
@available(tvOS 17.0, *)
struct SwiftfinControlButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let size: ButtonSize
    let action: () -> Void
    
    enum ButtonSize {
        case small, medium, large
        
        var iconSize: Font {
            switch self {
            case .small: return .title2
            case .medium: return .largeTitle
            case .large: return .system(size: 48)
            }
        }
        
        var frameSize: CGSize {
            switch self {
            case .small: return CGSize(width: 100, height: 80)
            case .medium: return CGSize(width: 120, height: 100)
            case .large: return CGSize(width: 140, height: 120)
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(size.iconSize)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: size.frameSize.width, height: size.frameSize.height)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? .white.opacity(0.25) : .white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(isSelected ? 0.4 : 0.2), lineWidth: 2)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Progress Handler

@available(tvOS 17.0, *)
class ProgressHandler: ObservableObject {
    @Published var progress: Float = 0.0
    @Published var seconds: Int = 0
    @Published var duration: Int = 0
    @Published var scrubbedProgress: Float = 0.0
    
    private var player: VLCMediaPlayer?
    private var timer: Timer?
    
    init() {
        // 明确的初始化器
    }
    
    func startTracking(player: VLCMediaPlayer) {
        self.player = player
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
        player = nil
    }
    
    func updateProgress(currentTime: Int, duration: Int) {
        self.seconds = currentTime / 1000 // VLC 时间以毫秒为单位
        self.duration = duration / 1000
        self.progress = duration > 0 ? Float(currentTime) / Float(duration) : 0
        
        if scrubbedProgress == 0 || abs(scrubbedProgress - progress) < 0.01 {
            scrubbedProgress = progress
        }
    }
    
    private func updateProgress() {
        guard let player = player,
              let media = player.media,
              media.length.intValue > 0 else {
            return
        }
        
        let currentTime = player.time.intValue
        let totalTime = media.length.intValue
        
        DispatchQueue.main.async { [weak self] in
            self?.seconds = Int(currentTime / 1000)
            self?.duration = Int(totalTime / 1000)
            self?.progress = Float(currentTime) / Float(totalTime)
        }
    }
}

// MARK: - VLC Player UIKit Wrapper

struct VLCPlayerViewRepresentable: UIViewRepresentable {
    @Binding var player: VLCMediaPlayer?
    @Binding var progressHandler: ProgressHandler
    @Binding var isPlaying: Bool
    let videoURL: URL?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player {
            player.drawable = uiView
            
            // 设置播放状态监听
            setupPlayerObservers(player: player)
        }
    }
    
    private func setupPlayerObservers(player: VLCMediaPlayer) {
        // 进度更新定时器
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard player.isPlaying else {
                // 检查播放器是否结束或停止
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                let currentTime = Int(player.time.intValue)
                let duration = Int(player.media?.length.intValue ?? 0)
                
                progressHandler.updateProgress(currentTime: currentTime, duration: duration)
                isPlaying = player.isPlaying
            }
        }
    }
}

// MARK: - Control Overlay

@available(tvOS 17.0, *)
struct VLCControlOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let vlcPlayer: VLCMediaPlayer?
    @ObservedObject var progressHandler: ProgressHandler
    let isPlaying: Bool
    @Binding var isScrubbing: Bool
    let onSeek: (Float) -> Void
    
    @State private var selectedButton: ControlButton? = .playPause
    
    enum ControlButton: CaseIterable {
        case seekBackward, playPause, seekForward, danmakuSettings, seriesSelection, speedControl
        
        var icon: String {
            switch self {
            case .seekBackward: return "gobackward.10"
            case .playPause: return "play.fill" // 动态更新
            case .seekForward: return "goforward.10"
            case .danmakuSettings: return "slider.horizontal.3"
            case .seriesSelection: return "list.bullet"
            case .speedControl: return "speedometer"
            }
        }
        
        var title: String {
            switch self {
            case .seekBackward: return "快退"
            case .playPause: return "播放/暂停"
            case .seekForward: return "快进"
            case .danmakuSettings: return "弹幕设置"
            case .seriesSelection: return "选择番剧"
            case .speedControl: return "播放速度"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 播放进度条
            VStack(spacing: 20) {
                HStack {
                    Text(formatTime(progressHandler.seconds))
                        .foregroundColor(.white)
                        .font(.title3)
                    
                    Spacer()
                    
                    Text(formatTime(progressHandler.duration))
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                ProgressView(value: progressHandler.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.3))
                    .frame(height: 6)
                    .cornerRadius(3)
            }
            .padding(.horizontal, 80)
            
            // 媒体信息
            if let series = viewModel.series {
                VStack(spacing: 8) {
                    Text("当前播放")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    Text(series.displayTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            
            // 控制按钮
            HStack(spacing: 60) {
                // 快退按钮
                ControlButtonView(
                    icon: "gobackward.10",
                    title: "快退 10s",
                    isSelected: selectedButton == .seekBackward
                ) {
                    seekBackward()
                }
                
                // 播放/暂停按钮
                ControlButtonView(
                    icon: isPlaying ? "pause.fill" : "play.fill",
                    title: isPlaying ? "暂停" : "播放",
                    isSelected: selectedButton == .playPause
                ) {
                    togglePlayPause()
                }
                
                // 快进按钮
                ControlButtonView(
                    icon: "goforward.10",
                    title: "快进 10s",
                    isSelected: selectedButton == .seekForward
                ) {
                    seekForward()
                }
            }
            
            // 次要控制按钮
            HStack(spacing: 40) {
                ControlButtonView(
                    icon: "slider.horizontal.3",
                    title: "弹幕设置",
                    isSelected: selectedButton == .danmakuSettings
                ) {
                    // 打开弹幕设置
                }
                
                ControlButtonView(
                    icon: "list.bullet",
                    title: "选择番剧",
                    isSelected: selectedButton == .seriesSelection
                ) {
                    viewModel.fetchCandidateSeriesList()
                }
                
                // 播放速度控制
                Menu {
                    Button("0.5x") { setPlaybackRate(0.5) }
                    Button("0.75x") { setPlaybackRate(0.75) }
                    Button("1.0x") { setPlaybackRate(1.0) }
                    Button("1.25x") { setPlaybackRate(1.25) }
                    Button("1.5x") { setPlaybackRate(1.5) }
                    Button("2.0x") { setPlaybackRate(2.0) }
                } label: {
                    ControlButtonView(
                        icon: "speedometer",
                        title: "播放速度",
                        isSelected: selectedButton == .speedControl
                    ) {
                        // Menu 会自动处理
                    }
                }
            }
            
            Spacer().frame(height: 60)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Control Actions
    
    private func togglePlayPause() {
        guard let player = vlcPlayer else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func seekForward() {
        guard let player = vlcPlayer else { return }
        let newTime = player.time.intValue + 10000 // 10秒 = 10000毫秒
        player.time = VLCTime(int: newTime)
    }
    
    private func seekBackward() {
        guard let player = vlcPlayer else { return }
        let newTime = max(0, player.time.intValue - 10000)
        player.time = VLCTime(int: newTime)
    }
    
    private func setPlaybackRate(_ rate: Float) {
        vlcPlayer?.rate = rate
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Control Button View

@available(tvOS 17.0, *)
struct ControlButtonView: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 100, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .white.opacity(0.3) : .white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
