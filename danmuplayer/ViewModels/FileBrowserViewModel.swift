/// 文件浏览器逻辑
import Foundation
import Combine

/// 管理WebDAV文件浏览状态和数据
@MainActor
@available(tvOS 17.0, *)
class FileBrowserViewModel: ObservableObject {
    /// 统一获取视频播放URL和字幕URL数组
    func prepareMediaForPlayback(item: WebDAVItem, completion: @escaping (URL, [URL]) -> Void) {
        getVideoStreamingURL(for: item) { result in
            switch result {
            case .success(let videoURL):
                let subtitleItems = self.findSubtitleFiles(for: item)
                let subtitleURLs: [URL] = subtitleItems.compactMap { self.constructWebDAVURL(for: $0) }
                completion(videoURL, subtitleURLs)
            case .failure:
                // 失败时只返回空数组
                completion(URL(string: "")!, [])
            }
        }
    }
    @Published var items: [WebDAVItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingVideoPlayer = false
    @Published var selectedVideoItem: WebDAVItem?

    private let webDAVClient: WebDAVClient
    private var currentPath: String = "/"
    
    var client: WebDAVClient { webDAVClient }
    var currentPathString: String { currentPath }

    init(client: WebDAVClient, path: String = "/") {
        self.webDAVClient = client
        self.currentPath = path
    }

    var currentDirectoryName: String {
        if currentPath == "/" {
            return "根目录"
        }
        return (currentPath as NSString).lastPathComponent
    }

    // MARK: - 加载指定路径目录文件列表
    func loadDirectory(path: String? = nil) {
        isLoading = true
        errorMessage = nil
        if let path = path {
            currentPath = path
        }

        webDAVClient.fetchDirectory(at: currentPath) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let items):
                    // 过滤掉父目录引用，并按目录和文件分组排序
                    let filteredItems = items.filter { !$0.path.hasSuffix("/..") && !$0.name.isEmpty }
                    self.items = self.sortItems(filteredItems, by: .name, isAscending: true)
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - 测试WebDAV连接
    func testWebDAVConnection() {
        isLoading = true
        errorMessage = nil
        
        webDAVClient.testConnection { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(_):
                    // 连接成功，重新加载目录
                    self.loadDirectory()
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - 创建子目录的ViewModel
    func createChildViewModel(for item: WebDAVItem) -> FileBrowserViewModel {
        // 正确构建子目录路径
        let childPath: String
        if currentPath == "/" {
            // 如果当前是根目录，直接使用item的路径
            childPath = item.path
        } else {
            // 否则拼接当前路径和子项路径
            let normalizedCurrentPath = currentPath.hasSuffix("/") ? currentPath : currentPath + "/"
            if item.path.hasPrefix("/") {
                // 如果item.path是绝对路径，直接使用
                childPath = item.path
            } else {
                // 如果是相对路径，进行拼接
                childPath = normalizedCurrentPath + item.path
            }
        }
        
        return FileBrowserViewModel(client: webDAVClient, path: childPath)
    }

    // MARK: - 播放视频文件
    func playVideo(item: WebDAVItem) {
        selectedVideoItem = item
        showingVideoPlayer = true
    }
    

    // MARK: - 获取视频文件的流媒体URL
    func getVideoStreamingURL(for item: WebDAVItem, completion: @escaping (Result<URL, Error>) -> Void) {
        webDAVClient.getStreamingURL(for: item.path, completion: completion)
    }

    func findSubtitleFiles(for videoItem: WebDAVItem) -> [WebDAVItem] {
        let videoBaseName = (videoItem.name as NSString).deletingPathExtension.lowercased()
        let subtitleExtensions = ["srt", "ass", "ssa", "vtt"]
        
        return items.filter { item in
            guard !item.isDirectory else { return false }
            
            let ext = (item.name as NSString).pathExtension.lowercased()
            guard subtitleExtensions.contains(ext) else { return false }
            
            // 取掉扩展名后的部分（可能还包含语言标识）
            let nameWithoutExt = (item.name as NSString).deletingPathExtension.lowercased()
            
            // 取 nameWithoutExt 的第一个段（按 . 切分）
            let firstPart = nameWithoutExt.split(separator: ".").first.map(String.init) ?? nameWithoutExt
            
            return firstPart.contains(videoBaseName)
        }
    }


    // MARK: - 支持文件排序（名称、日期、大小）
    func sortItems(by option: SortOption, isAscending: Bool = true) {
        items = sortItems(items, by: option, isAscending: isAscending)
    }
    
    private func sortItems(_ items: [WebDAVItem], by option: SortOption, isAscending: Bool) -> [WebDAVItem] {
        let directories = items.filter { $0.isDirectory }
        let files = items.filter { !$0.isDirectory }
        
        var sortedDirectories: [WebDAVItem]
        var sortedFiles: [WebDAVItem]
        
        switch option {
        case .name:
            sortedDirectories = directories.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased()
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased()
                return isAscending ? result : !result
            }
        case .date:
            sortedDirectories = directories.sorted { 
                let result = ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast)
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast)
                return isAscending ? result : !result
            }
        case .size:
            sortedDirectories = directories.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased() // 目录按名称排序
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = ($0.size ?? 0) > ($1.size ?? 0)
                return isAscending ? result : !result
            }
        }
        
