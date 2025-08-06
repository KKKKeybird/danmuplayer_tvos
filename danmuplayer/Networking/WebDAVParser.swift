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
        } else if (currentElement == "collection" || currentElement.contains("collection")) && isParsingResponse {
            // 当遇到collection元素时，标记为目录
            currentIsDirectory = true
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
            case "resourcetype":
                currentResourceType += trimmedString
                // 检查resourcetype内容是否包含collection
                if XMLParserHelper.extractResourceType(from: trimmedString) {
                    currentIsDirectory = true
                }
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.lowercased() == "response" && isParsingResponse {
            // 解析完一个response元素，创建WebDAVItem
            guard !currentHref.isEmpty else { return }
            
            // 使用XMLParserHelper进行路径清理和验证
            let cleanedHref = XMLParserHelper.cleanPath(currentHref)
            let fileName = currentDisplayName.isEmpty ? 
                          XMLParserHelper.extractFileName(from: cleanedHref) : 
                          currentDisplayName
            
            // 验证是否为有效的WebDAV项目
            guard XMLParserHelper.isValidWebDAVItem(href: cleanedHref, displayName: fileName) else {
                isParsingResponse = false
                return
            }
            
            // 解析文件大小
            let size = XMLParserHelper.parseFileSize(currentContentLength)
            
            // 解析修改日期
            let modifiedDate = XMLParserHelper.parseWebDAVDate(currentLastModified)
            
            // 最终检查resourceType是否标记为目录
            if !currentIsDirectory && XMLParserHelper.extractResourceType(from: currentResourceType) {
                currentIsDirectory = true
            }
            
            let item = WebDAVItem(
                name: fileName,
                path: cleanedHref,
                isDirectory: currentIsDirectory,
                size: size,
                modifiedDate: modifiedDate
            )
            
            webDAVItems.append(item)
            isParsingResponse = false
        }
        
        currentElement = ""
    }
}
