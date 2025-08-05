/// 解析XML响应
import Foundation

/// 解析WebDAV PROPFIND返回的XML，构建文件/文件夹列表
class WebDAVParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentHref = ""
    private var currentDisplayName = ""
    private var currentContentLength = ""
    private var currentLastModified = ""
    private var currentResourceType = ""
    private var currentIsDirectory = false
    private var webDAVItems: [WebDAVItem] = []
    private var isParsingResponse = false
    
    /// 解析XML数据
    /// - Parameter data: XML数据
    /// - Returns: WebDAVItem数组
    func parseDirectoryResponse(_ data: Data) throws -> [WebDAVItem] {
        webDAVItems.removeAll()
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw NSError(domain: "WebDAVParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])
        }
        
        return webDAVItems
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        
        if currentElement == "response" {
            isParsingResponse = true
            // 重置当前解析状态
            currentHref = ""
            currentDisplayName = ""
            currentContentLength = ""
            currentLastModified = ""
            currentResourceType = ""
            currentIsDirectory = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isParsingResponse && !trimmedString.isEmpty {
            switch currentElement {
            case "href":
                currentHref += trimmedString
            case "displayname":
                currentDisplayName += trimmedString
            case "getcontentlength":
                currentContentLength += trimmedString
            case "getlastmodified":
                currentLastModified += trimmedString
            case "collection":
                currentIsDirectory = true
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.lowercased() == "response" && isParsingResponse {
            // 解析完一个response元素，创建WebDAVItem
            guard !currentHref.isEmpty else { return }
            
            // 从href中提取文件名和路径
            let decodedHref = currentHref.removingPercentEncoding ?? currentHref
            let name = currentDisplayName.isEmpty ? URL(fileURLWithPath: decodedHref).lastPathComponent : currentDisplayName
            
            // 解析文件大小
            let size = Int64(currentContentLength)
            
            // 解析修改日期
            var modifiedDate: Date?
            if !currentLastModified.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                modifiedDate = formatter.date(from: currentLastModified)
            }
            
            let item = WebDAVItem(
                name: name,
                path: decodedHref,
                isDirectory: currentIsDirectory,
                size: size,
                modifiedDate: modifiedDate
            )
            
            // 过滤掉父目录本身
            if !decodedHref.hasSuffix("/") || name != "" {
                webDAVItems.append(item)
            }
            
            isParsingResponse = false
        }
        
        currentElement = ""
    }
}
