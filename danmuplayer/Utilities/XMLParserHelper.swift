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
        let decoded = path.removingPercentEncoding ?? path
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
    
    /// 验证XML元素是否为有效的WebDAV响应项
    static func isValidWebDAVItem(href: String, displayName: String) -> Bool {
        let cleanHref = cleanPath(href)
        let fileName = extractFileName(from: href)
        
        // 过滤掉无效项目
        if cleanHref.isEmpty || fileName.isEmpty {
            return false
        }
        
        // 过滤掉父目录引用
        if fileName == ".." || cleanHref.hasSuffix("/..") {
            return false
        }
        
        // 过滤掉当前目录引用
        if fileName == "." || cleanHref.hasSuffix("/.") {
            return false
        }
        
        return true
    }
    
    /// 解析文件大小字符串
    static func parseFileSize(_ sizeString: String) -> Int64? {
        let trimmed = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return Int64(trimmed)
    }
}
