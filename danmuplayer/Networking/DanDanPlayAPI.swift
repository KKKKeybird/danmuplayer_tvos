import Foundation
import CryptoKit

/// 封装弹弹Play的API请求
class DanDanPlayAPI {
    private let baseURL = "https://api.dandanplay.net"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 签名验证
    
    /// 生成API请求签名
    /// 算法：base64(sha256(AppId + Timestamp + Path + AppSecret))
    private func generateSignature(appId: String, timestamp: Int64, path: String, appSecret: String) -> String {
        let data = "\(appId)\(timestamp)\(path)\(appSecret)"
        let hash = SHA256.hash(data: Data(data.utf8))
        return Data(hash).base64EncodedString()
    }
    
    /// 为请求添加身份验证头
    private func addAuthenticationHeaders(to request: inout URLRequest, path: String) -> Bool {
        guard DanDanPlayConfig.isConfigured else {
            print("弹弹Play API未配置AppId和AppSecret")
            return false
        }
        
        let timestamp = Int64(Date().timeIntervalSince1970)
        let signature = generateSignature(
            appId: DanDanPlayConfig.appId,
            timestamp: timestamp,
            path: path,
            appSecret: DanDanPlayConfig.secretKey
        )
        
        request.setValue(DanDanPlayConfig.appId, forHTTPHeaderField: "X-AppId")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        
        return true
    }
    
    /// 自动识别剧集（返回最佳匹配结果）
    func identifyEpisode(for videoURL: URL, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) {
        // 提取文件信息
        guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let fileName = fileInfo.fileName
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // 先检查缓存（如果用户之前手动选择过，缓存中就是用户选择的结果）
        let cacheKey = !fileInfo.fileHash.isEmpty ? fileInfo.fileHash : fileNameWithoutExtension
        if let cachedResults = DanDanPlayCache.shared.getCachedSearchResult(for: cacheKey),
           let firstResult = cachedResults.first {
            print("📦 使用缓存的剧集: \(firstResult.displayTitle)")
            completion(.success(firstResult))
            return
        }
        
        // 构建匹配请求
        guard let url = URL(string: "\(baseURL)/api/v2/match") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/match"
        guard addAuthenticationHeaders(to: &request, path: path) else {
            completion(.failure(NetworkError.authenticationFailed))
            return
        }
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "fileName": fileName,
            "fileHash": fileInfo.fileHash,
            "fileSize": fileInfo.fileSize,
            "videoDuration": fileInfo.videoDuration, // 使用实际的视频时长
            "matchMode": "hashAndFileName" // 使用hash和文件名匹配模式
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(NetworkError.parseError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(NetworkError.connectionFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let matchResult = try JSONDecoder().decode(DanDanPlayMatchResult.self, from: data)
                
                // 检查API调用是否成功
                guard matchResult.success, matchResult.errorCode == 0 else {
                    print("Match API调用失败: \(matchResult.errorMessage ?? "未知错误")")
                    // 回退到搜索API
                    self.fallbackToSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
                    return
                }
                
                // 系统自动识别：使用第一个匹配结果
                if let match = matchResult.matches?.first {
                    let episode = DanDanPlayEpisode(
                        animeId: match.animeId,
                        animeTitle: match.animeTitle ?? "未知作品",
                        episodeId: Int(match.episodeId), // 转换为Int以兼容现有代码
                        episodeTitle: match.episodeTitle ?? "未知剧集",
                        shift: match.shift // 保留偏移时间信息
                    )
                    
                    // 缓存所有匹配结果供后续手动选择使用
                    if let matches = matchResult.matches {
                        let episodeList = matches.map { match in
                            DanDanPlayEpisode(
                                animeId: match.animeId,
                                animeTitle: match.animeTitle ?? "未知作品",
                                episodeId: Int(match.episodeId),
                                episodeTitle: match.episodeTitle ?? "未知剧集",
                                shift: match.shift
                            )
                        }
                        DanDanPlayCache.shared.cacheSearchResult(episodeList, for: cacheKey)
                    }
                    
                    completion(.success(episode))
                } else {
                    // 如果匹配失败，回退到搜索API
                    self.fallbackToSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
                }
            } catch {
                // 解析失败，回退到搜索API
                self.fallbackToSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
            }
        }.resume()
    }
    
