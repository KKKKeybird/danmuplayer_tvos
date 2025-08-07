/// WebDAV通用状态视图组件
import SwiftUI

/// WebDAV加载状态视图
@available(tvOS 17.0, *)
struct WebDAVLoadingView: View {
    let message: String
    
    init(message: String = "加载中...") {
        self.message = message
    }
    
    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// WebDAV错误状态视图
@available(tvOS 17.0, *)
struct WebDAVErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("加载失败")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                retryAction()
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// WebDAV空目录视图
@available(tvOS 17.0, *)
struct WebDAVEmptyView: View {
    let refreshAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.gray)
            Text("目录为空")
                .font(.headline)
            Text("此目录中没有文件或文件夹")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("刷新") {
                refreshAction()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("WebDAV Loading") {
    WebDAVLoadingView()
}

#Preview("WebDAV Error") {
    WebDAVErrorView(
        message: "网络连接失败，请检查网络设置后重试",
        retryAction: {}
    )
}

#Preview("WebDAV Empty") {
    WebDAVEmptyView(refreshAction: {})
}
