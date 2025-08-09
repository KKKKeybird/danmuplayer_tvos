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
    
    // MARK: - 剧集匹配
    /// 自动识别剧集（返回最佳匹配结果）
    /// - Parameters:
    ///   - videoURL: 视频源URL（本地或远程）
    ///   - overrideFileName: 当URL无法提供有效文件名（如流媒体）时，使用此原始文件名参与匹配
    func identifyEpisode(for videoURL: URL, overrideFileName: String? = nil, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) {
        // 先检查缓存（如果用户之前手动选择过，缓存中就是用户选择的结果）
        let cacheKey = videoURL
        if let cachedResult = DanDanPlayCache.shared.getCachedEpisodeInfo(for: cacheKey) {
            print("📦 使用缓存的剧集: \(cachedResult.displayTitle)")
            completion(.success(cachedResult))
            return
        }

        // 在后台线程提取文件信息（远程直链可计算真实hash）
        DispatchQueue.global(qos: .userInitiated).async {
            guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            let rawName = overrideFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = (rawName?.isEmpty == false ? rawName! : fileInfo.fileName)
            let fileName = self.sanitizeFileName(fallbackName)

            // 构建匹配请求
            guard let url = URL(string: "\(self.baseURL)/api/v2/match") else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // 添加身份验证头
            let path = "/api/v2/match"
            guard self.addAuthenticationHeaders(to: &request, path: path) else {
                completion(.failure(NetworkError.authenticationFailed))
                return
            }

            // 构建请求体（根据可用信息自适应）
            var requestBody: [String: Any] = [
                "fileName": fileName,
                "videoDuration": max(0, Int(fileInfo.videoDuration.rounded()))
            ]
            let hasHash = !fileInfo.fileHash.isEmpty && fileInfo.fileHash.count == 32
            let hasSize = fileInfo.fileSize > 0
            if hasHash { requestBody["fileHash"] = fileInfo.fileHash }
            if hasSize { requestBody["fileSize"] = fileInfo.fileSize }
            requestBody["matchMode"] = (hasHash && hasSize) ? "hashAndFileName" : "fileNameOnly"
            print(requestBody)

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            } catch {
                completion(.failure(NetworkError.parseError))
                return
            }
            if let body = try? JSONSerialization.data(withJSONObject: requestBody),
               let bodyString = String(data: body, encoding: .utf8) {
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("Match 请求体: \(bodyString)")
                }
            }

            self.session.dataTask(with: request) { data, response, error in
            if error != nil {
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
                    completion(.failure(NetworkError.serverError(matchResult.errorCode)))
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
                    
                    DanDanPlayCache.shared.cacheEpisodeInfo(episode, for: videoURL)
                    
                    completion(.success(episode))
                } else {
                    // 如果匹配失败，回退到搜索API
                    completion(.failure(NetworkError.notFound))
                    return
                }
            } catch {
                completion(.failure(NetworkError.parseError))
                return
            }
        }.resume()
        }
    }


    // MARK: - 剧集候选列表搜索
    /// 获取候选剧集列表供用户手动选择
    func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void) {
        // 在后台线程提取文件信息（远程直链可计算真实hash）
        DispatchQueue.global(qos: .userInitiated).async {
            guard let fileInfo = FileInfoExtractor.extractFileInfo(from: videoURL) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            let fileName = self.sanitizeFileName(fileInfo.fileName)

            // 先尝试文件匹配
            guard let url = URL(string: "\(self.baseURL)/api/v2/match") else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // 添加身份验证头
            let path = "/api/v2/match"
            guard self.addAuthenticationHeaders(to: &request, path: path) else {
                completion(.failure(NetworkError.authenticationFailed))
                return
            }

            // 构建请求体（自适应：远程直链可能没有文件大小）
            var requestBody: [String: Any] = [
                "fileName": fileName,
                "videoDuration": max(0, Int(fileInfo.videoDuration.rounded()))
            ]
            let hasHash = !fileInfo.fileHash.isEmpty && fileInfo.fileHash.count == 32
            let hasSize = fileInfo.fileSize > 0
            if hasHash { requestBody["fileHash"] = fileInfo.fileHash }
            if hasSize { requestBody["fileSize"] = fileInfo.fileSize }
            requestBody["matchMode"] = (hasHash && hasSize) ? "hashAndFileName" : "fileNameOnly"

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            } catch {
                completion(.failure(NetworkError.parseError))
                return
            }
            if let body = try? JSONSerialization.data(withJSONObject: requestBody),
               let bodyString = String(data: body, encoding: .utf8) {
                DispatchQueue.main.async {
                    DanmakuDebugLogger.shared.add("候选列表 请求体: \(bodyString)")
                }
            }

            self.session.dataTask(with: request) { data, response, error in
            if error != nil {
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
                    completion(.failure(NetworkError.serverError(matchResult.errorCode)))
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
                    
                    completion(.success(episodeList))
                } else {
                    completion(.failure(NetworkError.notFound))
                    return
                }
            } catch {
                completion(.failure(NetworkError.parseError))
                return
            }
        }.resume()
        }
    }


    // MARK: - 加载ASS弹幕
    /// 加载弹幕并转换为ASS格式（新版简化API）
    func loadDanmakuAsASS(for episode: DanDanPlayEpisode, completion: @escaping (Result<String, Error>) -> Void) {
        // 先检查ASS缓存
        if let cachedASS = DanDanPlayCache.shared.getCachedASSSubtitle(for: episode.episodeId) {
            completion(.success(cachedASS))
            return
        }
        
        // 加载原始弹幕数据
        loadDanmaku(for: episode) { result in
            switch result {
            case .success(let data):
                do {
                    // 解析弹幕数据
                    let commentResult = try JSONDecoder().decode(DanDanPlayCommentResult.self, from: data)
                    let comments = commentResult.comments ?? []
                    let danmakuParams = comments.compactMap { $0.parsedParams }
                    let danmakuComments = danmakuParams.map { params in
                        DanmakuComment(
                            time: params.time,
                            mode: params.mode,
                            fontSize: 25, // 默认字体大小
                            colorValue: Int(params.color),
                            timestamp: params.time,
                            content: params.content
                        )
                    }
                    // 转换为ASS格式
                    let assContent = DanmakuToSubtitleConverter.convertToASS(danmakuComments, videoWidth: 1920, videoHeight: 1080)
                    
                    // 缓存ASS内容
                    DanDanPlayCache.shared.cacheASSSubtitle(assContent, for: episode.episodeId)
                    
                    completion(.success(assContent))
                    
                } catch {
                    completion(.failure(NetworkError.parseError))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 加载对应剧集的弹幕数据
    private func loadDanmaku(for episode: DanDanPlayEpisode, completion: @escaping (Result<Data, Error>) -> Void) {
        
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
                
                completion(.success(data))
            } catch {
                print("弹幕数据解析失败: \(error)")
                completion(.failure(NetworkError.parseError))
            }
        }.resume()
    }
}

// MARK: - 文件名清洗
extension DanDanPlayAPI {
    /// 去除无关标签，保留番名+集数等关键信息，提升匹配成功率
    fileprivate func sanitizeFileName(_ name: String) -> String {
        var s = name
        // 去除路径
        if let last = s.components(separatedBy: "/").last { s = last }
        // 去除扩展名
        if let dot = s.lastIndex(of: ".") { s = String(s[..<dot]) }
        // 去除中括号/小括号/大括号内的内容（字幕组、语言、分辨率等）
        let patterns = ["\\[.*?\\]", "\\(.*?\\)", "\\{.*?\\}"]
        for p in patterns {
            s = s.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        // 去除常见画质/编码标签
        let tokens = ["1080p","720p","2160p","4k","x264","x265","hevc","avc","hdr","webrip","web-dl","bluray","dvdrip","aac","ac3","flac","chs","cht","big5","gb","eng","chinese","multi"]
        for t in tokens { s = s.replacingOccurrences(of: t, with: " ", options: .caseInsensitive) }
        // 将分隔符替换为空格
        s = s.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        // 合并多余空白
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            DanmakuDebugLogger.shared.add("清洗文件名: \(name) -> \(s)")
        }
        return s.isEmpty ? name : s
    }
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
}

// MARK: - Comment API Response Models

/// 弹幕API响应结果
struct DanDanPlayCommentResult: Codable {
    let count: Int32              // 弹幕数量
    let comments: [CommentData]?  // 弹幕列表，可为null
}

/// 弹幕数据
struct CommentData: Codable {
    let cid: Int64      // 弹幕ID（64位整数）
    let p: String?      // 弹幕参数（出现时间,模式,颜色,用户ID），可为null
    let m: String?      // 弹幕内容，可为null

    /// 解析的弹幕参数
    struct DanmakuParams {
        let cid: Int64         // 弹幕ID
        let time: Double       // 出现时间（秒）
        let mode: Int          // 弹幕模式：1-普通，4-底部，5-顶部
        let color: UInt32      // 颜色值（32位整数）
        let userId: String     // 用户ID
        let content: String    // 弹幕内容
    }
    
    /// 解析p参数字符串
    var parsedParams: DanmakuParams? {
        // 检查必要的字段
        guard let pString = p, let content = m else { 
            return nil 
        }
        
        let components = pString.components(separatedBy: ",")
        guard components.count >= 4 else { return nil }
        
        guard let time = Double(components[0]),
              let mode = Int(components[1]),
              let color = UInt32(components[2]) else {
            return nil
        }
        
        let userId = components[3]
        
        return DanmakuParams(
            cid: cid,
            time: time,
            mode: mode,
            color: color,
            userId: userId,
            content: content
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
