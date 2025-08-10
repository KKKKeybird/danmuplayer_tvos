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
    @State private var showLibrarySelection = false
    @State private var availableLibraries: [JellyfinLibrary] = []
    @State private var selectedLibraryIds: Set<String> = []
    @State private var authenticatedClient: JellyfinClient?
    
    let editingConfig: MediaLibraryConfig?
    
    init(configManager: MediaLibraryConfigManager, editingConfig: MediaLibraryConfig? = nil) {
        self.configManager = configManager
        self.editingConfig = editingConfig
        
        if let config = editingConfig {
            _serverType = State(initialValue: config.serverType)
            _name = State(initialValue: config.name)
            _baseURL = State(initialValue: config.serverURL)
            _username = State(initialValue: config.username ?? "")
            _password = State(initialValue: config.password ?? "")
            
            // 如果是编辑 Jellyfin 配置，加载媒体库选择
            if config.serverType == .jellyfin {
                let libraryConfig = JellyfinLibraryConfigManager.shared.getConfig(for: config.serverURL)
                _selectedLibraryIds = State(initialValue: libraryConfig?.selectedLibraryIds ?? [])
            }
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
                    .disabled(serverType == .jellyfin && selectedLibraryIds.isEmpty && editingConfig == nil)
                    
                    // Jellyfin 媒体库选择状态显示
                    if serverType == .jellyfin && !selectedLibraryIds.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已选择 \(selectedLibraryIds.count) 个媒体库")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("重新选择媒体库") {
                                showLibrarySelection = true
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
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
            .sheet(isPresented: $showLibrarySelection) {
                if let client = authenticatedClient {
                    JellyfinLibrarySelectionSheet(
                        client: client,
                        serverId: baseURL,
                        availableLibraries: availableLibraries,
                        selectedLibraryIds: $selectedLibraryIds,
                        onSave: { selectedIds in
                            selectedLibraryIds = selectedIds
                            showLibrarySelection = false
                        }
                    )
                }
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
            serverURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            serverType: serverType,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )
        
        // 保存配置
        if editingConfig == nil {
            configManager.addConfig(config)
            
            // 如果是 Jellyfin 服务器，同时保存媒体库选择配置
            if serverType == .jellyfin && !selectedLibraryIds.isEmpty {
                JellyfinLibraryConfigManager.shared.updateSelectedLibraries(
                    for: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    selectedIds: selectedLibraryIds
                )
            }
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
        let client = JellyfinClient(serverURL: url, username: username, password: password)
        
        Task {
            await MainActor.run {
                isTestingConnection = true
                connectionTestResult = nil
            }
            
            // 第一步：测试连接和认证
            let authResult = await withCheckedContinuation { continuation in
                client.authenticate { result in
                    switch result {
                    case .success(let user):
                        continuation.resume(returning: (true, user.name, nil as Error?))
                    case .failure(let error):
                        continuation.resume(returning: (false, "", error))
                    }
                }
            }
            
            if !authResult.0 {
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = "认证失败，请检查用户名和密码"
                }
                return
            }
            
            // 第二步：获取媒体库列表
            let librariesResult = await withCheckedContinuation { continuation in
                client.getLibraries { result in
                    switch result {
                    case .success(let libraries):
                        continuation.resume(returning: (true, libraries))
                    case .failure(_):
                        continuation.resume(returning: (false, []))
                    }
                }
            }
            
            await MainActor.run {
                isTestingConnection = false
                
                if librariesResult.0 {
                    let mediaLibraries = librariesResult.1.filter { library in
                        library.collectionType == "movies" || library.collectionType == "tvshows" || library.collectionType == nil
                    }
                    
                    if mediaLibraries.isEmpty {
                        connectionTestResult = "连接成功，但未找到电影或电视剧媒体库"
                    } else {
                        connectionTestResult = "连接成功，找到 \(mediaLibraries.count) 个媒体库，请选择要显示的媒体库"
                        availableLibraries = mediaLibraries
                        authenticatedClient = client
                        
                        // 默认选择所有媒体库
                        selectedLibraryIds = Set(mediaLibraries.map { $0.id })
                        
                        // 自动显示媒体库选择界面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showLibrarySelection = true
                        }
                    }
                } else {
                    connectionTestResult = "认证成功，但无法获取媒体库列表"
                }
            }
        }
    }
}

/// 简化的媒体库选择Sheet组件
struct JellyfinLibrarySelectionSheet: View {
    let client: JellyfinClient
    let serverId: String
    let availableLibraries: [JellyfinLibrary]
    @Binding var selectedLibraryIds: Set<String>
    let onSave: (Set<String>) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var localSelectedIds: Set<String>
    
    init(client: JellyfinClient, serverId: String, availableLibraries: [JellyfinLibrary], selectedLibraryIds: Binding<Set<String>>, onSave: @escaping (Set<String>) -> Void) {
        self.client = client
        self.serverId = serverId
        self.availableLibraries = availableLibraries
        self._selectedLibraryIds = selectedLibraryIds
        self.onSave = onSave
        self._localSelectedIds = State(initialValue: selectedLibraryIds.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 说明文字
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择要显示的媒体库")
                        .font(.headline)
                    
                    Text("选择的媒体库将合并显示在一个列表中，方便浏览所有内容。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("已选择: \(localSelectedIds.count) / \(availableLibraries.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let isAllSelected = localSelectedIds.count == availableLibraries.count
                        Button(isAllSelected ? "取消全选" : "全选") {
                            if isAllSelected {
                                localSelectedIds.removeAll()
                            } else {
                                localSelectedIds = Set(availableLibraries.map { $0.id })
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                
                // 媒体库列表
                List {
                    ForEach(availableLibraries, id: \.id) { library in
                        Button {
                            if localSelectedIds.contains(library.id) {
                                localSelectedIds.remove(library.id)
                            } else {
                                localSelectedIds.insert(library.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                let isSelected = localSelectedIds.contains(library.id)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(library.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    if let type = library.collectionType {
                                        Text(type.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("媒体库选择")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onSave(localSelectedIds)
                    }
                    .disabled(localSelectedIds.isEmpty)
                }
            }
        }
    }
}
