/// WebDAV文件/文件夹模型
import Foundation

/// 表示WebDAV文件或文件夹
struct WebDAVItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?
    
    static func == (lhs: WebDAVItem, rhs: WebDAVItem) -> Bool {
        return lhs.path == rhs.path && 
               lhs.name == rhs.name && 
               lhs.isDirectory == rhs.isDirectory
    }
}
