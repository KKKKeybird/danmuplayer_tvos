/// XML解析辅助工具
import Foundation

/// XML解析辅助工具
class XMLParserHelper {
    
    /// 从WebDAV PROPFIND响应中提取资源类型
    static func extractResourceType(from xmlString: String) -> Bool {
        return xmlString.lowercased().contains("collection") || 
               xmlString.lowercased().contains("<d:collection") ||
               xmlString.lowercased().contains("<collection")
    }
    
    /// 解析WebDAV日期格式
    static func parseWebDAVDate(_ dateString: String) -> Date? {
        let formatters = [
            "EEE, dd MMM yyyy HH:mm:ss zzz", // RFC 1123
            "yyyy-MM-dd'T'HH:mm:ss'Z'",      // ISO 8601
            "yyyy-MM-dd'T'HH:mm:ssZ",        // ISO 8601 with timezone
            "yyyy-MM-dd HH:mm:ss"            // Simple format
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// 清理和解码URL路径
    static func cleanPath(_ path: String) -> String {
        var cleanedPath = path
        
        // 如果是完整URL，提取路径部分
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            if let url = URL(string: path) {
                cleanedPath = url.path
            }
        }
        
        let decoded = cleanedPath.removingPercentEncoding ?? cleanedPath
        // 移除多余的斜杠
        let cleaned = decoded.replacingOccurrences(of: "//+", with: "/", options: .regularExpression)
        return cleaned
    }
    
    /// 从href路径中提取文件名
    static func extractFileName(from href: String) -> String {
        let cleanedPath = cleanPath(href)
        let url = URL(fileURLWithPath: cleanedPath)
        let fileName = url.lastPathComponent
        
        // 如果文件名为空或只是路径分隔符，返回路径的最后部分
        if fileName.isEmpty || fileName == "/" {
            let components = cleanedPath.components(separatedBy: "/").filter { !$0.isEmpty }
            return components.last ?? ""
        }
        
        return fileName
    }
    
    /// 验证XML元素是否为有效的WebDAV响应项（只保留目录和视频文件）
    static func isValidWebDAVItem(href: String, displayName: String, isDirectory: Bool = false) -> Bool {
        let cleanHref = cleanPath(href)
        let fileName = extractFileName(from: href)
        
        print("XMLParserHelper: Validating item - href: '\(href)', clean: '\(cleanHref)', fileName: '\(fileName)', displayName: '\(displayName)', isDirectory: \(isDirectory)")
        
        // 过滤掉无效项目
        if cleanHref.isEmpty {
            print("XMLParserHelper: Rejected - empty href")
            return false
        }
        
        // 过滤掉父目录引用
        if fileName == ".." || cleanHref.hasSuffix("/..") {
            print("XMLParserHelper: Rejected - parent directory reference")
            return false
        }
        
        // 过滤掉当前目录引用
        if fileName == "." || cleanHref.hasSuffix("/.") {
            print("XMLParserHelper: Rejected - current directory reference")
            return false
        }
        
        // 过滤掉当前请求的目录本身（根目录）
        // 当fileName为空时，通常表示这是当前目录，不应该显示
        if fileName.isEmpty {
            print("XMLParserHelper: Rejected - current directory (empty fileName)")
            return false
        }
        
        // 过滤掉displayName也为空的无效项
        if displayName.isEmpty {
            print("XMLParserHelper: Rejected - empty displayName")
            return false
        }
        
        // 如果是目录，直接接受
        if isDirectory {
            print("XMLParserHelper: Accepted directory")
            return true
        }
        
        // 如果是文件，检查是否为视频文件
        if isVideoFile(fileName: fileName) {
            print("XMLParserHelper: Accepted video file")
            return true
        } else {
            print("XMLParserHelper: Rejected - not a video file")
            return false
        }
    }
    
    /// 检查文件是否为视频文件
    static func isVideoFile(fileName: String) -> Bool {
        let videoExtensions: Set<String> = [
            // 最常见的视频格式
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
            // 高清和蓝光格式
            "ts", "m2ts", "mts", "vob", "iso", "bdmv",
            // 经典格式
            "3gp", "asf", "rm", "rmvb", "ogv", "divx", "xvid",
            // Apple 格式
            "m4v", "qt",
            // 流媒体格式
            "m3u8", "mpd", "f4v",
            // 其他视频容器
            "mpg", "mpeg", "mp2", "mpe", "mpv", "m2v",
            "dat", "dv", "nsv", "mxf", "gxf",
            // 新兴格式
            "hevc", "x265", "av1"
        ]
        
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let isVideo = videoExtensions.contains(fileExtension)
        
        if isVideo {
            print("XMLParserHelper: '\(fileName)' identified as video file (extension: .\(fileExtension))")
        }
        
        return isVideo
    }
    
    /// 解析文件大小字符串
    static func parseFileSize(_ sizeString: String) -> Int64? {
        let trimmed = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return Int64(trimmed)
    }
    
    /// 获取支持的视频文件扩展名列表（用于调试或UI显示）
    static func getSupportedVideoExtensions() -> [String] {
        return [
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
            "ts", "m2ts", "mts", "vob", "iso", "bdmv",
            "3gp", "asf", "rm", "rmvb", "ogv", "divx", "xvid",
            "qt", "m3u8", "mpd", "f4v",
            "mpg", "mpeg", "mp2", "mpe", "mpv", "m2v",
            "dat", "dv", "nsv", "mxf", "gxf",
            "hevc", "x265", "av1"
        ].sorted()
    }
}
