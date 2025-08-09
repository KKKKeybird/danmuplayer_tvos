/// 播放器信息覆盖层 - 使用VLCKit扩展实现
import SwiftUI
import VLCKitSPM
import VLCUI

// MARK: - VLCMediaPlayer 扩展

extension VLCMediaPlayer {
    /// 获取格式化的当前时间
    var formattedCurrentTime: String {
        let time = self.time.intValue / 1000 // 转换为秒
        return formatTime(Double(time))
    }
    
    /// 获取格式化的总时长
    var formattedDuration: String {
        guard let media = self.media else { return "0:00" }
        let duration = media.length.intValue / 1000 // 转换为秒
        return formatTime(Double(duration))
    }
    
    /// 获取播放进度百分比
    var playbackProgress: Float {
        guard let media = self.media else { return 0.0 }
        let currentTime = self.time.intValue
        let totalTime = media.length.intValue
        return totalTime > 0 ? Float(currentTime) / Float(totalTime) : 0.0
    }
    
    /// 跳转到指定进度百分比
    func seekToProgress(_ progress: Float) {
        guard let media = self.media else { return }
        let targetTime = Int32(Float(media.length.intValue) * progress)
        self.time = VLCTime(number: NSNumber(value: targetTime))
    }
    
    /// 快进指定秒数
    func fastForward(_ seconds: Int) {
        let currentTime = self.time.intValue
        let newTime = currentTime + Int32(seconds * 1000)
        self.time = VLCTime(number: NSNumber(value: newTime))
    }
    
    /// 快退指定秒数
    func rewind(_ seconds: Int) {
        let currentTime = self.time.intValue
        let newTime = max(0, currentTime - Int32(seconds * 1000))
        self.time = VLCTime(number: NSNumber(value: newTime))
    }
    
    /// 格式化时间的私有方法
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

// MARK: - VLC 播放器控制协议

protocol VLCPlayerControlDelegate: AnyObject {
    func playerDidRequestAudioTrackSelection()
    func playerDidRequestSubtitleSelection()
    func playerDidRequestDanmakuToggle()
    func playerDidRequestDanmakuMatch()
    func playerDidRequestDanmakuSettings()
    func playerDidRequestDismiss()
}

// MARK: - VLC 集成的信息覆盖层

@available(tvOS 17.0, *)
struct TopInformationOverlay: View {
    @ObservedObject private var playerState: VLCPlayerState
    let controlDelegate: VLCPlayerControlDelegate?
    
    @State private var isVisible: Bool = true
    @State private var hideTimer: Timer?
    @FocusState private var isTopDefaultFocused: Bool
    
    private let shouldRequestFocus: Bool
    private let onRequestHide: (() -> Void)?

    init(player: VLCMediaPlayer, controlDelegate: VLCPlayerControlDelegate? = nil, shouldRequestFocus: Bool = false, onRequestHide: (() -> Void)? = nil) {
        self.playerState = VLCPlayerState(player: player)
        self.controlDelegate = controlDelegate
        self.shouldRequestFocus = shouldRequestFocus
        self.onRequestHide = onRequestHide
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制栏
            topControlBar
            Spacer()
        }
        .background(overlayTopGradient)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            startHideTimer()
            if shouldRequestFocus {
                DispatchQueue.main.async { isTopDefaultFocused = true }
            }
        }
        .onExitCommand {
            withAnimation(.easeInOut(duration: 0.25)) { isVisible = false }
            onRequestHide?()
        }
        .onReceive(playerState.$isPlaying) { $0 ? startHideTimer() : showOverlay() }
        .focusSection()
    }
    
    // MARK: - 子视图
    
    private var topControlBar: some View {
        HStack {
            Button(action: { controlDelegate?.playerDidRequestDismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(.white)
                .font(.body)
            }
            .focused($isTopDefaultFocused)
            
            Spacer()
            
            // 弹幕控制组
            HStack(spacing: 24) {
                overlayButton(
                    icon: "text.bubble",
                    title: "弹幕",
                    action: { controlDelegate?.playerDidRequestDanmakuToggle() }
                )
                
                overlayButton(
                    icon: "magnifyingglass",
                    title: "匹配",
                    action: { controlDelegate?.playerDidRequestDanmakuMatch() }
                )
                
                overlayButton(
                    icon: "slider.horizontal.3",
                    title: "设置",
                    action: { controlDelegate?.playerDidRequestDanmakuSettings() }
                )
                
                // 调试
                overlayButton(
                    icon: "ladybug",
                    title: "调试",
                    action: { NotificationCenter.default.post(name: NSNotification.Name("DanmakuDebugToggle"), object: nil) }
                )
            }
        }
        .padding(.horizontal, 50)
        .padding(.top, 50)
    }
    
    // 顶部无底部控制栏
    
    private var playbackControls: some View {
        HStack(spacing: 50) {
            // 音频轨道
            overlayButton(
                icon: "speaker.wave.2",
                title: "音轨",
                action: { controlDelegate?.playerDidRequestAudioTrackSelection() }
            )
            
            // 快退15秒
            Button(action: { playerState.player.rewind(15) }) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // 播放/暂停
            Button(action: { playerState.togglePlayback() }) {
                Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            
            // 快进15秒
            Button(action: { playerState.player.fastForward(15) }) {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // 字幕选择
            overlayButton(
                icon: "captions.bubble",
                title: "字幕",
                action: { controlDelegate?.playerDidRequestSubtitleSelection() }
            )
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // 时间显示
            HStack {
                Text(playerState.formattedCurrentTime)
                    .foregroundColor(.white)
                    .font(.caption)
                
                Spacer()
                
                Text(playerState.formattedDuration)
                    .foregroundColor(.white)
                    .font(.caption)
            }
            
            // VLC 集成进度条
            VLCProgressBar(playerState: playerState)
        }
    }
    
    private var overlayTopGradient: some View {
        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]), startPoint: .top, endPoint: .center)
    }
    
    // MARK: - 辅助方法
    
    private func overlayButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.white)
        }
    }
    
    private func showOverlay() {
        hideTimer?.invalidate()
        isVisible = true
        DispatchQueue.main.async { isTopDefaultFocused = true }
    }
    
    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
            onRequestHide?()
        }
    }
}

