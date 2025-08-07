/// 基于真实 Swiftfin tvOS 架构的视频播放器
import SwiftUI
import VLCKitSPM

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
