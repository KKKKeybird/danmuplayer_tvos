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
        // 假设 MPVView 有 player 属性
        // 实际请参考 MPVKit 文档
        return MPVPlayer.shared
    }
}

extension MPVPlayer {
    func load(url: URL) {
        // 加载视频
        // 实际请参考 MPVKit 文档
    }
    func addSubtitle(url: URL) {
        // 加载字幕
        // 实际请参考 MPVKit 文档
    }
    var onPlaybackEnded: (() -> Void)? {
        get { nil } set { /* 监听播放结束 */ }
    }
    static var shared: MPVPlayer {
        // 单例或全局播放器
        // 实际请参考 MPVKit 文档
        MPVPlayer()
    }
}