// 底部 Overlay
@available(tvOS 17.0, *)
struct BottomInformationOverlay: View {
    @ObservedObject private var playerState: VLCPlayerState
    let controlDelegate: VLCPlayerControlDelegate?
    @State private var isVisible: Bool = true
    @State private var hideTimer: Timer?

    private let shouldRequestFocus: Bool
    private let onRequestHide: (() -> Void)?

    init(player: VLCMediaPlayer, controlDelegate: VLCPlayerControlDelegate? = nil, shouldRequestFocus: Bool = false, onRequestHide: (() -> Void)? = nil) {
        self.playerState = VLCPlayerState(player: player)
        self.controlDelegate = controlDelegate
        self.shouldRequestFocus = shouldRequestFocus
        self.onRequestHide = onRequestHide
    }

    @FocusState private var isBottomDefaultFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            bottomControlBar
        }
        .background(overlayBottomGradient)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            startHideTimer()
            if shouldRequestFocus {
                DispatchQueue.main.async { isBottomDefaultFocused = true }
            }
        }
        .onExitCommand {
            withAnimation(.easeInOut(duration: 0.25)) { isVisible = false }
            onRequestHide?()
        }
        .onReceive(playerState.$isPlaying) { $0 ? startHideTimer() : showOverlay() }
        .focusSection()
    }

    private var bottomControlBar: some View {
        VStack(spacing: 20) {
            playbackControls
            progressSection
        }
        .padding(.horizontal, 50)
        .padding(.bottom, 50)
    }

    private var playbackControls: some View {
        HStack(spacing: 50) {
            overlayButton(icon: "speaker.wave.2", title: "音轨") { controlDelegate?.playerDidRequestAudioTrackSelection() }
            Button(action: { playerState.player.rewind(15) }) { Image(systemName: "gobackward.15").font(.title2).foregroundColor(.white) }
            Button(action: { playerState.togglePlayback() }) { Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill").font(.largeTitle).foregroundColor(.white) }
            Button(action: { playerState.player.fastForward(15) }) { Image(systemName: "goforward.15").font(.title2).foregroundColor(.white) }
            overlayButton(icon: "captions.bubble", title: "字幕") { controlDelegate?.playerDidRequestSubtitleSelection() }
        }
        .focused($isBottomDefaultFocused)
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(playerState.formattedCurrentTime).foregroundColor(.white).font(.caption)
                Spacer()
                Text(playerState.formattedDuration).foregroundColor(.white).font(.caption)
            }
            VLCProgressBar(playerState: playerState)
        }
    }

    private var overlayBottomGradient: some View {
        LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]), startPoint: .center, endPoint: .bottom)
    }

    private func overlayButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .foregroundColor(.white)
        }
    }

    private func showOverlay() {
        hideTimer?.invalidate()
        isVisible = true
        DispatchQueue.main.async { isBottomDefaultFocused = true }
    }
    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { isVisible = false }
            onRequestHide?()
        }
    }
}

// 播放器状态共享
@available(tvOS 17.0, *)
class VLCPlayerState: ObservableObject {
    let player: VLCMediaPlayer
    private var timeObserver: Timer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: String = "0:00"
    @Published var duration: String = "0:00"
    @Published var progress: Float = 0.0
    var formattedCurrentTime: String { player.formattedCurrentTime }
    var formattedDuration: String { player.formattedDuration }
    init(player: VLCMediaPlayer) { self.player = player; startTimeObserver() }
    deinit { timeObserver?.invalidate() }
    private func startTimeObserver() {
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.update() }
    }
    private func update() {
        isPlaying = player.isPlaying
        currentTime = player.formattedCurrentTime
        duration = player.formattedDuration
        progress = player.playbackProgress
    }
    func togglePlayback() {
        if player.isPlaying {
            DispatchQueue.main.async { self.player.pause() }
        } else {
            DispatchQueue.main.async { self.player.play() }
        }
    }
}

// MARK: - VLC 进度条组件

@available(tvOS 17.0, *)
struct VLCProgressBar: View {
    @ObservedObject var playerState: VLCPlayerState
    @State private var isDragging: Bool = false
    @State private var dragProgress: Float = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                // 进度轨道
                Rectangle()
                    .fill(Color.white)
                    .frame(
                        width: CGFloat(isDragging ? dragProgress : playerState.progress) * geometry.size.width,
                        height: 4
                    )
                
                // 滑块
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .offset(
                        x: CGFloat(isDragging ? dragProgress : playerState.progress) * geometry.size.width - 8
                    )
            }
        }
        .frame(height: 20)
        .focusable()
        .onTapGesture {
            // tvOS 中用点击来显示/隐藏控制栏
            // 实际的拖拽会通过焦点状态和遥控器处理
        }
    }
}

// MARK: - 向后兼容性

/// 原有的 InformationOverlay 结构体的类型别名，用于保持向后兼容性
@available(tvOS 17.0, *)
typealias InformationOverlay = TopInformationOverlay

/// 原有的 OverlayType 枚举，用于保持向后兼容性
extension TopInformationOverlay {
    enum OverlayType {
        case main
        case audioTrack
        case subtitle
        case danmakuMatch
        case danmakuSettings
    }
}
