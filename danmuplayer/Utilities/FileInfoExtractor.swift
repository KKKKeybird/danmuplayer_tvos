import Foundation
import CryptoKit
import AVFoundation

/// 文件信息提取工具，用于DanDanPlay API的文件识别
struct FileInfoExtractor {
    /// 生成32位占位hash（十六进制字符）
    private static func generatePlaceholderHash() -> String {
        let hexChars = Array("0123456789abcdef")
        var result = String()
        result.reserveCapacity(32)
        for _ in 0..<32 {
            if let random = hexChars.randomElement() {
                result.append(random)
            }
        }
        return result
    }
    
    /// 文件匹配信息
    struct FileMatchInfo {
        let fileName: String
        let fileHash: String
        let fileSize: Int64
        let videoDuration: Double // 视频时长（秒）
    }
    
    /// 计算文件的MD5哈希值
    /// DanDanPlay API要求使用文件前16MB的MD5哈希
    static func calculateFileHash(for url: URL) -> String? {
        // 本地文件：直接读取前16MB计算MD5
        if url.isFileURL {
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
                return generatePlaceholderHash()
            }
            defer { fileHandle.closeFile() }
            let chunkSize = 16 * 1024 * 1024 // 16MB
            let data = fileHandle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return generatePlaceholderHash() }
            let hash = Insecure.MD5.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        }

        // 远程直链：避免主线程网络阻塞，主线程返回占位值；后台线程尝试Range获取前16MB计算MD5
        guard url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
            return generatePlaceholderHash()
        }
        if Thread.isMainThread {
            return generatePlaceholderHash()
        }
        if let data = fetchRemoteHeadChunk(url: url, maxBytes: 16 * 1024 * 1024, timeout: 5) {
            let hash = Insecure.MD5.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return generatePlaceholderHash()
    }
    
    /// 获取文件大小
    static func getFileSize(for url: URL) -> Int64? {
        // 仅对本地文件读取大小
        guard url.isFileURL else { return 0 }
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    /// 获取视频时长（秒）- 使用 AVFoundation 新异步API，并做同步桥接，兼容调用方
    static func getVideoDuration(for url: URL) -> Double? {
        // 优先尝试精确加载，适配远程直链
        let asset: AVURLAsset
        if url.isFileURL {
            asset = AVURLAsset(url: url)
        } else {
            asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        }

        // 避免在主线程对远程资源进行同步等待，直接返回nil，防止UI卡顿
        if Thread.isMainThread && !url.isFileURL {
            return nil
        }

        // 使用新的异步属性加载，并通过信号量桥接为同步，设置超时保护
        let semaphore = DispatchSemaphore(value: 0)
        var loadedSeconds: Double?

        Task {
            do {
                let duration = try await asset.load(.duration)
                if duration.isValid && !duration.isIndefinite {
                    loadedSeconds = CMTimeGetSeconds(duration)
                }
            } catch {
                // 忽略错误，保持 nil 以便后续兜底
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 5)
        if let loadedSeconds { return loadedSeconds }

        // 兜底：返回 nil（调用方自行处理缺省值）
        return nil
    }
    
    /// 提取文件的完整匹配信息
    static func extractFileInfo(from url: URL) -> FileMatchInfo? {
        let fileName = extractFileName(from: url)

        if url.isFileURL {
            // 本地文件：计算前16MB MD5以及真实文件大小
            guard let fileHash = calculateFileHash(for: url),
                  let fileSize = getFileSize(for: url) else {
                let videoDuration = getVideoDuration(for: url) ?? 0
                return FileMatchInfo(
                    fileName: fileName,
                    fileHash: generatePlaceholderHash(),
                    fileSize: 0,
                    videoDuration: videoDuration
                )
            }
            let videoDuration = getVideoDuration(for: url) ?? 0
            return FileMatchInfo(
                fileName: fileName,
                fileHash: fileHash,
                fileSize: fileSize,
                videoDuration: videoDuration
            )
        } else {
            // 远程直链：使用占位hash；尝试通过HEAD获取Content-Length；尽力获取视频时长
            let placeholderHash = generatePlaceholderHash()
            let remoteSize = getRemoteFileSize(for: url) ?? 0
            let videoDuration = getVideoDuration(for: url) ?? 0
            return FileMatchInfo(
                fileName: fileName,
                fileHash: placeholderHash,
                fileSize: remoteSize,
                videoDuration: videoDuration
            )
        }
    }

    /// 远程直链尝试通过HEAD获取文件大小
    private static func getRemoteFileSize(for url: URL) -> Int64? {
        guard url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
            return nil
        }
        // 避免在主线程进行同步等待，防止UI卡顿
        if Thread.isMainThread { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        let semaphore = DispatchSemaphore(value: 0)
        var contentLength: Int64?

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                if let lengthString = http.allHeaderFields["Content-Length"] as? String,
                   let length = Int64(lengthString) {
                    contentLength = length
                }
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 5)
        return contentLength
    }

    /// 远程直链抓取前 maxBytes 字节数据（Range 请求），仅在非主线程调用
    private static func fetchRemoteHeadChunk(url: URL, maxBytes: Int, timeout: TimeInterval) -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-\(maxBytes - 1)", forHTTPHeaderField: "Range")
        request.timeoutInterval = timeout

        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?

        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (http.statusCode == 206 || http.statusCode == 200), let data = data {
                resultData = data.prefix(maxBytes)
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout)
        return resultData
    }

    /// 更鲁棒的文件名提取（适配远程直链与带查询参数的URL）
    private static func extractFileName(from url: URL) -> String {
        // 优先使用路径最后一段
        var name = url.lastPathComponent
        if let decoded = name.removingPercentEncoding { name = decoded }

        // 移除常见的查询参数干扰
        if name.isEmpty || !name.contains(".") {
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                let candidates = ["filename", "file", "name", "title"]
                for key in candidates {
                    if let value = queryItems.first(where: { $0.name.lowercased() == key })?.value,
                       !value.isEmpty {
                        name = value.removingPercentEncoding ?? value
                        break
                    }
                }
            }
        }

        // 兜底：使用host
        if name.isEmpty { name = url.lastPathComponent.isEmpty ? (url.host ?? "video") : url.lastPathComponent }
        return name
    }
}
