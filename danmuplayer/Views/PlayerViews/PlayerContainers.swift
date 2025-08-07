/// 播放器View层 - UI组件和工厂方法
import SwiftUI

// MARK: - 简化播放器参数

/// 统一播放器参数结构
struct PlayerParameters {
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

// MARK: - 统一播放器工厂

@available(tvOS 17.0, *)
struct UnifiedPlayerFactory {
    
    /// 统一播放器创建方法
    @MainActor
    static func createPlayer(parameters: PlayerParameters) -> SwiftfinStyleVideoPlayerView {
        let viewModel = VideoPlayerViewModel(
            videoURL: parameters.videoURL,
            originalFileName: parameters.originalFileName,
            subtitleFiles: parameters.subtitleFiles,
            mediaType: parameters.mediaType
        )
        viewModel.dismiss = parameters.onDismiss
        
        return SwiftfinStyleVideoPlayerView(viewModel: viewModel)
    }
}

// MARK: - 播放器容器视图

/// 统一的播放器容器视图
@available(tvOS 17.0, *)
struct UnifiedPlayerContainerView<Content: View>: View {
    let content: () -> Content
    @StateObject private var stateManager = PlayerStateManager()
    
    var body: some View {
        ZStack {
            if stateManager.isLoading {
                UnifiedLoadingView()
            } else if let errorMessage = stateManager.errorMessage {
                UnifiedErrorView(
                    errorMessage: errorMessage,
                    onDismiss: {
                        // 处理错误后的操作
                        stateManager.clearError()
                    }
                )
            } else {
                content()
            }
        }
        .environmentObject(stateManager)
    }
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
}

// MARK: - WebDAV播放器容器

/// WebDAV播放器专用容器
@available(tvOS 17.0, *)
struct WebDAVPlayerContainer: View {
    let videoItem: WebDAVItem
    let subtitleFiles: [WebDAVItem]
    let webDAVClient: WebDAVClient
    
    @State private var videoURL: URL?
    @EnvironmentObject private var stateManager: PlayerStateManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        UnifiedPlayerContainerView {
            if let videoURL = videoURL {
                UnifiedPlayerFactory.createWebDAVPlayer(
                    videoItem: videoItem,
                    subtitleFiles: subtitleFiles,
                    videoURL: videoURL,
                    onDismiss: { dismiss() }
                )
            } else {
                Color.clear
                    .onAppear {
                        loadVideoURL()
                    }
            }
        }
    }
    
    private func loadVideoURL() {
        stateManager.setLoading(true)
        stateManager.clearError()
        
        webDAVClient.getStreamingURL(for: videoItem.path) { result in
            Task { @MainActor in
                stateManager.setLoading(false)
                switch result {
                case .success(let url):
                    videoURL = url
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        stateManager.setError(networkError.localizedDescription)
                    } else {
                        stateManager.setError(error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - Jellyfin播放器容器

/// Jellyfin播放器专用容器
@available(tvOS 17.0, *)
struct JellyfinPlayerContainer: View {
    let mediaItem: JellyfinMediaItem
    let jellyfinClient: JellyfinClient
    
    @State private var videoURL: URL?
    @EnvironmentObject private var stateManager: PlayerStateManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        UnifiedPlayerContainerView {
            if let videoURL = videoURL {
                UnifiedPlayerFactory.createJellyfinPlayer(
                    mediaItem: mediaItem,
                    videoURL: videoURL,
                    onDismiss: { dismiss() }
                )
            } else {
                Color.clear
                    .onAppear {
                        loadVideoURL()
                    }
            }
        }
    }
    
    private func loadVideoURL() {
        stateManager.setLoading(true)
        stateManager.clearError()
        
        guard let url = jellyfinClient.getPlaybackUrl(itemId: mediaItem.id) else {
            stateManager.setError("无法获取播放地址")
            stateManager.setLoading(false)
            return
        }
        
        stateManager.setLoading(false)
        videoURL = url
    }
}

// MARK: - 状态视图组件

/// 统一的加载视图
@available(tvOS 17.0, *)
struct UnifiedLoadingView: View {
    var body: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("正在获取视频链接...")
                .font(.title3)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

/// 统一的错误视图
@available(tvOS 17.0, *)
struct UnifiedErrorView: View {
    let errorMessage: String?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            
            Text("无法加载视频")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            Button {
                onDismiss()
            } label: {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("返回")
                }
                .font(.title2)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