        return sortedDirectories + sortedFiles
    }
    
    // MARK: - 辅助方法
    
    /// 检查文件是否为视频文件
    private func isVideoFile(_ fileName: String) -> Bool {
        return XMLParserHelper.isVideoFile(fileName: fileName)
    }
    
    /// 从字幕文件列表中选择最佳字幕URL
    private func findBestSubtitleURL(for videoName: String, in subtitleFiles: [WebDAVItem]) -> URL? {
        guard !subtitleFiles.isEmpty else { return nil }
        
        let videoBaseName = videoName.components(separatedBy: ".").first ?? videoName
        
        // 查找匹配的字幕文件
        let matchingSubtitles = subtitleFiles.filter { subtitle in
            let subtitleBaseName = subtitle.name.components(separatedBy: ".").first ?? subtitle.name
            return subtitleBaseName.contains(videoBaseName) || videoBaseName.contains(subtitleBaseName)
        }
        
        // 优先选择中文字幕
        for subtitle in matchingSubtitles {
            let fileName = subtitle.name.lowercased()
            if fileName.contains("zh") || fileName.contains("chinese") || fileName.contains("中文") ||
               fileName.contains("chs") || fileName.contains("cht") {
                return constructWebDAVURL(for: subtitle)
            }
        }
        
        // 如果没有中文字幕，返回第一个匹配的字幕
        if let firstSubtitle = matchingSubtitles.first {
            return constructWebDAVURL(for: firstSubtitle)
        }
        
        return nil
    }
    
    /// 检查是否为字幕文件
    private func isSubtitleFile(_ fileName: String) -> Bool {
        let lowercaseName = fileName.lowercased()
        return lowercaseName.hasSuffix(".srt") || lowercaseName.hasSuffix(".ass") ||
               lowercaseName.hasSuffix(".vtt") || lowercaseName.hasSuffix(".sub")
    }
    
    /// 为WebDAV项目构造完整的URL
    private func constructWebDAVURL(for item: WebDAVItem) -> URL? {
        let baseURL = webDAVClient.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let itemPath = item.path.hasPrefix("/") ? item.path : "/" + item.path
        let fullURLString = baseURL + itemPath
        
        return URL(string: fullURLString)
    }

    enum SortOption {
        case name, date, size
        
        var displayName: String {
            switch self {
            case .name: return "名称"
            case .date: return "日期"
            case .size: return "大小"
            }
        }
        
        var systemImage: String {
            switch self {
            case .name: return "textformat.abc"
            case .date: return "calendar"
            case .size: return "scale.3d"
            }
        }
    }

    @Published var isAscending: Bool = true

    func sortItems(by option: SortOption, isAscending: Bool? = nil) {
        let ascending = isAscending ?? self.isAscending
        switch option {
        case .name:
            items.sort { lhs, rhs in
                let res = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                return ascending ? res : !res
            }
        case .date:
            items.sort { lhs, rhs in
                let l = lhs.modifiedDate ?? Date.distantPast
                let r = rhs.modifiedDate ?? Date.distantPast
                let res = l < r
                return ascending ? res : !res
            }
        case .size:
            items.sort { lhs, rhs in
                let l = lhs.size ?? 0
                let r = rhs.size ?? 0
                let res = l < r
                return ascending ? res : !res
            }
        }
        self.isAscending = ascending
    }
}
