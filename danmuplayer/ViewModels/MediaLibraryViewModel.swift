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
    
    // MARK: - 刷新媒体库列表
    func refreshLibraries() {
        let configs = configManager.configs
        mediaLibraries = configs.map { config in
            return MediaLibrary(
                id: config.id,
                name: config.name,
                config: config
            )
        }
    }
    
    // MARK: - 删除媒体库
    func removeLibrary(withId id: UUID) {
        configManager.removeConfig(withId: id)
        refreshLibraries()
        connectionStatus.removeValue(forKey: id)
    }
    
    // MARK: - 测试所有媒体库连接
    func testAllConnections() {
        connectionStatus.removeAll()
        
        for library in mediaLibraries {
            testConnection(for: library.id)
        }
    }
    
    // MARK: - 测试特定媒体库的连接
    func testConnection(for libraryId: UUID) {
        guard let library = mediaLibraries.first(where: { $0.id == libraryId }) else {
            return
        }
        
        // 标记为测试中
        connectionStatus.removeValue(forKey: libraryId)
        
        Task {
            let isConnected = await testLibraryConnection(library)
            await MainActor.run {
                self.connectionStatus[libraryId] = isConnected
            }
        }
    }
    
    /// 异步测试媒体库连接
    private func testLibraryConnection(_ library: MediaLibrary) async -> Bool {
        switch library.config.serverType {
        case .webdav:
            return await testWebDAVConnection(library)
        case .jellyfin:
            return await testJellyfinConnection(library)
        }
    }
    
    /// 测试WebDAV连接
    private func testWebDAVConnection(_ library: MediaLibrary) async -> Bool {
        guard let webDAVClient = library.config.createWebDAVClient() else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            webDAVClient.testConnection { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// 测试Jellyfin连接
    private func testJellyfinConnection(_ library: MediaLibrary) async -> Bool {
        guard let jellyfinClient = library.config.createJellyfinClient() else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            jellyfinClient.authenticate { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

struct MediaLibrary: Identifiable {
    let id: UUID
    let name: String
    let config: MediaLibraryConfig
    
    /// 获取服务器类型的显示名称
    var serverTypeDisplayName: String {
        switch config.serverType {
        case .webdav:
            return "WebDAV"
        case .jellyfin:
            return "Jellyfin"
        }
    }
}
