/// Jellyfin视频播放器包装组件
import SwiftUI

/// Jellyfin视频播放器包装器，负责创建和管理播放器容器
@available(tvOS 17.0, *)
struct JellyfinVideoPlayerWrapper: View {
    let item: JellyfinMediaItem
    let viewModel: JellyfinMediaLibraryViewModel
    let onDismiss: () -> Void
    
    @State private var playerContainer: VLCPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "准备播放器...")
            } else if let errorMessage = errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: {
                        setupPlayerContainer()
                    },
                    onDismiss: onDismiss
                )
            } else if let container = playerContainer {
                container
            }
        }
        .onAppear {
            setupPlayerContainer()
        }
    }
    
    private func setupPlayerContainer() {
        isLoading = true
        errorMessage = nil
        
        // 使用ViewModel预处理媒体和字幕，然后使用统一的创建方法
        viewModel.prepareMediaForPlayback(item: item) { playbackURL, subtitleURLs in
            DispatchQueue.main.async {
                // 生成更合适的文件名用于弹幕匹配
                let fileName = self.generateFileName()
                
                // 使用VLCPlayerContainer的统一创建方法
                let container = VLCPlayerContainer.create(
                    videoURL: playbackURL,
                    originalFileName: fileName,
                    subtitleURLs: subtitleURLs,
                    onDismiss: self.onDismiss
                )
                self.playerContainer = container
                self.isLoading = false
            }
        }
    }
    
    /// 生成用于弹幕匹配的文件名
    private func generateFileName() -> String {
        // 如果是电影，直接使用电影名称
        if item.type == "Movie" {
            return item.name
        }
        
        // 如果是剧集，组合系列名、季数和集数
        var fileName = item.name
        
        // 添加系列名
        if let seriesName = item.seriesName, !seriesName.isEmpty {
            fileName = "\(seriesName) - \(fileName)"
        }
        
        // 添加季数和集数信息
        if let seasonNumber = item.parentIndexNumber, let episodeNumber = item.indexNumber {
            fileName = "\(fileName) S\(String(format: "%02d", seasonNumber))E\(String(format: "%02d", episodeNumber))"
        } else if let episodeNumber = item.indexNumber {
            fileName = "\(fileName) E\(String(format: "%02d", episodeNumber))"
        }
        
        return fileName
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
