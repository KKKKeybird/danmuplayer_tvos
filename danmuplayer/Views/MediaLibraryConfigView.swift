/// 添加/编辑媒体库配置视图
import SwiftUI

/// 用于添加或编辑媒体库配置的表单视图
@available(tvOS 17.0, *)
struct MediaLibraryConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var configManager: MediaLibraryConfigManager
    
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    
    let editingConfig: MediaLibraryConfig?
    
    init(configManager: MediaLibraryConfigManager, editingConfig: MediaLibraryConfig? = nil) {
        self.configManager = configManager
        self.editingConfig = editingConfig
        
        if let config = editingConfig {
            _name = State(initialValue: config.name)
            _baseURL = State(initialValue: config.baseURL)
            _username = State(initialValue: config.username ?? "")
            _password = State(initialValue: config.password ?? "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("媒体库名称", text: $name)
                    TextField("WebDAV地址", text: $baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("认证信息（可选）")) {
                    TextField("用户名", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("密码", text: $password)
                }
                
                Section(header: Text("连接测试")) {
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTestingConnection ? "测试中..." : "测试连接")
                        }
                    }
                    .disabled(isTestingConnection || baseURL.isEmpty)
                    
                    if let result = connectionTestResult {
                        Text(result)
                            .foregroundStyle(result.contains("成功") ? .green : .red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: saveConfig) {
                        Text(editingConfig == nil ? "添加媒体库" : "保存更改")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle(editingConfig == nil ? "添加媒体库" : "编辑媒体库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func saveConfig() {
        // 验证输入
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("请输入媒体库名称")
            return
        }
        
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("请输入WebDAV地址")
            return
        }
        
        guard URL(string: baseURL) != nil else {
            showError("WebDAV地址格式不正确")
            return
        }
        
        // 创建配置对象
        let config = MediaLibraryConfig(
            id: editingConfig?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )
        
        // 保存配置
        if editingConfig == nil {
            configManager.addConfig(config)
        } else {
            configManager.updateConfig(config)
        }
        
        dismiss()
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func testConnection() {
        guard !baseURL.isEmpty else {
            showError("请先输入WebDAV地址")
            return
        }
        
        guard let url = URL(string: baseURL) else {
            showError("WebDAV地址格式不正确")
            return
        }
        
        isTestingConnection = true
        connectionTestResult = nil
        
        let credentials: Credentials?
        if !username.isEmpty && !password.isEmpty {
            credentials = Credentials(username: username, password: password)
        } else {
            credentials = nil
        }
        
        let client = WebDAVClient(baseURL: url, credentials: credentials)
        
        client.testConnection { result in
            Task { @MainActor in
                isTestingConnection = false
                
                switch result {
                case .success:
                    connectionTestResult = "连接成功"
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        connectionTestResult = "\(networkError.localizedDescription)"
                    } else {
                        connectionTestResult = "连接失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
