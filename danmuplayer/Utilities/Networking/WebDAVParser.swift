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
    
    // MARK: - 解析XML数据
    /// - Parameters:
    ///   - data: XML数据
    ///   - currentPath: 当前请求的目录路径（用于过滤掉自身）
    /// - Returns: WebDAVItem数组
    func parseDirectoryResponse(_ data: Data, currentPath: String) throws -> [WebDAVItem] {
        webDAVItems.removeAll()
        
        print("WebDAV Parser: Starting XML parsing")
        print("WebDAV Parser: Data size: \(data.count) bytes")
        
        if let xmlString = String(data: data, encoding: .utf8) {
            let preview = String(xmlString.prefix(2000))
            print("WebDAV Parser: XML preview: \(preview)")
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            print("WebDAV Parser: XML parsing failed")
            throw NSError(domain: "WebDAVParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])
        }
        
        print("WebDAV Parser: XML parsing completed, found \(webDAVItems.count) items (before filtering)")
        for (index, item) in webDAVItems.enumerated() {
            print("WebDAV Parser: Item \(index): '\(item.name)' at '\(item.path)' (dir: \(item.isDirectory))")
        }
        // 过滤掉当前目录本身
        let filtered = webDAVItems.filter { $0.path != currentPath && $0.path != (currentPath.hasSuffix("/") ? String(currentPath.dropLast()) : currentPath + "/") }
        print("WebDAV Parser: Filtered items, final count: \(filtered.count)")
        return filtered
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // 移除命名空间前缀，只保留元素名称
        let localName = elementName.contains(":") ? String(elementName.split(separator: ":").last!) : elementName
        currentElement = localName.lowercased()
        
        print("WebDAV Parser: didStartElement - elementName: '\(elementName)', localName: '\(localName)', currentElement: '\(currentElement)'")
        
        if currentElement == "response" {
            isParsingResponse = true
            // 重置当前解析状态
            currentHref = ""
            currentDisplayName = ""
            currentContentLength = ""
            currentLastModified = ""
            currentResourceType = ""
            currentIsDirectory = false
            print("WebDAV Parser: Started new response element")
        } else if (currentElement == "collection" || currentElement.contains("collection")) && isParsingResponse {
            // 当遇到collection元素时，标记为目录
            currentIsDirectory = true
            print("WebDAV Parser: Found collection element, marking as directory")
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isParsingResponse && !trimmedString.isEmpty {
            switch currentElement {
            case "href":
                currentHref += trimmedString
                print("WebDAV Parser: Found href: '\(trimmedString)'")
            case "displayname":
                currentDisplayName += trimmedString
                print("WebDAV Parser: Found displayName: '\(trimmedString)'")
            case "getcontentlength":
                currentContentLength += trimmedString
                print("WebDAV Parser: Found contentLength: '\(trimmedString)'")
            case "getlastmodified":
                currentLastModified += trimmedString
                print("WebDAV Parser: Found lastModified: '\(trimmedString)'")
            case "collection":
                currentIsDirectory = true
                print("WebDAV Parser: Found collection in characters")
            case "resourcetype":
                currentResourceType += trimmedString
                print("WebDAV Parser: Found resourceType: '\(trimmedString)'")
                // 检查resourcetype内容是否包含collection
                if XMLParserHelper.extractResourceType(from: trimmedString) {
                    currentIsDirectory = true
                    print("WebDAV Parser: ResourceType indicates directory")
                }
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // 移除命名空间前缀，只保留元素名称
        let localName = elementName.contains(":") ? String(elementName.split(separator: ":").last!) : elementName
        
        print("WebDAV Parser: didEndElement - elementName: '\(elementName)', localName: '\(localName)'")
        
        if localName.lowercased() == "response" && isParsingResponse {
            // 解析完一个response元素，创建WebDAVItem
            guard !currentHref.isEmpty else { 
                print("WebDAV Parser: Empty href, skipping item")
                isParsingResponse = false
                return 
            }
            
            // 使用XMLParserHelper进行路径清理和验证
            let cleanedHref = XMLParserHelper.cleanPath(currentHref)
            let fileName = currentDisplayName.isEmpty ? 
                          XMLParserHelper.extractFileName(from: cleanedHref) : 
                          currentDisplayName
            
            print("WebDAV Parser: Processing item - href: '\(currentHref)', cleaned: '\(cleanedHref)', name: '\(fileName)'")
            
            // 最终检查resourceType是否标记为目录
            if !currentIsDirectory && XMLParserHelper.extractResourceType(from: currentResourceType) {
                currentIsDirectory = true
            }
            
            // 验证是否为有效的WebDAV项目（只保留目录和视频文件）
            guard XMLParserHelper.isValidWebDAVItem(href: cleanedHref, displayName: fileName, isDirectory: currentIsDirectory) else {
                print("WebDAV Parser: Invalid WebDAV item, skipping: '\(cleanedHref)'")
                isParsingResponse = false
                return
            }
            
            // 解析文件大小
            let size = XMLParserHelper.parseFileSize(currentContentLength)
            
            // 解析修改日期
            let modifiedDate = XMLParserHelper.parseWebDAVDate(currentLastModified)
            
            print("WebDAV Parser: Creating item - name: '\(fileName)', path: '\(cleanedHref)', isDirectory: \(currentIsDirectory)")
            
            let item = WebDAVItem(
                name: fileName,
                path: cleanedHref,
                isDirectory: currentIsDirectory,
                size: size,
                modifiedDate: modifiedDate
            )
            
            webDAVItems.append(item)
            print("WebDAV Parser: Added item, total count: \(webDAVItems.count)")
            isParsingResponse = false
        }
        
        currentElement = ""
    }
}
