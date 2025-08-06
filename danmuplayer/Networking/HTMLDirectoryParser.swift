/// HTML目录列表解析器
import Foundation

/// 解析HTML格式的目录列表（如Apache httpd的自动索引）
class HTMLDirectoryParser {
    
    /// 解析HTML格式的目录响应
    /// - Parameters:
    ///   - data: HTML数据
    ///   - baseURL: 基础URL
    /// - Returns: WebDAVItem数组
    func parseDirectoryResponse(_ data: Data, baseURL: URL) throws -> [WebDAVItem] {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "HTMLDirectoryParser", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML data"])
        }
        
        print("HTML content preview: \(String(htmlString.prefix(500)))")
        
        var items: [WebDAVItem] = []
        
        // 更灵活的正则表达式，匹配你的HTML格式
        // 匹配格式: <a href="http://192.168.0.111:7654/Anime/">Anime/</a>
        let linkPattern = #"<a\s+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"#
        let regex = try NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive])
        let matches = regex.matches(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.count))
        
        print("Found \(matches.count) matches in HTML")
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let hrefRange = match.range(at: 1)
            let nameRange = match.range(at: 2)
            
            guard let hrefNSRange = Range(hrefRange, in: htmlString),
                  let nameNSRange = Range(nameRange, in: htmlString) else { continue }
            
            let href = String(htmlString[hrefNSRange])
            let name = String(htmlString[nameNSRange])
            
            print("Processing: href='\(href)', name='\(name)'")
            
            // 跳过父目录链接
            if href == "../" || name == "../" || href.contains("../") {
                print("Skipping parent directory link")
                continue
            }
            
            // 跳过无效的链接
            if href.isEmpty || name.isEmpty {
                print("Skipping empty link")
                continue
            }
            
            // 判断是否为目录（根据名称是否以/结尾）
            let isDirectory = name.hasSuffix("/")
            
            // 清理名称，移除末尾的斜杠
            let cleanName = isDirectory ? String(name.dropLast()) : name
            
            // 处理路径：如果href是完整URL，提取相对路径部分
            let relativePath: String
            if href.hasPrefix("http") {
                // 从完整URL中提取路径部分
                if let url = URL(string: href) {
                    relativePath = url.path
                } else {
                    relativePath = href
                }
            } else {
                relativePath = href
            }
            
            // 尝试解析文件大小和修改日期（从HTML表格行中）
            let (size, modifiedDate) = extractFileInfo(for: href, name: name, from: htmlString)
            
            let item = WebDAVItem(
                name: cleanName,
                path: relativePath,
                isDirectory: isDirectory,
                size: size,
                modifiedDate: modifiedDate
            )
            
            print("Created item: \(item)")
            items.append(item)
        }
        
        print("Total items parsed: \(items.count)")
        return items
    }
    
    /// 从HTML中提取文件信息（大小和修改日期）
    private func extractFileInfo(for href: String, name: String, from html: String) -> (size: Int64?, modifiedDate: Date?) {
        // 查找包含该链接的整行
        let lines = html.components(separatedBy: .newlines)
        for line in lines {
            if line.contains(href) || line.contains(name) {
                print("Analyzing line: \(line)")
                
                // 解析修改日期（格式：19-Mar-2025 14:43）
                let modifiedDate = extractModifiedDate(from: line)
                
                // 对于目录，通常没有大小信息
                let size: Int64? = nil
                
                return (size: size, modifiedDate: modifiedDate)
            }
        }
        return (size: nil, modifiedDate: nil)
    }
    
    /// 从HTML行中提取修改日期
    private func extractModifiedDate(from line: String) -> Date? {
        // 匹配日期模式：19-Mar-2025 14:43
        let datePattern = #"(\d{1,2}-\w{3}-\d{4}\s+\d{2}:\d{2})"#
        if let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) {
            let matches = dateRegex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: line) {
                    let dateString = String(line[range])
                    print("Found date string: \(dateString)")
                    return parseHTMLDate(dateString)
                }
            }
        }
        return nil
    }
    
    /// 解析HTML中的日期格式 (如: "19-Mar-2025 14:43")
    private func parseHTMLDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
}
