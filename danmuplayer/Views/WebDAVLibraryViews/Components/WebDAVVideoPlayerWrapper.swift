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
            print("WebDAV: WebDAVVideoPlayerWrapper 出现，开始设置播放器")
            print("WebDAV: 视频文件: \(videoItem.name)")
            setupPlayerContainer()
        }
    }
    
    private func setupPlayerContainer() {
        print("WebDAV: 开始准备媒体播放")
        viewModel.prepareMediaForPlayback(item: videoItem) { playbackURL, subtitleURLs in
            print("WebDAV: 媒体准备完成 - URL: \(playbackURL)")
            DispatchQueue.main.async {
                if playbackURL.absoluteString.isEmpty {
                    print("WebDAV: 错误 - 无法获取视频流")
                    self.errorMessage = "无法获取视频流"
                    self.isLoading = false
                    return
                }
                print("WebDAV: 创建 VLCPlayerContainer")
                let fileName = videoItem.name.applyingTransform(.traditionalToSimplifiedChinese, reverse: false) ?? videoItem.name
                let container = VLCPlayerContainer.create(
                    videoURL: playbackURL,
                    originalFileName: fileName,
                    subtitleURLs: subtitleURLs,
                    onDismiss: {
                        print("WebDAV: 播放器请求关闭")
                        dismiss()
                    }
                )
                self.playerContainer = container
                self.isLoading = false
                print("WebDAV: 播放器容器创建完成")
            }
        }
    }
    
    static func isVideoFile(_ filename: String) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm"]
        let ext = (filename as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
    
    static func getFileIcon(for filename: String) -> String {
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
    
    static func getFileColor(for filename: String) -> Color {
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
