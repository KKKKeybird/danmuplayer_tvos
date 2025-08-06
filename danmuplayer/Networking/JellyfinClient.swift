/// Jellyfin API客户端
import Foundation

/// Jellyfin服务器API客户端
class JellyfinClient {
    let serverURL: URL
    let apiKey: String?
    let userId: String?
    let username: String?
    let password: String?
    
    private var accessToken: String?
    private let urlSession: URLSession
    private let deviceId: String
    
    init(serverURL: URL, apiKey: String? = nil, userId: String? = nil, 
         username: String? = nil, password: String? = nil) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.userId = userId
        self.username = username
        self.password = password
        
        // 生成唯一的设备ID
        self.deviceId = "DanmuPlayer-tvOS-\(UUID().uuidString.prefix(8))"
        
        // 创建支持HTTP和自签名证书的URLSession配置
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // 创建自定义URLSession来处理自签名证书
        self.urlSession = URLSession(
            configuration: config,
            delegate: JellyfinURLSessionDelegate(),
            delegateQueue: nil
        )
    }
    
    /// 测试连接
    func testConnection(completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = serverURL.appendingPathComponent("System/Info")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 设置10秒超时
        
        print("Testing connection to: \(url)")
        
        if let apiKey = apiKey {
            request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
        }
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Connection test failed with error: \(error)")
                    completion(.failure(NetworkError.from(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response received")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Connection test response code: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    print("Connection test successful")
                    completion(.success(true))
                case 401:
                    completion(.failure(NetworkError.unauthorized))
                case 403:
                    completion(.failure(NetworkError.forbidden))
                case 404:
                    completion(.failure(NetworkError.notFound))
                case 500...599:
                    completion(.failure(NetworkError.serverUnavailable))
                default:
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    /// 用户认证
    func authenticate(completion: @escaping (Result<JellyfinUser, Error>) -> Void) {
        guard let username = username, let password = password else {
            print("Authentication failed: Missing username or password")
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        // 使用标准的认证端点
        authenticateWithEndpoint("Users/AuthenticateByName", username: username, password: password, completion: completion)
    }
    
    /// 使用特定端点进行认证
    private func authenticateWithEndpoint(_ endpoint: String, username: String, password: String, completion: @escaping (Result<JellyfinUser, Error>) -> Void) {
        let url = serverURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DanmuPlayer", forHTTPHeaderField: "X-Emby-Client")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Emby-Client-Version")
        request.setValue("DanmuPlayer-tvOS", forHTTPHeaderField: "X-Emby-Device-Name")
        request.setValue(deviceId, forHTTPHeaderField: "X-Emby-Device-Id")
        request.timeoutInterval = 15.0
        
        // 使用正确的Jellyfin认证API格式，按照官方源码的字段顺序
        let authRequest: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        
        print("Attempting authentication for user: \(username)")
        print("Authentication URL: \(url)")
        print("Device ID: \(deviceId)")
        
        // 手动构建JSON以确保字段顺序
        let jsonString = "{\"Username\":\"\(username)\",\"Pw\":\"\(password)\"}"
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to create JSON data")
            completion(.failure(NetworkError.parseError))
            return
        }
        request.httpBody = jsonData
        
        print("Request body: \(jsonString)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Authentication request failed: \(error)")
                    completion(.failure(NetworkError.from(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid authentication response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Authentication response code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
                
                // 打印响应内容用于调试
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString)")
                }
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        print("Authentication failed: Invalid credentials (401)")
                    } else if httpResponse.statusCode == 400 {
                        print("Authentication failed: Bad request (400)")
                    } else {
                        print("Authentication failed with status: \(httpResponse.statusCode)")
                    }
                    completion(.failure(NetworkError.unauthorized))
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(JellyfinAuthResponse.self, from: data)
                    self.accessToken = authResponse.accessToken
                    print("Authentication successful for user: \(authResponse.user.name)")
                    completion(.success(authResponse.user))
                } catch {
                    print("Failed to parse authentication response: \(error)")
                    print("Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取媒体库列表
    func getLibraries(completion: @escaping (Result<[JellyfinLibrary], Error>) -> Void) {
        guard let userId = userId else {
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        let url = serverURL.appendingPathComponent("Users/\(userId)/Views")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinLibrary>.self, from: data)
                    completion(.success(response.items))
                } catch {
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取媒体库中的项目
    func getLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) {
        guard let userId = userId else {
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Users/\(userId)/Items"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Series,Movie"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "BasicSyncInfo,CanDelete,PrimaryImageAspectRatio,ProductionYear,Status,EndDate,Overview")
        ]
        
        guard let url = components?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinMediaItem>.self, from: data)
                    completion(.success(response.items))
                } catch {
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取剧集列表
    func getEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) {
        guard let userId = userId else {
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Shows/\(seriesId)/Episodes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio,MediaStreams")
        ]
        
        guard let url = components?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinEpisode>.self, from: data)
                    completion(.success(response.items))
                } catch {
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取播放URL
    func getPlaybackUrl(itemId: String) -> URL? {
        guard let userId = userId else { return nil }
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Videos/\(itemId)/stream"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "MediaSourceId", value: itemId),
            URLQueryItem(name: "Static", value: "true")
        ]
        
        if let apiKey = apiKey {
            components?.queryItems?.append(URLQueryItem(name: "ApiKey", value: apiKey))
        } else if let accessToken = accessToken {
            components?.queryItems?.append(URLQueryItem(name: "AccessToken", value: accessToken))
        }
        
        return components?.url
    }
    
    /// 获取图片URL
    func getImageUrl(itemId: String, type: String = "Primary", maxWidth: Int = 600) -> URL? {
        var components = URLComponents(url: serverURL.appendingPathComponent("Items/\(itemId)/Images/\(type)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "quality", value: "90")
        ]
        
        if let apiKey = apiKey {
            components?.queryItems?.append(URLQueryItem(name: "ApiKey", value: apiKey))
        }
        
        return components?.url
    }
    
    private func addAuthHeader(to request: inout URLRequest) {
        if let apiKey = apiKey {
            request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
        } else if let accessToken = accessToken {
            request.setValue("MediaBrowser Token=\"\(accessToken)\"", forHTTPHeaderField: "Authorization")
        }
    }
}

/// URLSessionDelegate to handle self-signed certificates and HTTP connections
class JellyfinURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // 允许所有证书（包括自签名证书）
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 对于本地网络地址，直接信任证书
        let host = challenge.protectionSpace.host
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.") || host == "localhost" || host.hasSuffix(".local") {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // 对于其他地址，也允许（为了支持自签名证书）
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
