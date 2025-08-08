/// VLC播放器容器 - 视频播放生成容器
import SwiftUI

/// 视频播放生成容器，负责创建和管理VLC播放器实例
@available(tvOS 17.0, *)
struct VLCPlayerContainer: View {
    // MARK: - 输入参数
    let videoURL: URL
    let originalFileName: String
    let subtitleURL: URL?
    let onDismiss: () -> Void
    
    // MARK: - 状态管理
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "正在准备播放器...")
            } else if let errorMessage = errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: {
                        setupPlayer()
                    },
                    onDismiss: onDismiss
                )
            } else {
                VLCPlayerView(
                    videoURL: videoURL,
                    originalFileName: originalFileName,
                    subtitleURL: subtitleURL,
                    onDismiss: onDismiss
                )
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    // MARK: - 私有方法
    
    private func setupPlayer() {
        isLoading = true
        errorMessage = nil
        
        // 验证视频URL
        DispatchQueue.global(qos: .userInitiated).async {
            if canAccessURL(videoURL) {
                DispatchQueue.main.async {
                    isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "无法访问视频文件，请检查网络连接或文件路径。"
                }
            }
        }
    }
    
    private func canAccessURL(_ url: URL) -> Bool {
        // 对于本地文件
        if url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path)
        }
        
        // 对于网络URL，进行简单的可达性检查
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAccessible = false
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                isAccessible = httpResponse.statusCode < 400
            } else {
                isAccessible = error == nil
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return isAccessible
    }
}

// MARK: - 工厂方法

@available(tvOS 17.0, *)
extension VLCPlayerContainer {
    
    /// 为WebDAV创建播放器容器
    static func forWebDAV(
        item: WebDAVItem,
        streamingURL: URL,
        subtitleFiles: [WebDAVItem] = [],
        onDismiss: @escaping () -> Void
    ) -> VLCPlayerContainer {
        
        // 寻找字幕文件
        let subtitleURL = findBestSubtitleURL(for: item.name, in: subtitleFiles)
        
        return VLCPlayerContainer(
            videoURL: streamingURL,
            originalFileName: item.name,
            subtitleURL: subtitleURL,
            onDismiss: onDismiss
        )
    }
    
    /// 为Jellyfin创建播放器容器
    static func forJellyfin(
        item: JellyfinMediaItem,
        client: JellyfinClient,
        onDismiss: @escaping () -> Void
    ) -> VLCPlayerContainer {
        
        guard let playbackURL = client.getPlaybackUrl(itemId: item.id) else {
            // 如果无法获取播放URL，返回带错误的容器
            return VLCPlayerContainer(
                videoURL: URL(string: "about:blank")!,
                originalFileName: item.name,
                subtitleURL: nil,
                onDismiss: onDismiss
            )
        }
        
        return VLCPlayerContainer(
            videoURL: playbackURL,
            originalFileName: item.name,
            subtitleURL: nil, // Jellyfin的字幕通常是内嵌的
            onDismiss: onDismiss
        )
    }
    
    /// 为本地文件创建播放器容器
    static func forLocalFile(
        url: URL,
        subtitleURL: URL? = nil,
        onDismiss: @escaping () -> Void
    ) -> VLCPlayerContainer {
        
        return VLCPlayerContainer(
            videoURL: url,
            originalFileName: url.lastPathComponent,
            subtitleURL: subtitleURL,
            onDismiss: onDismiss
        )
    }
    
    // MARK: - 辅助方法
    
    private static func findBestSubtitleURL(for videoName: String, in subtitleFiles: [WebDAVItem]) -> URL? {
        let videoBaseName = videoName.components(separatedBy: ".").first ?? videoName
        
        // 查找匹配的字幕文件
        let matchingSubtitles = subtitleFiles.filter { subtitle in
            let subtitleBaseName = subtitle.name.components(separatedBy: ".").first ?? subtitle.name
            return subtitleBaseName.contains(videoBaseName) || videoBaseName.contains(subtitleBaseName)
        }
        
        // 优先选择中文字幕
        for subtitle in matchingSubtitles {
            let fileName = subtitle.name.lowercased()
            if fileName.contains("zh") || fileName.contains("chinese") || fileName.contains("中文") {
                return URL(string: subtitle.path) // 这里需要根据实际的WebDAV路径构造方式调整
            }
        }
        
        // 如果没有中文字幕，返回第一个匹配的字幕
        return matchingSubtitles.first.map { URL(string: $0.path) } ?? nil
    }
}

// MARK: - 辅助视图

@available(tvOS 17.0, *)
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

@available(tvOS 17.0, *)
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("播放错误")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            HStack(spacing: 30) {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(.blue)
                
                Button("返回") {
                    onDismiss()
                }
                .buttonStyle(BorderedButtonStyle())
                .tint(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - 预览

#if DEBUG
@available(tvOS 17.0, *)
struct VLCPlayerContainer_Previews: PreviewProvider {
    static var previews: some View {
        VLCPlayerContainer(
            videoURL: URL(string: "https://example.com/video.mp4")!,
            originalFileName: "示例视频.mp4",
            subtitleURL: nil,
            onDismiss: {}
        )
    }
}
#endif
