import Foundation
import Combine

/// 媒体库排序配置存储器 - 为每个媒体库持久化存储排序设置
class MediaLibrarySortStore: ObservableObject {
    static let shared = MediaLibrarySortStore()
    
    // Jellyfin 排序配置
    @Published var jellyfinSortConfigs: [String: JellyfinSortConfig] = [:] {
        didSet {
            saveJellyfinConfigs()
        }
    }
    
    // WebDAV 排序配置
    @Published var webDAVSortConfigs: [String: WebDAVSortConfig] = [:] {
        didSet {
            saveWebDAVConfigs()
        }
    }
    
    private init() {
        loadConfigs()
    }
    
    // MARK: - Jellyfin 排序配置
    
    struct JellyfinSortConfig: Codable {
        var sortOption: String // 使用 rawValue 存储
        var isAscending: Bool
        
        init(sortOption: String = "最近观看", isAscending: Bool = true) {
            self.sortOption = sortOption
            self.isAscending = isAscending
        }
    }
    
    func getJellyfinSortConfig(for libraryId: String) -> JellyfinSortConfig {
        return jellyfinSortConfigs[libraryId] ?? JellyfinSortConfig()
    }
    
    func setJellyfinSortConfig(for libraryId: String, sortOption: String, isAscending: Bool) {
        jellyfinSortConfigs[libraryId] = JellyfinSortConfig(sortOption: sortOption, isAscending: isAscending)
    }
    
    // MARK: - WebDAV 排序配置
    
    struct WebDAVSortConfig: Codable {
        var sortOption: String // "name", "date", "size"
        var isAscending: Bool
        
        init(sortOption: String = "name", isAscending: Bool = true) {
            self.sortOption = sortOption
            self.isAscending = isAscending
        }
    }
    
    func getWebDAVSortConfig(for path: String) -> WebDAVSortConfig {
        return webDAVSortConfigs[path] ?? WebDAVSortConfig()
    }
    
    func setWebDAVSortConfig(for path: String, sortOption: String, isAscending: Bool) {
        webDAVSortConfigs[path] = WebDAVSortConfig(sortOption: sortOption, isAscending: isAscending)
    }
    
    // MARK: - 持久化存储
    
    private func loadConfigs() {
        // 加载 Jellyfin 配置
        if let jellyfinData = UserDefaults.standard.data(forKey: "jellyfinSortConfigs"),
           let decoded = try? JSONDecoder().decode([String: JellyfinSortConfig].self, from: jellyfinData) {
            jellyfinSortConfigs = decoded
        }
        
        // 加载 WebDAV 配置
        if let webDAVData = UserDefaults.standard.data(forKey: "webDAVSortConfigs"),
           let decoded = try? JSONDecoder().decode([String: WebDAVSortConfig].self, from: webDAVData) {
            webDAVSortConfigs = decoded
        }
    }
    
    private func saveJellyfinConfigs() {
        if let encoded = try? JSONEncoder().encode(jellyfinSortConfigs) {
            UserDefaults.standard.set(encoded, forKey: "jellyfinSortConfigs")
        }
    }
    
    private func saveWebDAVConfigs() {
        if let encoded = try? JSONEncoder().encode(webDAVSortConfigs) {
            UserDefaults.standard.set(encoded, forKey: "webDAVSortConfigs")
        }
    }
}
