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
    
    /// 根据视频文件信息调用番剧匹配接口
    func identifySeries(for videoURL: URL, completion: @escaping (Result<DanDanPlaySeries, Error>) -> Void) {
        // 提取文件信息
        guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let fileName = fileInfo.fileName
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // 先检查缓存 - 使用文件hash作为缓存key
        let cacheKey = !fileInfo.fileHash.isEmpty ? fileInfo.fileHash : fileNameWithoutExtension
        if let cachedResults = DanDanPlayCache.shared.getCachedSearchResult(for: cacheKey),
           let firstResult = cachedResults.first {
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
            "videoDuration": 0, // 如果有视频时长信息可以添加
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
                
                if let match = matchResult.matches?.first {
                    let series = DanDanPlaySeries(
                        animeId: match.animeId,
                        animeTitle: match.animeTitle,
                        episodeId: match.episodeId,
                        episodeTitle: match.episodeTitle
                    )
                    
                    // 缓存匹配结果
                    var seriesList = [series]
                    if let matches = matchResult.matches {
                        seriesList = matches.map { match in
                            DanDanPlaySeries(
                                animeId: match.animeId,
                                animeTitle: match.animeTitle,
                                episodeId: match.episodeId,
                                episodeTitle: match.episodeTitle
                            )
                        }
                    }
                    DanDanPlayCache.shared.cacheSearchResult(seriesList, for: cacheKey)
                    
                    completion(.success(series))
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
    private func fallbackToSearch(fileNameWithoutExtension: String, completion: @escaping (Result<DanDanPlaySeries, Error>) -> Void) {
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
                if let firstResult = searchResult.animes.first {
                    // 选择第一个匹配的动画和第一集
                    let series = DanDanPlaySeries(
                        animeId: firstResult.animeId,
                        animeTitle: firstResult.animeTitle,
                        episodeId: firstResult.episodes.first?.episodeId ?? 0,
                        episodeTitle: firstResult.episodes.first?.episodeTitle ?? "第1话"
                    )
                    
                    // 缓存搜索结果
                    var seriesList: [DanDanPlaySeries] = []
                    for anime in searchResult.animes {
                        for episode in anime.episodes {
                            let episodeSeries = DanDanPlaySeries(
                                animeId: anime.animeId,
                                animeTitle: anime.animeTitle,
                                episodeId: episode.episodeId,
                                episodeTitle: episode.episodeTitle
                            )
                            seriesList.append(episodeSeries)
                        }
                    }
                    DanDanPlayCache.shared.cacheSearchResult(seriesList, for: fileNameWithoutExtension)
                    
                    completion(.success(series))
                } else {
                    completion(.failure(NetworkError.notFound))
                }
            } catch {
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }

    /// 获取候选番剧列表供用户选择
    func fetchCandidateSeriesList(for videoURL: URL, completion: @escaping (Result<[DanDanPlaySeries], Error>) -> Void) {
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
            "videoDuration": 0,
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
                    let seriesList = matches.map { match in
                        DanDanPlaySeries(
                            animeId: match.animeId,
                            animeTitle: match.animeTitle,
                            episodeId: match.episodeId,
                            episodeTitle: match.episodeTitle
                        )
                    }
                    
                    // 缓存匹配结果
                    DanDanPlayCache.shared.cacheSearchResult(seriesList, for: cacheKey)
                    completion(.success(seriesList))
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
    private func fallbackToCandidateSearch(fileNameWithoutExtension: String, completion: @escaping (Result<[DanDanPlaySeries], Error>) -> Void) {
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
                var seriesList: [DanDanPlaySeries] = []
                
                for anime in searchResult.animes {
                    for episode in anime.episodes {
                        let series = DanDanPlaySeries(
                            animeId: anime.animeId,
                            animeTitle: anime.animeTitle,
                            episodeId: episode.episodeId,
                            episodeTitle: episode.episodeTitle
                        )
                        seriesList.append(series)
                    }
                }
                
                // 缓存搜索结果
                DanDanPlayCache.shared.cacheSearchResult(seriesList, for: fileNameWithoutExtension)
                
                completion(.success(seriesList))
            } catch {
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }

    /// 更新识别结果，通知弹幕匹配
    func updateSeriesSelection(series: DanDanPlaySeries, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 这个API通常用于用户手动选择后的确认，这里简单返回成功
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            completion(.success(true))
        }
    }

    /// 加载对应番剧的弹幕数据
    func loadDanmaku(for series: DanDanPlaySeries, completion: @escaping (Result<Data, Error>) -> Void) {
        // 先检查缓存
        if let cachedData = DanDanPlayCache.shared.getCachedDanmaku(for: series.episodeId) {
            completion(.success(cachedData))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/v2/comment/\(series.episodeId)?withRelated=true&chConvert=1") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加身份验证头
        let path = "/api/v2/comment/\(series.episodeId)"
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
            
            // 根据文档，弹幕API可能返回302跳转
            if httpResponse.statusCode == 302 {
                // 获取跳转地址
                if let location = httpResponse.allHeaderFields["Location"] as? String,
                   let redirectURL = URL(string: location) {
                    // 对跳转地址发起新请求
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
                        
                        // 缓存弹幕数据
                        DanDanPlayCache.shared.cacheDanmaku(redirectData, for: series.episodeId)
                        
                        completion(.success(redirectData))
                    }.resume()
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
            
            // 缓存弹幕数据
            DanDanPlayCache.shared.cacheDanmaku(data, for: series.episodeId)
            
            completion(.success(data))
        }.resume()
    }
}

// MARK: - API Response Models

struct DanDanPlaySearchResult: Codable {
    let animes: [AnimeResult]
}

struct AnimeResult: Codable {
    let animeId: Int
    let animeTitle: String
    let episodes: [EpisodeResult]
}

struct EpisodeResult: Codable {
    let episodeId: Int
    let episodeTitle: String
}

// MARK: - Match API Response Models

struct DanDanPlayMatchResult: Codable {
    let errorCode: Int
    let success: Bool
    let errorMessage: String?
    let isMatched: Bool
    let matches: [MatchResult]?
}

struct MatchResult: Codable {
    let episodeId: Int
    let animeId: Int
    let animeTitle: String
    let episodeTitle: String
    let type: String?
    let typeDescription: String?
    let shift: Int?
}

// MARK: - Comment API Response Models

struct DanDanPlayCommentResult: Codable {
    let count: Int
    let comments: [CommentResult]
}

struct CommentResult: Codable {
    let cid: Int
    let p: String
    let m: String
}

extension DanDanPlayAPI {
    /// 根据文件名直接进行番剧识别（用于Jellyfin等媒体服务器）
    func identifySeriesByName(_ fileName: String, completion: @escaping (Result<DanDanPlaySeries, Error>) -> Void) {
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
}
