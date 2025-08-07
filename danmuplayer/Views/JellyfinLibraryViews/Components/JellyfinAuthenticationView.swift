/// Jellyfin认证状态视图组件
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
