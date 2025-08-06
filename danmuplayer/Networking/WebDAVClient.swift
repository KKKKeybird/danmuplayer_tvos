/// WebDAV请求封装
import Foundation

/// WebDAV客户端，负责发起目录和文件请求
class WebDAVClient {
    let baseURL: URL
    let credentials: Credentials?

    init(baseURL: URL, credentials: Credentials?) {
        self.baseURL = baseURL
        self.credentials = credentials
    }

    /// 发起请求获取目录文件列表
    /// - Parameters:
    ///   - path: 目录相对路径
    ///   - completion: 回调WebDAVItem数组或错误
    func fetchDirectory(at path: String, completion: @escaping (Result<[WebDAVItem], Error>) -> Void) {
        // 处理路径，确保正确的URL构造
        let normalizedPath = path == "/" ? "" : path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url: URL
        if normalizedPath.isEmpty {
            url = baseURL
        } else {
            url = baseURL.appendingPathComponent(normalizedPath)
        }
        
        // 首先尝试GET请求（适用于HTML目录列表）
        tryHTMLRequest(url: url) { [weak self] result in
            switch result {
            case .success(let items):
                completion(.success(items))
            case .failure(_):
                // 如果HTML解析失败，尝试WebDAV PROPFIND请求
                self?.tryWebDAVRequest(url: url, completion: completion)
            }
        }
    }
    
    /// 尝试HTML GET请求
    private func tryHTMLRequest(url: URL, completion: @escaping (Result<[WebDAVItem], Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        // 添加认证信息
        if let credentials = credentials {
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        }
        
        // 创建自定义URLSession配置以支持HTTP连接
        let config = URLSessionConfiguration.default
        
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                // 检查HTTP状态码
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 401:
                    completion(.failure(NetworkError.unauthorized))
                    return
                case 403:
                    completion(.failure(NetworkError.forbidden))
                    return
                case 404:
                    completion(.failure(NetworkError.notFound))
                    return
                default:
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                // 尝试解析HTML格式的目录列表
                do {
                    let htmlParser = HTMLDirectoryParser()
                    let items = try htmlParser.parseDirectoryResponse(data, baseURL: url)
                    completion(.success(items))
                } catch {
                    print("HTML parsing failed: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 尝试WebDAV PROPFIND请求
    private func tryWebDAVRequest(url: URL, completion: @escaping (Result<[WebDAVItem], Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        // 添加认证信息
        if let credentials = credentials {
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        }
        
        // 设置PROPFIND请求体，包含更多属性以增强兼容性
        let propfindBody = """
        <?xml version="1.0" encoding="utf-8" ?>
        <D:propfind xmlns:D="DAV:">
            <D:prop>
                <D:displayname/>
                <D:getcontentlength/>
                <D:getlastmodified/>
                <D:creationdate/>
                <D:resourcetype/>
                <D:getcontenttype/>
                <D:getetag/>
            </D:prop>
        </D:propfind>
        """
        request.httpBody = propfindBody.data(using: .utf8)
        
        // 创建自定义URLSession配置以支持HTTP连接
        let config = URLSessionConfiguration.default
        
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                // 检查HTTP状态码
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 401:
                    completion(.failure(NetworkError.unauthorized))
                    return
                case 403:
                    completion(.failure(NetworkError.forbidden))
                    return
                case 404:
                    completion(.failure(NetworkError.notFound))
                    return
                default:
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                // 解析WebDAV XML响应
                do {
                    let parser = WebDAVParser()
                    let items = try parser.parseDirectoryResponse(data)
                    completion(.success(items))
                } catch {
                    print("WebDAV XML parsing failed: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }

    /// 获取文件的流媒体URL
    /// - Parameters:
    ///   - path: 文件路径
    ///   - completion: 返回可用于流媒体播放的URL或错误
    func getStreamingURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileURL = baseURL.appendingPathComponent(path)
        
        // 如果有认证信息，需要验证文件是否存在且可访问
        if let credentials = credentials {
            var request = URLRequest(url: fileURL)
            request.httpMethod = "HEAD" // 使用HEAD请求检查文件是否存在
            
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            
            // 创建自定义URLSession配置以支持HTTP连接
            let config = URLSessionConfiguration.default
            
            URLSession(configuration: config).dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(NetworkError.connectionFailed))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(NetworkError.invalidResponse))
                        return
                    }
                    
                    switch httpResponse.statusCode {
                    case 200:
                        break
                    case 401:
                        completion(.failure(NetworkError.unauthorized))
                        return
                    case 403:
                        completion(.failure(NetworkError.forbidden))
                        return
                    case 404:
                        completion(.failure(NetworkError.notFound))
                        return
                    default:
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                        return
                    }
                    
                    // 构建包含认证信息的URL
                    var urlComponents = URLComponents(url: fileURL, resolvingAgainstBaseURL: false)
                    urlComponents?.user = credentials.username
                    urlComponents?.password = credentials.password
                    
                    if let authenticatedURL = urlComponents?.url {
                        completion(.success(authenticatedURL))
                    } else {
                        completion(.success(fileURL))
                    }
                }
            }.resume()
        } else {
            // 无认证情况下直接返回URL
            completion(.success(fileURL))
        }
    }
    
    /// 测试WebDAV连接
    /// - Parameter completion: 返回连接是否成功
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "OPTIONS"
        request.timeoutInterval = 10.0
        
        // 添加认证信息
        if let credentials = credentials {
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        }
        
        // 创建自定义URLSession配置以支持HTTP连接
        let config = URLSessionConfiguration.default
        
        URLSession(configuration: config).dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    completion(.success(true))
                case 401:
                    completion(.failure(NetworkError.unauthorized))
                case 403:
                    completion(.failure(NetworkError.forbidden))
                case 404:
                    completion(.failure(NetworkError.notFound))
                default:
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
}
