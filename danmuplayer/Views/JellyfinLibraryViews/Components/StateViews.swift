/// 通用状态视图组件
import SwiftUI

/// 加载状态视图
@available(tvOS 17.0, *)
struct LoadingStateView: View {
    let message: String
    let showLargeSpinner: Bool
    
    init(message: String = "加载中...", showLargeSpinner: Bool = true) {
        self.message = message
        self.showLargeSpinner = showLargeSpinner
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(showLargeSpinner ? 2 : 1)
            Text(message)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 错误状态视图
@available(tvOS 17.0, *)
struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    let iconName: String
    let iconColor: Color
    
    init(
        title: String = "加载失败",
        message: String,
        iconName: String = "exclamationmark.triangle",
        iconColor: Color = .red,
        retryAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.iconColor = iconColor
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                retryAction()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 空状态视图
@available(tvOS 17.0, *)
struct EmptyStateView: View {
    let title: String
    let message: String
    let iconName: String
    let iconColor: Color
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        iconName: String,
        iconColor: Color = .gray,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.iconColor = iconColor
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Loading State") {
    LoadingStateView(message: "正在连接...")
}

#Preview("Error State") {
    ErrorStateView(
        message: "网络连接失败，请检查网络设置后重试",
        retryAction: {}
    )
}

#Preview("Empty State") {
    EmptyStateView(
        title: "没有找到内容",
        message: "此目录中没有文件或文件夹",
        iconName: "folder",
        actionTitle: "刷新",
        action: {}
    )
}
