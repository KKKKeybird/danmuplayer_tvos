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
    private var sessionId: String?
    private var keepAliveTimer: Timer?
    private var authenticatedUserId: String? // 存储认证后获取的用户ID
    
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
        config.waitsForConnectivity = true
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
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
        
        // ✅ 使用正确的Jellyfin客户端认证头部格式
        let authHeaderValue = "MediaBrowser Client=\"DanmuPlayer\", Device=\"AppleTV\", DeviceId=\"\(deviceId)\", Version=\"1.0.0\""
        request.setValue(authHeaderValue, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Testing connection to: \(url)")
        print("Server URL: \(serverURL)")
        print("Device ID: \(deviceId)")
        print("Auth header: \(authHeaderValue)")
        
        if let apiKey = apiKey {
            request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "X-MediaBrowser-Token")
            print("Using API Key authentication")
        } else if let accessToken = accessToken {
            request.setValue("MediaBrowser Token=\"\(accessToken)\"", forHTTPHeaderField: "Authorization")
            request.setValue(accessToken, forHTTPHeaderField: "X-MediaBrowser-Token")
            print("Using Access Token authentication")
        } else {
            print("No authentication token available - testing anonymous access")
        }
        
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Connection test failed with error: \(error)")
                    print("Error details: \(error.localizedDescription)")
                    
                    // 检查是否是URL格式问题
                    if let urlError = error as? URLError {
                        print("URLError code: \(urlError.code.rawValue)")
                        print("URLError localized description: \(urlError.localizedDescription)")
                        
                        switch urlError.code {
                        case .badURL:
                            print("Bad URL detected. Server URL: \(self.serverURL)")
                            completion(.failure(NetworkError.invalidURL))
                            return
                        case .cannotConnectToHost, .cannotFindHost:
                            print("Cannot connect to host")
                            completion(.failure(NetworkError.connectionFailed))
                            return
                        case .timedOut:
                            print("Connection timed out")
                            completion(.failure(NetworkError.timeout))
                            return
                        default:
                            completion(.failure(NetworkError.from(error)))
                            return
                        }
                    }
                    
                    completion(.failure(NetworkError.from(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response received")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Connection test response code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    print("Connection test successful")
                    completion(.success(true))
                case 401:
                    // 401对于连接测试来说是可以接受的，说明服务器可达但需要认证
                    print("Server is reachable but requires authentication (401) - this is normal for connection test")
                    completion(.success(true))
                case 403:
                    print("Server is reachable but access forbidden (403)")
                    completion(.success(true)) // 服务器可达
                case 404:
                    print("API endpoint not found (404) - server may not be Jellyfin")
                    completion(.failure(NetworkError.notFound))
                case 500...599:
                    print("Server error (5xx)")
                    completion(.failure(NetworkError.serverUnavailable))
                default:
                    print("Unexpected status code: \(httpResponse.statusCode)")
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
        
        // ✅ 使用正确的Jellyfin认证头部格式
        let authHeaderValue = "MediaBrowser Client=\"DanmuPlayer\", Device=\"AppleTV\", DeviceId=\"\(deviceId)\", Version=\"1.0.0\""
        request.setValue(authHeaderValue, forHTTPHeaderField: "X-Emby-Authorization")
        request.timeoutInterval = 15.0
        
        print("Attempting authentication for user: \(username)")
        print("Authentication URL: \(url)")
        print("Device ID: \(deviceId)")
        print("Auth header: \(authHeaderValue)")
        
        // 使用正确的请求体格式
        let authRequest = [
            "Username": username,
            "Pw": password
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: authRequest, options: [])
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request body: \(jsonString)")
            }
        } catch {
            print("Failed to create JSON data: \(error)")
            completion(.failure(NetworkError.parseError))
            return
        }
        
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
                    self.sessionId = authResponse.sessionInfo?.id
                    self.authenticatedUserId = authResponse.user.id // 保存认证用户的ID
                    print("Authentication successful for user: \(authResponse.user.name)")
                    print("User ID: \(authResponse.user.id)")
                    print("Access Token: \(authResponse.accessToken)")
                    
                    // 启动会话保持
                    self.startSessionKeepAlive()
                    
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
        // 优先使用认证后获取的用户ID，否则使用初始化时的userId
        guard let currentUserId = authenticatedUserId ?? userId else {
            print("Jellyfin: No user ID available for getLibraries")
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        print("Jellyfin: Getting libraries for user ID: \(currentUserId)")
        
        let url = serverURL.appendingPathComponent("Users/\(currentUserId)/Views")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        print("Jellyfin: Libraries request URL: \(url)")
        print("Jellyfin: Libraries request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Jellyfin: Libraries request failed: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Jellyfin: Libraries invalid response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Jellyfin: Libraries response status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        print("Jellyfin: Libraries unauthorized (401)")
                        completion(.failure(NetworkError.unauthorized))
                    } else {
                        print("Jellyfin: Libraries error status: \(httpResponse.statusCode)")
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    }
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinLibrary>.self, from: data)
                    print("Jellyfin: Successfully got \(response.items.count) libraries")
                    completion(.success(response.items))
                } catch {
                    print("Jellyfin: Failed to parse libraries response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Jellyfin: Libraries response body: \(responseString)")
                    }
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取媒体库中的项目
    func getLibraryItems(libraryId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) {
        guard let currentUserId = authenticatedUserId ?? userId else {
            print("Jellyfin: No user ID available for getLibraryItems")
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        print("Jellyfin: Getting library items for user ID: \(currentUserId), library: \(libraryId)")
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Users/\(currentUserId)/Items"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Series,Movie,Video"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "BasicSyncInfo,CanDelete,PrimaryImageAspectRatio,ProductionYear,Status,EndDate,Overview,Genres,Tags,SeriesName,SeasonName,IndexNumber,ParentIndexNumber"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Limit", value: "200") // 限制返回数量避免超时
        ]
        
        guard let url = components?.url else {
            print("Jellyfin: Failed to create library items URL")
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        print("Jellyfin: Library items request URL: \(url)")
        print("Jellyfin: Library items request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Jellyfin: Library items request failed: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Jellyfin: Library items invalid response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Jellyfin: Library items response status: \(httpResponse.statusCode)")
                print("Jellyfin: Library items response headers: \(httpResponse.allHeaderFields)")
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        print("Jellyfin: Library items unauthorized (401)")
                        completion(.failure(NetworkError.unauthorized))
                    } else if httpResponse.statusCode == 404 {
                        print("Jellyfin: Library not found (404)")
                        completion(.failure(NetworkError.notFound))
                    } else {
                        print("Jellyfin: Library items error status: \(httpResponse.statusCode)")
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    }
                    return
                }
                
                // 打印响应内容用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Jellyfin: Library items response body: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinMediaItem>.self, from: data)
                    print("Jellyfin: Successfully got \(response.items.count) library items")
                    for (index, item) in response.items.enumerated() {
                        print("Jellyfin: Item \(index + 1): \(item.name) (ID: \(item.id), Type: \(item.type))")
                    }
                    completion(.success(response.items))
                } catch {
                    print("Jellyfin: Failed to parse library items response: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取系列的季节列表
    func getSeasons(seriesId: String, completion: @escaping (Result<[JellyfinMediaItem], Error>) -> Void) {
        guard let currentUserId = authenticatedUserId ?? userId else {
            print("Jellyfin: No user ID available for getSeasons")
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        print("Jellyfin: Getting seasons for user ID: \(currentUserId), series: \(seriesId)")
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Shows/\(seriesId)/Seasons"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: currentUserId),
            URLQueryItem(name: "Fields", value: "BasicSyncInfo,CanDelete,PrimaryImageAspectRatio,ProductionYear,Status,Overview")
        ]
        
        guard let url = components?.url else {
            print("Jellyfin: Failed to create seasons URL")
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        print("Jellyfin: Seasons request URL: \(url)")
        print("Jellyfin: Seasons request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Jellyfin: Seasons request failed: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Jellyfin: Seasons invalid response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Jellyfin: Seasons response status: \(httpResponse.statusCode)")
                print("Jellyfin: Seasons response headers: \(httpResponse.allHeaderFields)")
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        print("Jellyfin: Seasons unauthorized (401)")
                        completion(.failure(NetworkError.unauthorized))
                    } else if httpResponse.statusCode == 404 {
                        print("Jellyfin: Series not found (404)")
                        completion(.failure(NetworkError.notFound))
                    } else {
                        print("Jellyfin: Seasons error status: \(httpResponse.statusCode)")
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    }
                    return
                }
                
                // 打印响应内容用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Jellyfin: Seasons response body: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinMediaItem>.self, from: data)
                    print("Jellyfin: Successfully got \(response.items.count) seasons")
                    for (index, season) in response.items.enumerated() {
                        print("Jellyfin: Season \(index + 1): \(season.name) (ID: \(season.id))")
                    }
                    completion(.success(response.items))
                } catch {
                    print("Jellyfin: Failed to parse seasons response: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取剧集列表
    func getEpisodes(seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) {
        guard let currentUserId = authenticatedUserId ?? userId else {
            print("Jellyfin: No user ID available for getEpisodes")
            completion(.failure(NetworkError.unauthorized))
            return
        }
        
        print("Jellyfin: Getting episodes for user ID: \(currentUserId), series: \(seriesId)")
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Shows/\(seriesId)/Episodes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: currentUserId),
            URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio,MediaStreams")
        ]
        
        guard let url = components?.url else {
            print("Jellyfin: Failed to create episodes URL")
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        print("Jellyfin: Episodes request URL: \(url)")
        print("Jellyfin: Episodes request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Jellyfin: Episodes request failed: \(error)")
                    completion(.failure(NetworkError.connectionFailed))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Jellyfin: Episodes invalid response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                print("Jellyfin: Episodes response status: \(httpResponse.statusCode)")
                print("Jellyfin: Episodes response headers: \(httpResponse.allHeaderFields)")
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if httpResponse.statusCode == 401 {
                        print("Jellyfin: Episodes unauthorized (401)")
                        completion(.failure(NetworkError.unauthorized))
                    } else if httpResponse.statusCode == 404 {
                        print("Jellyfin: Series not found (404)")
                        completion(.failure(NetworkError.notFound))
                    } else {
                        print("Jellyfin: Episodes error status: \(httpResponse.statusCode)")
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                    }
                    return
                }
                
                // 打印响应内容用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Jellyfin: Episodes response body: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(JellyfinItemsResponse<JellyfinEpisode>.self, from: data)
                    print("Jellyfin: Successfully got \(response.items.count) episodes")
                    for (index, episode) in response.items.enumerated() {
                        print("Jellyfin: Episode \(index + 1): \(episode.name) (Season \(episode.parentIndexNumber ?? 0), Episode \(episode.indexNumber ?? 0))")
                    }
                    completion(.success(response.items))
                } catch {
                    print("Jellyfin: Failed to parse episodes response: \(error)")
                    completion(.failure(NetworkError.parseError))
                }
            }
        }.resume()
    }
    
    /// 获取播放URL
    func getPlaybackUrl(itemId: String) -> URL? {
        guard let currentUserId = authenticatedUserId ?? userId else { 
            print("Jellyfin: No user ID available for getPlaybackUrl")
            return nil 
        }
        
        print("Jellyfin: Getting playback URL for user ID: \(currentUserId), item: \(itemId)")
        
        var components = URLComponents(url: serverURL.appendingPathComponent("Videos/\(itemId)/stream"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: currentUserId),
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
        // ✅ 使用正确的Jellyfin客户端认证头部格式
        let authHeaderValue = "MediaBrowser Client=\"DanmuPlayer\", Device=\"AppleTV\", DeviceId=\"\(deviceId)\", Version=\"1.0.0\""
        request.setValue(authHeaderValue, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加认证令牌
        if let apiKey = apiKey {
            // 使用API Key作为主要认证方式
            request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "X-MediaBrowser-Token")
        } else if let accessToken = accessToken {
            // 使用Access Token作为备用认证方式
            request.setValue("MediaBrowser Token=\"\(accessToken)\"", forHTTPHeaderField: "Authorization")
            request.setValue(accessToken, forHTTPHeaderField: "X-MediaBrowser-Token")
        }
    }
    
    /// 启动会话保持机制
    private func startSessionKeepAlive() {
        // 停止之前的定时器
        keepAliveTimer?.invalidate()
        
        // 每30秒发送一次心跳
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendKeepAlive()
        }
        
        print("Jellyfin: Started session keep-alive timer")
    }
    
    /// 发送心跳请求
    private func sendKeepAlive() {
        guard let accessToken = accessToken else { return }
        
        let url = serverURL.appendingPathComponent("Sessions/Playing/Ping")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeader(to: &request)
        
        print("Jellyfin: Sending keep-alive ping")
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Jellyfin: Keep-alive ping failed: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Jellyfin: Keep-alive ping response: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// 停止会话保持
    func stopSessionKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        print("Jellyfin: Stopped session keep-alive timer")
    }
    
    /// 析构函数，清理资源
    deinit {
        stopSessionKeepAlive()
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
