/// 新的播放器容器 - 简化架构
import SwiftUI

// MARK: - WebDAV播放器容器（新版）

@available(tvOS 17.0, *)
struct NewWebDAVPlayerContainer: View {
    let videoItem: WebDAVItem
    let subtitleFiles: [WebDAVItem]  
    let webDAVClient: WebDAVClient
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playerParameters: UnifiedPlayerParameters?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "正在获取视频链接...")
            } else if let errorMessage = errorMessage {
                ErrorView(message: errorMessage) {
                    dismiss()
                }
            } else if let parameters = playerParameters {
                UnifiedVideoPlayer(parameters: parameters)
            }
        }
        .onAppear {
            loadVideoURL()
        }
    }
    
    private func loadVideoURL() {
        webDAVClient.getStreamingURL(for: videoItem.path) { result in
            Task { @MainActor in
                switch result {
                case .success(let videoURL):
                    // 转换字幕文件信息
                    let subtitleFileInfos = convertSubtitleFiles(subtitleFiles)
                    
                    // 创建播放器参数
                    playerParameters = UnifiedPlayerParameters(
                        videoURL: videoURL,
                        originalFileName: videoItem.name,
                        subtitleFiles: subtitleFileInfos,
                        mediaType: .webDAV,
                        onDismiss: { dismiss() }
                    )
                    
                    isLoading = false
                    
                case .failure(let error):
                    isLoading = false
                    if let networkError = error as? NetworkError {
                        errorMessage = networkError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func convertSubtitleFiles(_ webDAVSubtitles: [WebDAVItem]) -> [SubtitleFileInfo] {
        return webDAVSubtitles.compactMap { item in
            // WebDAV字幕文件需要通过客户端获取URL
            // 这里暂时返回基本信息，实际使用时可能需要异步获取URL
            return SubtitleFileInfo(
                name: item.name,
                url: nil, // 需要异步获取
                language: detectLanguage(from: item.name)
            )
        }
    }
    
    private func detectLanguage(from fileName: String) -> String? {
        let name = fileName.lowercased()
        if name.contains("zh") || name.contains("chi") || name.contains("chs") {
            return "zh"
        } else if name.contains("en") || name.contains("eng") {
            return "en"
        }
        return nil
    }
}

// MARK: - Jellyfin播放器容器（新版）

@available(tvOS 17.0, *)
struct NewJellyfinPlayerContainer: View {
    let mediaItem: JellyfinMediaItem
    let jellyfinClient: JellyfinClient
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playerParameters: UnifiedPlayerParameters?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "正在获取播放地址...")
            } else if let errorMessage = errorMessage {
                ErrorView(message: errorMessage) {
                    dismiss()
                }
            } else if let parameters = playerParameters {
                UnifiedVideoPlayer(parameters: parameters)
            }
        }
        .onAppear {
            loadVideoURL()
        }
    }
    
    private func loadVideoURL() {
        guard let videoURL = jellyfinClient.getPlaybackUrl(itemId: mediaItem.id) else {
            errorMessage = "无法获取播放地址"
            isLoading = false
            return
        }
        
        // Jellyfin通常不需要外部字幕文件，字幕通过API处理
        let subtitleFileInfos: [SubtitleFileInfo] = []
        
        // 创建播放器参数
        playerParameters = UnifiedPlayerParameters(
            videoURL: videoURL,
            originalFileName: mediaItem.name,
            subtitleFiles: subtitleFileInfos,
            mediaType: .jellyfin,
            onDismiss: { dismiss() }
        )
        
        isLoading = false
    }
}

// MARK: - 通用状态视图

@available(tvOS 17.0, *)
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text(message)
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

@available(tvOS 17.0, *)
struct ErrorView: View {
    let message: String
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
            
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
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
