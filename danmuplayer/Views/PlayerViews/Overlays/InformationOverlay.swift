/// 播放器信息覆盖层 - 进度条覆盖层，配有各种控制按钮
import SwiftUI
import VLCKitSPM
import VLCUI

/// 进度条覆盖层，包含视频音频轨选择按钮，字幕选择按钮，弹幕开关按钮，弹幕匹配按钮，弹幕设置按钮
@available(tvOS 17.0, *)
struct InformationOverlay: View {
    @Binding var isVisible: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isPlaying: Bool
    @Binding var currentOverlayType: OverlayType
    
    let vlcPlayer: VLCMediaPlayer?
    let onSeek: (Double) -> Void
    let onPlayPause: () -> Void
    let onShowAudioTracks: () -> Void
    let onShowSubtitles: () -> Void
    let onToggleDanmaku: () -> Void
    let onShowDanmakuMatch: () -> Void
    let onShowDanmakuSettings: () -> Void
    let onDismiss: () -> Void
    
    enum OverlayType {
        case main
        case audioTrack
        case subtitle
        case danmakuMatch
        case danmakuSettings
    }
    
    @State private var isScrubbing: Bool = false
    @State private var scrubbingProgress: Double = 0
    @State private var isSliderFocused: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制栏
            topControlBar
            
            Spacer()
            
            // 底部进度条和控制栏
            bottomControlBar
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.clear,
                    Color.black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
    
    // MARK: - 顶部控制栏
    
    private var topControlBar: some View {
        HStack {
            Button(action: onDismiss) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // 弹幕控制按钮组
            HStack(spacing: 20) {
                Button(action: onToggleDanmaku) {
                    VStack(spacing: 2) {
                        Image(systemName: "text.bubble")
                        Text("弹幕")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onShowDanmakuMatch) {
                    VStack(spacing: 2) {
                        Image(systemName: "magnifyingglass")
                        Text("匹配")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onShowDanmakuSettings) {
                    VStack(spacing: 2) {
                        Image(systemName: "slider.horizontal.3")
                        Text("设置")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }
    
    // MARK: - 底部控制栏
    
    private var bottomControlBar: some View {
        VStack(spacing: 16) {
            // 进度条
            progressSlider
            
            // 播放控制
            playbackControls
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    // MARK: - 进度条
    
    private var progressSlider: some View {
        VStack(spacing: 8) {
            // 时间标签
            HStack {
                Text(formatTime(isScrubbing ? scrubbingProgress : currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // 进度滑块
            ProgressSliderView(
                progress: $currentTime,
                duration: duration,
                isSliderFocused: $isSliderFocused,
                onSeekStarted: {
                    isScrubbing = true
                },
                onSeekChanged: { progress in
                    scrubbingProgress = progress
                },
                onSeekEnded: { finalProgress in
                    isScrubbing = false
                    onSeek(finalProgress)
                }
            )
        }
    }
    
    // MARK: - 播放控制
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // 音频轨道选择
            Button(action: onShowAudioTracks) {
                VStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                    Text("音轨")
                        .font(.caption2)
                }
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 后退15秒
            Button(action: {
                onSeek(max(0, currentTime - 15))
            }) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 播放/暂停
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 快进15秒
            Button(action: {
                onSeek(min(duration, currentTime + 15))
            }) {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 字幕选择
            Button(action: onShowSubtitles) {
                VStack(spacing: 4) {
                    Image(systemName: "captions.bubble")
                    Text("字幕")
                        .font(.caption2)
                }
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 辅助方法
    
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

// MARK: - 进度滑块组件

@available(tvOS 17.0, *)
struct ProgressSliderView: View {
    @Binding var progress: Double
    let duration: Double
    @Binding var isSliderFocused: Bool
    
    let onSeekStarted: () -> Void
    let onSeekChanged: (Double) -> Void
    let onSeekEnded: (Double) -> Void
    
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
                    .frame(width: CGFloat(progress / duration) * geometry.size.width, height: 4)
                
                // 滑块
                Circle()
                    .fill(Color.white)
                    .frame(width: isSliderFocused ? 20 : 12, height: isSliderFocused ? 20 : 12)
                    .offset(x: CGFloat(progress / duration) * geometry.size.width - (isSliderFocused ? 10 : 6))
            }
        }
        .frame(height: 20)
        .focusable()
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { _ in
            // 长按开始拖动
        } onPressingChanged: { isPressing in
            if isPressing {
                onSeekStarted()
            }
        }
        // 这里需要添加手势处理逻辑
    }
}
