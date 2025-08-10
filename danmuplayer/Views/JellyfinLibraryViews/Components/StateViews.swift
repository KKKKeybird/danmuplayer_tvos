/// 通用状态视图组件
import SwiftUI

/// Jellyfin认证状态视图
@available(tvOS 17.0, *)
struct JellyfinAuthenticationView: View {
    let isLoading: Bool
    let errorMessage: String?
    let isPerformingDetailedTest: Bool
    let connectionTestResults: [String]
    let onAuthenticate: () -> Void
    let onPerformDetailedTest: () async -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Text("连接到Jellyfin服务器")
                .font(.title2)
            
            if isLoading {
                ProgressView("正在连接...")
            } else {
                // 只有在有错误时才显示重试和诊断按钮
                if errorMessage != nil {
                    VStack(spacing: 20) {
                        Button("重新连接") {
                            onAuthenticate()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        // 连接诊断按钮
                        Button("连接诊断") {
                            Task {
                                await onPerformDetailedTest()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingDetailedTest)
                        
                        if isPerformingDetailedTest {
                            ProgressView("正在执行诊断测试...")
                                .padding(.top)
                        }
                        
                        // 显示诊断结果
                        if !connectionTestResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("诊断结果:")
                                    .font(.headline)
                                    .padding(.top)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(connectionTestResults, id: \.self) { result in
                                            Text(result)
                                                .font(.caption)
                                                .foregroundColor(result.contains("✅") ? .green : .red)
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
}

#Preview {
    JellyfinAuthenticationView(
        isLoading: false,
        errorMessage: "连接失败",
        isPerformingDetailedTest: false,
        connectionTestResults: ["✅ 服务器连接成功", "❌ 用户认证失败"],
        onAuthenticate: {},
        onPerformDetailedTest: {}
    )
}

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
