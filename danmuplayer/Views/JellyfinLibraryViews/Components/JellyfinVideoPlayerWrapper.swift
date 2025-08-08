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
        
        // 使用ViewModel的播放器容器创建方法
        DispatchQueue.main.async {
            if let container = viewModel.createVideoPlayerContainer(for: item, onDismiss: onDismiss) {
                self.playerContainer = container
                self.isLoading = false
            } else {
                self.errorMessage = "无法创建播放器：播放URL不可用或网络连接问题"
                self.isLoading = false
            }
        }
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
