/// 统一的视频播放器容器 - 重定向到新的MVVM架构
import SwiftUI

/// 统一的视频播放器容器，支持WebDAV和Jellyfin数据源，使用SwiftfinStyle UI
/// 注意：此文件将被废弃，建议使用新的WebDAVPlayerContainer
@available(tvOS 17.0, *)
struct UnifiedVideoPlayerContainer: View {
    let videoItem: WebDAVItem
    let subtitleFiles: [WebDAVItem]
    let webDAVClient: WebDAVClient
    
    var body: some View {
        // 使用新的MVVM架构容器
        WebDAVPlayerContainer(
            videoItem: videoItem,
            subtitleFiles: subtitleFiles,
            webDAVClient: webDAVClient
        )
    }
}

// MARK: - VideoPlayerContainer别名，保持向后兼容

@available(tvOS 17.0, *)
typealias VideoPlayerContainer = UnifiedVideoPlayerContainer

// MARK: - 旧的状态视图组件（已废弃，使用PlayerViews.swift中的新版本）

/// 统一的加载视图（废弃）
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

/// 统一的错误视图（废弃）
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
