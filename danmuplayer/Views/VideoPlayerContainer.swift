/// 视频播放器容�?
import SwiftUI

/// 视频播放器容器，负责初始化播放器和获取流媒体URL
@available(tvOS 17.0, *)
struct VideoPlayerContainer: View {
    let videoItem: WebDAVItem
    let subtitleFiles: [WebDAVItem]
    let webDAVClient: WebDAVClient
    
    @State private var videoURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(2)
                    Text("正在获取视频链接...")
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.9))
            } else if let videoURL = videoURL {
                VLCVideoPlayerView(
                    viewModel: {
                        let viewModel = VideoPlayerViewModel(
                            videoURL: videoURL,
                            subtitleFiles: subtitleFiles
                        )
                        viewModel.dismiss = { dismiss() }
                        return viewModel
                    }()
                )
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("无法加载视频")
                        .font(.headline)
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button("返回") {
                        dismiss()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.9))
            }
        }
        .onAppear {
            loadVideoURL()
        }
    }
    
    private func loadVideoURL() {
        webDAVClient.getStreamingURL(for: videoItem.path) { result in
            Task { @MainActor in
                isLoading = false
                switch result {
                case .success(let url):
                    videoURL = url
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        errorMessage = networkError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
