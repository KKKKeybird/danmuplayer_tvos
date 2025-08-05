/// 媒体库视图模型
import Foundation

/// 媒体库数据模型
@MainActor
@available(tvOS 17.0, *)
class MediaLibraryViewModel: ObservableObject {
    @Published var mediaLibraries: [MediaLibrary] = []
    @Published var connectionStatus: [UUID: Bool] = [:]
    let configManager = MediaLibraryConfigManager()
    
    init() {
        refreshLibraries()
    }
    
    /// 刷新媒体库列表
    func refreshLibraries() {
        let configs = configManager.configs
        mediaLibraries = configs.map { config in
            let credentials: Credentials?
            if let username = config.username, let password = config.password {
                credentials = Credentials(username: username, password: password)
            } else {
                credentials = nil
            }
            
            let client = WebDAVClient(
                baseURL: URL(string: config.baseURL)!,
                credentials: credentials
            )
            
            return MediaLibrary(
                id: config.id,
                name: config.name,
                config: config,
                webDAVClient: client
            )
        }
    }
    
    /// 删除媒体库
    func removeLibrary(withId id: UUID) {
        configManager.removeConfig(withId: id)
        refreshLibraries()
        connectionStatus.removeValue(forKey: id)
    }
    
    /// 测试所有媒体库连接
    func testAllConnections() {
        connectionStatus.removeAll()
        
        for library in mediaLibraries {
            testConnection(for: library.id)
        }
    }
    
    /// 测试特定媒体库的连接
    func testConnection(for libraryId: UUID) {
        guard let library = mediaLibraries.first(where: { $0.id == libraryId }) else {
            return
        }
        
        // 标记为测试中
        connectionStatus.removeValue(forKey: libraryId)
        
        library.webDAVClient.testConnection { result in
            Task { @MainActor in
                switch result {
                case .success:
                    self.connectionStatus[libraryId] = true
                case .failure:
                    self.connectionStatus[libraryId] = false
                }
            }
        }
    }
}

struct MediaLibrary: Identifiable {
    let id: UUID
    let name: String
    let config: MediaLibraryConfig
    let webDAVClient: WebDAVClient
}
