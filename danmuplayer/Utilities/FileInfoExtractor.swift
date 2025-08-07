import Foundation
import CryptoKit
import AVFoundation

/// 文件信息提取工具，用于DanDanPlay API的文件识别
struct FileInfoExtractor {
    
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
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { fileHandle.closeFile() }
        
        // 读取前16MB的数据
        let chunkSize = 16 * 1024 * 1024 // 16MB
        let data = fileHandle.readData(ofLength: chunkSize)
        
        guard !data.isEmpty else {
            return nil
        }
        
        // 计算MD5哈希
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 获取文件大小
    static func getFileSize(for url: URL) -> Int64? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return nil
        }
    }
    
    /// 获取视频时长
    static func getVideoDuration(for url: URL) -> Double? {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        
        guard duration.isValid && !duration.isIndefinite else {
            return nil
        }
        
        return CMTimeGetSeconds(duration)
    }
    
    /// 提取文件的完整匹配信息
    static func extractFileInfo(from url: URL) -> FileMatchInfo? {
        let fileName = url.lastPathComponent
        
        guard let fileHash = calculateFileHash(for: url),
              let fileSize = getFileSize(for: url) else {
            // 如果无法计算hash或大小，至少返回文件名和视频时长信息
            let videoDuration = getVideoDuration(for: url) ?? 0
            return FileMatchInfo(
                fileName: fileName,
                fileHash: "",
                fileSize: 0,
                videoDuration: videoDuration
            )
        }
        
        // 获取视频时长
        let videoDuration = getVideoDuration(for: url) ?? 0
        
        return FileMatchInfo(
            fileName: fileName,
            fileHash: fileHash,
            fileSize: fileSize,
            videoDuration: videoDuration
        )
    }
}
