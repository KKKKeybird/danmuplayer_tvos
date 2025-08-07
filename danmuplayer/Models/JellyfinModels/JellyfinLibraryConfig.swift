/// Jellyfin媒体库显示配置
import Foundation

/// 媒体库选择配置
struct JellyfinLibraryConfig: Codable, Equatable {
    let serverId: String // 服务器标识
    var selectedLibraryIds: Set<String> // 选择显示的媒体库ID列表
    let lastUpdated: Date
    
    init(serverId: String, selectedLibraryIds: Set<String>) {
        self.serverId = serverId
        self.selectedLibraryIds = selectedLibraryIds
        self.lastUpdated = Date()
    }
    
    /// 检查是否应该显示指定的媒体库
    func shouldShowLibrary(id: String) -> Bool {
        return selectedLibraryIds.contains(id)
    }
    
    /// 获取选择的媒体库数量
    var selectedCount: Int {
        return selectedLibraryIds.count
    }
    
    /// 添加媒体库到选择列表
    mutating func addLibrary(id: String) {
        selectedLibraryIds.insert(id)
    }
    
    /// 从选择列表移除媒体库
    mutating func removeLibrary(id: String) {
        selectedLibraryIds.remove(id)
    }
    
    /// 切换媒体库的选择状态
    mutating func toggleLibrary(id: String) {
        if selectedLibraryIds.contains(id) {
            selectedLibraryIds.remove(id)
        } else {
            selectedLibraryIds.insert(id)
        }
    }
}

/// 媒体库配置管理器
class JellyfinLibraryConfigManager: ObservableObject {
    static let shared = JellyfinLibraryConfigManager()
    
    @Published var configs: [String: JellyfinLibraryConfig] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let configsKey = "JellyfinLibraryConfigs"
    
    private init() {
        loadConfigs()
    }
    
    /// 获取指定服务器的配置
    func getConfig(for serverId: String) -> JellyfinLibraryConfig? {
        return configs[serverId]
    }
    
    /// 保存指定服务器的配置
    func saveConfig(_ config: JellyfinLibraryConfig, for serverId: String) {
        configs[serverId] = config
        saveConfigs()
    }
    
    /// 更新服务器的媒体库选择
    func updateSelectedLibraries(for serverId: String, selectedIds: Set<String>) {
        let config = JellyfinLibraryConfig(serverId: serverId, selectedLibraryIds: selectedIds)
        saveConfig(config, for: serverId)
    }
    
    /// 获取选择的媒体库ID列表
    func getSelectedLibraryIds(for serverId: String) -> Set<String> {
        return configs[serverId]?.selectedLibraryIds ?? []
    }
    
    /// 检查是否应该显示指定的媒体库
    func shouldShowLibrary(id: String, for serverId: String) -> Bool {
        guard let config = configs[serverId] else {
            // 如果没有配置，默认显示所有媒体库
            return true
        }
        return config.shouldShowLibrary(id: id)
    }
    
    /// 过滤媒体库列表，只返回选择显示的媒体库
    func filterLibraries(_ libraries: [JellyfinLibrary], for serverId: String) -> [JellyfinLibrary] {
        guard let config = configs[serverId] else {
            // 如果没有配置，返回所有媒体库
            return libraries
        }
        
        // 如果没有选择任何媒体库，也返回所有媒体库
        if config.selectedLibraryIds.isEmpty {
            return libraries
        }
        
        return libraries.filter { library in
            config.shouldShowLibrary(id: library.id)
        }
    }
    
    /// 获取合并后的媒体库项目
    func getMergedLibraryItems(
        from client: JellyfinClient,
        serverId: String,
        availableLibraries: [JellyfinLibrary],
        completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void
    ) {
        let selectedLibraries = filterLibraries(availableLibraries, for: serverId)
        
        guard !selectedLibraries.isEmpty else {
            completion(.success([]))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var allItems: [JellyfinMediaItem] = []
        var hasError = false
        var lastError: Error?
        
        for library in selectedLibraries {
            dispatchGroup.enter()
            
            client.getLibraryItems(libraryId: library.id) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let items):
                    DispatchQueue.main.async {
                        allItems.append(contentsOf: items)
                    }
                case .failure(let error):
                    print("获取媒体库 \(library.name) 的项目失败: \(error)")
                    hasError = true
                    lastError = error
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if hasError && allItems.isEmpty {
                completion(.failure(lastError ?? NetworkError.unknown))
            } else {
                // 按名称排序合并后的项目
                let sortedItems = allItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                completion(.success(sortedItems))
            }
        }
    }
    
    // MARK: - 持久化
    
    private func loadConfigs() {
        guard let data = userDefaults.data(forKey: configsKey) else {
            print("JellyfinLibraryConfigManager: No saved configs found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedConfigs = try decoder.decode([String: JellyfinLibraryConfig].self, from: data)
            self.configs = decodedConfigs
            print("JellyfinLibraryConfigManager: Loaded \(decodedConfigs.count) configs")
        } catch {
            print("JellyfinLibraryConfigManager: Failed to load configs: \(error)")
        }
    }
    
    private func saveConfigs() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(configs)
            userDefaults.set(data, forKey: configsKey)
            print("JellyfinLibraryConfigManager: Saved \(configs.count) configs")
        } catch {
            print("JellyfinLibraryConfigManager: Failed to save configs: \(error)")
        }
    }
    
    /// 清除所有配置（用于测试或重置）
    func clearAllConfigs() {
        configs.removeAll()
        userDefaults.removeObject(forKey: configsKey)
        print("JellyfinLibraryConfigManager: Cleared all configs")
    }
}
