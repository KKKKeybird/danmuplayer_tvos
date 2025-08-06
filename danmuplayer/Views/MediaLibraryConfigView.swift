/// 添加/编辑媒体库配置视图
import SwiftUI

/// 用于添加或编辑媒体库配置的表单视图
@available(tvOS 17.0, *)
struct MediaLibraryConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var configManager: MediaLibraryConfigManager
    
    @State private var serverType: MediaLibraryServerType = .webdav
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
            _serverType = State(initialValue: config.serverType)
            _name = State(initialValue: config.name)
            _baseURL = State(initialValue: config.baseURL)
            _username = State(initialValue: config.username ?? "")
            _password = State(initialValue: config.password ?? "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器类型")) {
                    Picker("服务器类型", selection: $serverType) {
                        Text("WebDAV").tag(MediaLibraryServerType.webdav)
                        Text("Jellyfin").tag(MediaLibraryServerType.jellyfin)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("基本信息")) {
                    TextField("媒体库名称", text: $name)
                    TextField(serverType == .webdav ? "WebDAV地址" : "Jellyfin服务器地址", text: $baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if serverType == .webdav {
                        Text("示例: http://192.168.1.100:8080/dav 或 https://cloud.example.com/webdav")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("示例: http://192.168.1.100:8096 或 https://jellyfin.example.com")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(serverType == .webdav ? "认证信息（可选）" : "登录信息")) {
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
            showError("请输入\(serverType == .webdav ? "WebDAV" : "Jellyfin服务器")地址")
            return
        }
        
        guard URL(string: baseURL) != nil else {
            showError("\(serverType == .webdav ? "WebDAV" : "Jellyfin服务器")地址格式不正确")
            return
        }
        
        // 创建配置对象
        let config = MediaLibraryConfig(
            id: editingConfig?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            serverType: serverType
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
            showError("请先输入\(serverType == .webdav ? "WebDAV" : "Jellyfin服务器")地址")
            return
        }
        
        guard let url = URL(string: baseURL) else {
            showError("\(serverType == .webdav ? "WebDAV" : "Jellyfin服务器")地址格式不正确")
            return
        }
        
        isTestingConnection = true
        connectionTestResult = nil
        
        if serverType == .webdav {
            testWebDAVConnection(url: url)
        } else {
            testJellyfinConnection(url: url)
        }
    }
    
    private func testWebDAVConnection(url: URL) {
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
    
    private func testJellyfinConnection(url: URL) {
        let client = JellyfinClient(baseURL: url)
        
        Task {
            do {
                let authResult = try await client.authenticate(username: username, password: password)
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = "连接成功，已验证用户：\(authResult.user.name)"
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
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
