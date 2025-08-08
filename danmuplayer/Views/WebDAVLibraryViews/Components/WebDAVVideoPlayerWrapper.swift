import SwiftUI

// MARK: - VLC播放器容器包装器
@available(tvOS 17.0, *)
struct WebDAVVideoPlayerWrapper: View {
    let videoItem: WebDAVItem
    let viewModel: FileBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var playerContainer: VLCPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("准备播放器...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("播放错误")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Button("返回") {
                        dismiss()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let container = playerContainer {
                container
            }
        }
        .onAppear {
            setupPlayerContainer()
        }
    }
    
    private func setupPlayerContainer() {
        // 获取流媒体URL和字幕文件
        viewModel.getVideoStreamingURL(for: videoItem) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let streamingURL):
                    // 查找字幕文件
                    let subtitleFiles = viewModel.findSubtitleFiles(for: videoItem)
                    
                    // 创建VLC播放器容器
                    let container = VLCPlayerContainer.create(
                        videoURL: streamingURL,
                        originalFileName: videoItem.name,
                        subtitleURL: subtitleFiles.first,
                        onDismiss: {
                            dismiss()
                        }
                    )
                    
                    self.playerContainer = container
                    self.isLoading = false
                    
                case .failure(let error):
                    self.errorMessage = "无法获取视频流: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }    private func playVideo(item: WebDAVItem) {
        selectedVideoItem = item
        showingVideoPlayer = true
    }
    
    private func isVideoFile(_ filename: String) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm"]
        let ext = (filename as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
    
    private func getFileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm":
            return "play.rectangle.fill"
        case "srt", "ass", "ssa", "vtt":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp":
            return "photo.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func getFileColor(for filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm":
            return .blue
        case "srt", "ass", "ssa", "vtt":
            return .green
        case "jpg", "jpeg", "png", "gif", "bmp":
            return .orange
        case "zip", "rar", "7z":
            return .purple
        default:
            return .gray
        }
    }
}