    /// 回退搜索方法，当文件匹配失败时使用
    private func fallbackToSearch(fileNameWithoutExtension: String, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) {
        // 构建搜索请求
        guard let encodedFileName = fileNameWithoutExtension.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/v2/search/episodes?anime=\(encodedFileName)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/search/episodes"
        guard addAuthenticationHeaders(to: &request, path: path) else {
            completion(.failure(NetworkError.authenticationFailed))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(NetworkError.connectionFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let searchResult = try JSONDecoder().decode(DanDanPlaySearchResult.self, from: data)
                
                // 检查API调用是否成功
                guard searchResult.success, searchResult.errorCode == 0 else {
                    print("Search API调用失败: \(searchResult.errorMessage ?? "未知错误")")
                    completion(.failure(NetworkError.serverError(searchResult.errorCode)))
                    return
                }
                
                if let animes = searchResult.animes, let firstAnime = animes.first {
                    // 选择第一个匹配的动画和第一集
                    let episode = DanDanPlayEpisode(
                        animeId: firstAnime.animeId,
                        animeTitle: firstAnime.animeTitle ?? "未知作品",
                        episodeId: firstAnime.episodes?.first?.episodeId ?? 0,
                        episodeTitle: firstAnime.episodes?.first?.episodeTitle ?? "未知剧集",
                        shift: nil // 搜索API没有偏移时间信息
                    )
                    
                    // 缓存搜索结果
                    var episodeList: [DanDanPlayEpisode] = []
                    for anime in animes {
                        if let episodes = anime.episodes {
                            for episode in episodes {
                                let episodeItem = DanDanPlayEpisode(
                                    animeId: anime.animeId,
                                    animeTitle: anime.animeTitle ?? "未知作品",
                                    episodeId: episode.episodeId,
                                    episodeTitle: episode.episodeTitle ?? "未知剧集",
                                    shift: nil // 搜索API没有偏移时间信息
                                )
                                episodeList.append(episodeItem)
                            }
                        }
                    }
                    DanDanPlayCache.shared.cacheSearchResult(episodeList, for: fileNameWithoutExtension)
                    
                    completion(.success(episode))
                } else {
                    completion(.failure(NetworkError.notFound))
                }
            } catch {
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }

    /// 获取候选剧集列表供用户手动选择
    func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void) {
        // 提取文件信息
        guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let fileName = fileInfo.fileName
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // 先检查缓存 - 使用文件hash作为缓存key
        let cacheKey = !fileInfo.fileHash.isEmpty ? fileInfo.fileHash : fileNameWithoutExtension
        if let cachedResults = DanDanPlayCache.shared.getCachedSearchResult(for: cacheKey) {
            completion(.success(cachedResults))
            return
        }
        
        // 先尝试文件匹配
        guard let url = URL(string: "\(baseURL)/api/v2/match") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/match"
        guard addAuthenticationHeaders(to: &request, path: path) else {
            completion(.failure(NetworkError.authenticationFailed))
            return
        }
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "fileName": fileName,
            "fileHash": fileInfo.fileHash,
            "fileSize": fileInfo.fileSize,
            "videoDuration": fileInfo.videoDuration, // 使用实际的视频时长
            "matchMode": "hashAndFileName"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(NetworkError.parseError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(NetworkError.connectionFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let matchResult = try JSONDecoder().decode(DanDanPlayMatchResult.self, from: data)
                
                // 检查API调用是否成功
                guard matchResult.success, matchResult.errorCode == 0 else {
                    print("Match API调用失败: \(matchResult.errorMessage ?? "未知错误")")
                    // 回退到搜索API
                    self.fallbackToCandidateSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
                    return
                }
                
                if let matches = matchResult.matches, !matches.isEmpty {
                    let episodeList = matches.map { match in
                        DanDanPlayEpisode(
                            animeId: match.animeId,
                            animeTitle: match.animeTitle ?? "未知作品",
                            episodeId: Int(match.episodeId), // 转换为Int
                            episodeTitle: match.episodeTitle ?? "未知剧集",
                            shift: match.shift // 保留偏移时间信息
                        )
                    }
                    
                    // 缓存匹配结果
                    DanDanPlayCache.shared.cacheSearchResult(episodeList, for: cacheKey)
                    completion(.success(episodeList))
                } else {
                    // 如果匹配失败，回退到搜索API
                    self.fallbackToCandidateSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
                }
            } catch {
                // 解析失败，回退到搜索API
                self.fallbackToCandidateSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
            }
        }.resume()
    }
    
    /// 候选搜索的回退方法
    private func fallbackToCandidateSearch(fileNameWithoutExtension: String, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void) {
        guard let encodedFileName = fileNameWithoutExtension.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/v2/search/episodes?anime=\(encodedFileName)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/search/episodes"
        guard addAuthenticationHeaders(to: &request, path: path) else {
            completion(.failure(NetworkError.authenticationFailed))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(NetworkError.connectionFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let searchResult = try JSONDecoder().decode(DanDanPlaySearchResult.self, from: data)
                
                // 检查API调用是否成功
                guard searchResult.success, searchResult.errorCode == 0 else {
                    print("Search API调用失败: \(searchResult.errorMessage ?? "未知错误")")
                    completion(.failure(NetworkError.serverError(searchResult.errorCode)))
                    return
                }
                
                var episodeList: [DanDanPlayEpisode] = []
                
                if let animes = searchResult.animes {
                    for anime in animes {
                        if let episodes = anime.episodes {
                            for episode in episodes {
                                let episodeItem = DanDanPlayEpisode(
                                    animeId: anime.animeId,
                                    animeTitle: anime.animeTitle ?? "未知作品",
                                    episodeId: episode.episodeId,
                                    episodeTitle: episode.episodeTitle ?? "未知剧集",
                                    shift: nil // 搜索API没有偏移时间信息
                                )
                                episodeList.append(episodeItem)
                            }
                        }
                    }
                }
                
                // 缓存搜索结果
                DanDanPlayCache.shared.cacheSearchResult(episodeList, for: fileNameWithoutExtension)
                
                completion(.success(episodeList))
            } catch {
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }

    /// 更新剧集选择结果，通知弹幕匹配
    func updateEpisodeSelection(episode: DanDanPlayEpisode, for videoURL: URL, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 提取文件信息以获取正确的缓存key
        guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let fileName = fileInfo.fileName
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        let cacheKey = !fileInfo.fileHash.isEmpty ? fileInfo.fileHash : fileNameWithoutExtension
        
        // 直接用用户选择的剧集覆盖现有缓存
        // 将用户选择的剧集作为唯一结果缓存，这样下次会优先使用
        DanDanPlayCache.shared.cacheSearchResult([episode], for: cacheKey)
        
        // 同时也缓存到专门的剧集信息缓存（长期缓存）
        DanDanPlayCache.shared.cacheEpisodeInfo(episode, for: cacheKey)
        
        print("用户手动选择已保存并覆盖缓存: \(episode.displayTitle)")
        if let shiftDesc = episode.shiftDescription {
            print("弹幕偏移: \(shiftDesc)")
        }
        
        // 异步返回成功
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(.success(true))
        }
    }
    
    /// 更新剧集选择结果的便捷方法（当无法获取videoURL时使用）
    func updateEpisodeSelection(episode: DanDanPlayEpisode, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 使用episodeId作为缓存key的简化版本
        // 这种情况下无法获取到具体的文件信息，只能基于剧集ID缓存
        let cacheKey = "episode_\(episode.episodeId)"
        
        DanDanPlayCache.shared.cacheSearchResult([episode], for: cacheKey)
        DanDanPlayCache.shared.cacheEpisodeInfo(episode, for: cacheKey)
        
        print("用户手动选择已保存: \(episode.displayTitle)")
        if let shiftDesc = episode.shiftDescription {
            print("弹幕偏移: \(shiftDesc)")
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(.success(true))
        }
    }

    /// 加载对应剧集的弹幕数据
    func loadDanmaku(for episode: DanDanPlayEpisode, completion: @escaping (Result<Data, Error>) -> Void) {
        // 先检查缓存
        if let cachedData = DanDanPlayCache.shared.getCachedDanmaku(for: episode.episodeId) {
            completion(.success(cachedData))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/v2/comment/\(episode.episodeId)?from=0&withRelated=true&chConvert=1") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/comment/\(episode.episodeId)"
        guard addAuthenticationHeaders(to: &request, path: path) else {
            completion(.failure(NetworkError.authenticationFailed))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(NetworkError.connectionFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            // 处理302重定向
            if httpResponse.statusCode == 302 {
                if let location = httpResponse.allHeaderFields["Location"] as? String,
                   let redirectURL = URL(string: location) {
                    // 对重定向URL发起新请求
                    var redirectRequest = URLRequest(url: redirectURL)
                    redirectRequest.httpMethod = "GET"
                    redirectRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    self.session.dataTask(with: redirectRequest) { redirectData, redirectResponse, redirectError in
                        if let redirectError = redirectError {
                            completion(.failure(NetworkError.connectionFailed))
                            return
                        }
                        
                        guard let redirectData = redirectData else {
                            completion(.failure(NetworkError.noData))
                            return
                        }
                        
                        // 验证重定向返回的数据格式
                        do {
                            let commentResult = try JSONDecoder().decode(DanDanPlayCommentResult.self, from: redirectData)
                            print("通过重定向成功获取弹幕数据，共 \(commentResult.count) 条弹幕")
                            
                            // 缓存弹幕数据
                            DanDanPlayCache.shared.cacheDanmaku(redirectData, for: episode.episodeId)
                            
                            completion(.success(redirectData))
                        } catch {
                            print("重定向后弹幕数据解析失败: \(error)")
                            completion(.failure(NetworkError.parseError))
                        }
                    }.resume()
                    return
                } else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            // 验证返回的是有效的JSON数据
            do {
                let commentResult = try JSONDecoder().decode(DanDanPlayCommentResult.self, from: data)
                print("成功获取弹幕数据，共 \(commentResult.count) 条弹幕")
                
                // 缓存弹幕数据
                DanDanPlayCache.shared.cacheDanmaku(data, for: episode.episodeId)
                
                completion(.success(data))
            } catch {
                print("弹幕数据解析失败: \(error)")
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }
}

// MARK: - API Response Models

struct DanDanPlaySearchResult: Codable {
    let errorCode: Int          // 错误代码，0表示没有发生错误
    let success: Bool           // 接口是否调用成功
    let errorMessage: String?   // 错误信息，可为空
    let hasMore: Bool           // 是否有更多未显示的搜索结果
    let animes: [SearchEpisodesAnime]? // 搜索结果（作品信息）列表，可为空
}

struct SearchEpisodesAnime: Codable {
    let animeId: Int           // 作品编号
    let animeTitle: String?    // 作品标题，可为空
    let type: String?          // 作品类型，可为空
    let typeDescription: String? // 类型描述，可为空
    let episodes: [SearchEpisodeDetails]? // 此作品的剧集列表，可为空
}

struct SearchEpisodeDetails: Codable {
    let episodeId: Int         // 剧集编号
    let episodeTitle: String?  // 剧集标题，可为空
}

// MARK: - Match API Response Models

struct DanDanPlayMatchResult: Codable {
    let errorCode: Int          // 错误代码，0表示没有发生错误
    let success: Bool           // 接口是否调用成功
    let errorMessage: String?   // 错误信息，可为空
    let isMatched: Bool         // 是否已精确关联到某个弹幕库
    let matches: [MatchResult]? // 搜索匹配的结果，可为空
}

struct MatchResult: Codable {
    let episodeId: Int64        // 弹幕库ID（64位整数）
    let animeId: Int           // 作品ID（32位整数）
    let animeTitle: String?    // 作品标题，可为空
    let episodeTitle: String?  // 剧集标题，可为空
    let type: String?          // 作品类别，可为空
    let typeDescription: String? // 类型描述，可为空
    let shift: Double          // 弹幕偏移时间（秒），负数表示提前出现
    
    /// 获取格式化的偏移时间描述
    var shiftDescription: String {
        if shift == 0 {
            return "无偏移"
        } else if shift > 0 {
            return "延迟 \(String(format: "%.1f", shift)) 秒"
        } else {
            return "提前 \(String(format: "%.1f", abs(shift))) 秒"
        }
    }
}

// MARK: - Comment API Response Models

struct DanDanPlayCommentResult: Codable {
    let count: Int
    let comments: [CommentResult]
}

struct CommentResult: Codable {
    let cid: Int
    let p: String  // 格式: "时间,模式,颜色,用户ID" 例如: "12.34,1,16777215,1234567890"
    let m: String  // 弹幕内容
}

// MARK: - 弹幕参数解析扩展
extension CommentResult {
    /// 解析弹幕参数
    struct DanmakuParams {
        let time: Double        // 出现时间（秒）
        let mode: Int          // 弹幕模式：1-普通，4-底部，5-顶部
        let color: UInt32      // 颜色值（32位整数）
        let userId: String     // 用户ID
        let content: String    // 弹幕内容
    }
    
    /// 解析p参数字符串
    var parsedParams: DanmakuParams? {
        let components = p.components(separatedBy: ",")
        guard components.count >= 4 else { return nil }
        
        guard let time = Double(components[0]),
              let mode = Int(components[1]),
              let color = UInt32(components[2]) else {
            return nil
        }
        
        let userId = components[3]
        
        return DanmakuParams(
            time: time,
            mode: mode,
            color: color,
            userId: userId,
            content: m
        )
    }
    
    /// 将32位颜色值转换为RGB分量
    var rgbColor: (red: UInt8, green: UInt8, blue: UInt8)? {
        guard let params = parsedParams else { return nil }
        
        let color = params.color
        let red = UInt8((color >> 16) & 0xFF)
        let green = UInt8((color >> 8) & 0xFF)
        let blue = UInt8(color & 0xFF)
        
        return (red: red, green: green, blue: blue)
    }
}

extension DanDanPlayAPI {
    /// 根据文件名直接进行剧集识别（用于Jellyfin等媒体服务器）
    func identifyEpisodeByName(_ fileName: String, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) {
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // 先检查缓存
        if let cachedResults = DanDanPlayCache.shared.getCachedSearchResult(for: fileNameWithoutExtension),
           let firstResult = cachedResults.first {
            completion(.success(firstResult))
            return
        }
        
        // 直接使用搜索API
        fallbackToSearch(fileNameWithoutExtension: fileNameWithoutExtension, completion: completion)
    }
    
    /// 获取解析后的弹幕数据
    func loadParsedDanmaku(for episode: DanDanPlayEpisode, completion: @escaping (Result<[CommentResult.DanmakuParams], Error>) -> Void) {
        loadDanmaku(for: episode) { result in
            switch result {
            case .success(let data):
                do {
                    let commentResult = try JSONDecoder().decode(DanDanPlayCommentResult.self, from: data)
                    let parsedComments = commentResult.comments.compactMap { $0.parsedParams }
                    completion(.success(parsedComments))
                } catch {
                    completion(.failure(NetworkError.parseError))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
