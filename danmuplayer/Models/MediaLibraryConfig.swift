/// 媒体库配置模型
import Foundation

/// 媒体库配置信息，可序列化保存
struct MediaLibraryConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let baseURL: String
    let username: String?
    let password: String?
    
    init(id: UUID = UUID(), name: String, baseURL: String, username: String? = nil, password: String? = nil) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.username = username
        self.password = password
    }
    
    /// 转换为WebDAVClient
    func createWebDAVClient() -> WebDAVClient? {
        guard let url = URL(string: baseURL) else {
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
}
