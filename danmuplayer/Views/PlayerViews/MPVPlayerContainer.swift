/// MPV播放器容器 - 视频播放生成容器
import SwiftUI
import MPVKit

@available(tvOS 17.0, *)
struct MPVPlayerContainer: View {
    // MARK: - 输入参数
    let videoURL: URL
    let originalFileName: String
    let subtitleURLs: [URL]
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
                MPVPlayerView(
                    videoURL: videoURL,
                    originalFileName: originalFileName,
                    subtitleURLs: subtitleURLs,
                    onDismiss: onDismiss
                )
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            if self.canAccessURL(self.videoURL) {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "无法访问视频文件，请检查网络连接或文件路径。"
                }
            }
        }
    }
    
    private func canAccessURL(_ url: URL) -> Bool {
        if url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return true
    }
}

// MARK: - 辅助视图
@available(tvOS 17.0, *)
private struct LoadingView: View {
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
private struct ErrorView: View {
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

// MARK: - 创建方法
@available(tvOS 17.0, *)
extension MPVPlayerContainer {
    static func create(
        videoURL: URL,
        originalFileName: String,
        subtitleURLs: [URL] = [],
        onDismiss: @escaping () -> Void
    ) -> MPVPlayerContainer {
        return MPVPlayerContainer(
            videoURL: videoURL,
            originalFileName: originalFileName,
            subtitleURLs: subtitleURLs,
            onDismiss: onDismiss
        )
    }
}
