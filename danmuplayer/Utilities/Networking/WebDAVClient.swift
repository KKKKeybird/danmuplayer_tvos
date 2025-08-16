/// WebDAV请求封装
import Foundation

/// WebDAV客户端，负责发起目录和文件请求
class WebDAVClient {
    let baseURL: URL
    let credentials: Credentials?
    private let urlSession: URLSession

    init(baseURL: URL, credentials: Credentials?) {
        self.baseURL = baseURL
        self.credentials = credentials
        
        // 创建支持HTTP和自签名证书的URLSession配置
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // 创建自定义URLSession来处理自签名证书
        self.urlSession = URLSession(
            configuration: config,
            delegate: WebDAVURLSessionDelegate(),
            delegateQueue: nil
        )
    }

    // MARK: - 发起请求获取目录文件列表
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
        
        print("WebDAV: Starting directory fetch")
        print("WebDAV: Base URL: \(baseURL)")
        print("WebDAV: Requested path: '\(path)'")
        print("WebDAV: Normalized path: '\(normalizedPath)'")
        print("WebDAV: Final URL: \(url)")
        print("WebDAV: Has credentials: \(credentials != nil)")
        
        // 直接使用WebDAV PROPFIND请求
        tryWebDAVRequest(url: url, completion: completion)
    }
    
    /// 尝试WebDAV PROPFIND请求
    private func tryWebDAVRequest(url: URL, completion: @escaping (Result<[WebDAVItem], Error>) -> Void) {
        print("WebDAV: Attempting PROPFIND request")
        print("WebDAV: PROPFIND URL: \(url)")
        
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
            print("WebDAV: Added Basic authentication for PROPFIND user: \(credentials.username)")
        } else {
            print("WebDAV: No authentication credentials for PROPFIND")
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
        
        print("WebDAV: PROPFIND request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("WebDAV: PROPFIND request body: \(propfindBody)")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                print("WebDAV: PROPFIND response received")
                
                if let error = error {
                    print("WebDAV: PROPFIND error: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("WebDAV: PROPFIND invalid response type")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("WebDAV: PROPFIND status code: \(httpResponse.statusCode)")
                print("WebDAV: PROPFIND response headers: \(httpResponse.allHeaderFields)")
                
                // 检查HTTP状态码
                switch httpResponse.statusCode {
                case 200...299:
                    print("WebDAV: PROPFIND success status: \(httpResponse.statusCode)")
                    break
                case 401:
                    print("WebDAV: PROPFIND unauthorized (401)")
                    completion(.failure(NetworkError.unauthorized))
                    return
                case 403:
                    print("WebDAV: PROPFIND forbidden (403)")
                    completion(.failure(NetworkError.forbidden))
                    return
                case 404:
                    print("WebDAV: PROPFIND not found (404)")
                    completion(.failure(NetworkError.notFound))
                    return
                default:
                    print("WebDAV: PROPFIND server error: \(httpResponse.statusCode)")
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    print("WebDAV: PROPFIND no data received")
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                print("WebDAV: PROPFIND data size: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(1000))
                    print("WebDAV: PROPFIND XML response preview: \(preview)")
                } else {
                    print("WebDAV: PROPFIND response data is not UTF-8 text")
                }
                
                // 解析WebDAV XML响应
                do {
                    let parser = WebDAVParser()
                    // 取 url.path 作为 currentPath 传递给 parser
                    let currentPath = url.path
                    let items = try parser.parseDirectoryResponse(data, currentPath: currentPath)
                    print("WebDAV: PROPFIND XML parsing succeeded, found \(items.count) items")
                    completion(.success(items))
                } catch {
                    print("WebDAV: PROPFIND XML parsing failed: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }

    // MARK: - 获取文件的流媒体URL
    /// - Parameters:
    ///   - path: 文件路径
    ///   - completion: 返回可用于流媒体播放的URL或错误
    func getStreamingURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileURL = baseURL.appendingPathComponent(path)
        print("WebDAV: Getting streaming URL for path: \(path)")
        print("WebDAV: Base URL: \(baseURL)")
        print("WebDAV: File URL: \(fileURL)")
        print("WebDAV: File URL components - scheme: \(fileURL.scheme ?? "nil"), host: \(fileURL.host ?? "nil"), path: \(fileURL.path)")
        
        // 如果有认证信息，需要验证文件是否存在且可访问
        if let credentials = credentials {
            print("WebDAV: Verifying file access with credentials")
            var request = URLRequest(url: fileURL)
            request.httpMethod = "HEAD" // 使用HEAD请求检查文件是否存在
            
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            
            print("WebDAV: HEAD request for file verification")
            
            urlSession.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("WebDAV: File verification error: \(error)")
                        completion(.failure(NetworkError.connectionFailed))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("WebDAV: File verification invalid response")
                        completion(.failure(NetworkError.invalidResponse))
                        return
                    }
                    
                    print("WebDAV: File verification status: \(httpResponse.statusCode)")
                    
                    switch httpResponse.statusCode {
                    case 200:
                        print("WebDAV: File verification successful")
                        break
                    case 401:
                        print("WebDAV: File verification unauthorized")
                        completion(.failure(NetworkError.unauthorized))
                        return
                    case 403:
                        print("WebDAV: File verification forbidden")
                        completion(.failure(NetworkError.forbidden))
                        return
                    case 404:
                        print("WebDAV: File not found")
                        completion(.failure(NetworkError.notFound))
                        return
                    default:
                        print("WebDAV: File verification server error: \(httpResponse.statusCode)")
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                        return
                    }
                    
                    // 为了使用 Range 而无需自定义 Header，这里在 URL 中内嵌 Basic 认证信息
                    if var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) {
                        components.user = credentials.username
                        components.password = credentials.password
                        if let authenticatedURL = components.url {
                            print("WebDAV: Using URL with embedded credentials for Range: \(authenticatedURL)")
                            completion(.success(authenticatedURL))
                            return
                        }
                    }
                    print("WebDAV: Fallback to original URL (server may allow anonymous GET)")
                    completion(.success(fileURL))
                }
            }.resume()
        } else {
            // 无认证情况下直接返回URL
            print("WebDAV: No credentials, returning direct URL")
            completion(.success(fileURL))
        }
    }
    
    // MARK: - 测试WebDAV连接
    /// - Parameter completion: 返回连接是否成功
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void) {
        print("WebDAV: Testing connection to \(baseURL)")
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "OPTIONS"
        request.timeoutInterval = 10.0
        
        // 添加认证信息
        if let credentials = credentials {
            let loginString = "\(credentials.username):\(credentials.password)"
            let loginData = loginString.data(using: .utf8)!
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            print("WebDAV: Added Basic authentication for connection test, user: \(credentials.username)")
        } else {
            print("WebDAV: No authentication credentials for connection test")
        }
        
        print("WebDAV: OPTIONS request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                print("WebDAV: Connection test response received")
                
                if let error = error {
                    print("WebDAV: Connection test error: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("WebDAV: Connection test invalid response type")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("WebDAV: Connection test status code: \(httpResponse.statusCode)")
                print("WebDAV: Connection test response headers: \(httpResponse.allHeaderFields)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    print("WebDAV: Connection test successful")
                    completion(.success(true))
                case 401:
                    print("WebDAV: Connection test unauthorized (401)")
                    completion(.failure(NetworkError.unauthorized))
                case 403:
                    print("WebDAV: Connection test forbidden (403)")
                    completion(.failure(NetworkError.forbidden))
                case 404:
                    print("WebDAV: Connection test not found (404)")
                    completion(.failure(NetworkError.notFound))
                default:
                    print("WebDAV: Connection test server error: \(httpResponse.statusCode)")
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
}

    // MARK: - 证书设置
/// URLSessionDelegate to handle self-signed certificates and HTTP connections for WebDAV
class WebDAVURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let host = challenge.protectionSpace.host
        let authMethod = challenge.protectionSpace.authenticationMethod
        
        print("WebDAV URLSessionDelegate: Received authentication challenge")
        print("WebDAV URLSessionDelegate: Host: \(host)")
        print("WebDAV URLSessionDelegate: Authentication method: \(authMethod)")
        print("WebDAV URLSessionDelegate: Protocol: \(challenge.protectionSpace.protocol ?? "unknown")")
        
        // 允许所有证书（包括自签名证书）
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            print("WebDAV URLSessionDelegate: Not a server trust challenge, using default handling")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 对于本地网络地址，直接信任证书
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.") || host == "localhost" || host.hasSuffix(".local") {
            print("WebDAV URLSessionDelegate: Local network address detected, trusting certificate")
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // 对于其他地址，也允许（为了支持自签名证书）
        print("WebDAV URLSessionDelegate: Non-local address, but allowing certificate for WebDAV compatibility")
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("WebDAV URLSessionDelegate: No server trust available, using default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
