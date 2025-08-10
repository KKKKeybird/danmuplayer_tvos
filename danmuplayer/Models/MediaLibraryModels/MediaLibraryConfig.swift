/// 媒体库配置模型
import Foundation

/// 媒体库服务器类型
enum MediaLibraryServerType: String, Codable, CaseIterable {
    case webdav = "webdav"
    case jellyfin = "jellyfin"
    
    var displayName: String {
        switch self {
        case .webdav:
            return "WebDAV"
        case .jellyfin:
            return "Jellyfin"
        }
    }
}

/// 媒体库配置信息，支持WebDAV和Jellyfin两种类型
struct MediaLibraryConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let serverURL: String // 服务器地址
    let serverType: MediaLibraryServerType // 服务器类型
    let username: String?
    let password: String?
    
    // Jellyfin专用字段
    let apiKey: String? // Jellyfin API密钥
    let userId: String? // Jellyfin用户ID
    
    init(id: UUID = UUID(), name: String, serverURL: String, 
         serverType: MediaLibraryServerType = .webdav,
         username: String? = nil, password: String? = nil,
         apiKey: String? = nil, userId: String? = nil) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.serverType = serverType
        self.username = username
        self.password = password
        self.apiKey = apiKey
        self.userId = userId
    }
    
    /// 创建对应类型的客户端
    func createClient() -> Any? {
        switch serverType {
        case .webdav:
            return createWebDAVClient()
        case .jellyfin:
            return createJellyfinClient()
        }
    }
    
    /// 创建WebDAV客户端
    func createWebDAVClient() -> WebDAVClient? {
        guard serverType == .webdav,
              let url = URL(string: serverURL) else {
            return nil
        }
        
        let credentials: Credentials?
        if let username = username, let password = password {
            credentials = Credentials(username: username, password: password)
        } else {
            credentials = nil
        }
        
        return WebDAVClient(baseURL: url, credentials: credentials)
    }
    
    /// 创建Jellyfin客户端
    func createJellyfinClient() -> JellyfinClient? {
        guard serverType == .jellyfin,
              let url = URL(string: serverURL) else {
            return nil
        }
        
        return JellyfinClient(
            serverURL: url,
            apiKey: apiKey,
            userId: userId,
            username: username,
            password: password
        )
    }
    
    // 保持向后兼容性
    var baseURL: String { serverURL }
    var isJellyfinServer: Bool { serverType == .jellyfin }
}

