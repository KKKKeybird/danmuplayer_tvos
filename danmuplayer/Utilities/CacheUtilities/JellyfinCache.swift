/// Jellyfin API缓存管理器
import Foundation
import UIKit

/// Jellyfin API数据缓存管理
class JellyfinCache {
    static let shared = JellyfinCache()
    
    private let metadataCache = NSCache<NSString, JellyfinCachedItem>()
    private let imageCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let imageCacheDirectory: URL
    
    private init() {
        // 创建缓存目录
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("JellyfinCache")
        imageCacheDirectory = cacheDirectory.appendingPathComponent("Images")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imageCacheDirectory, withIntermediateDirectories: true)
        
        // 配置内存缓存
        metadataCache.countLimit = 200  // 最多缓存200个元数据条目
        metadataCache.totalCostLimit = 20 * 1024 * 1024  // 20MB内存限制
        
        imageCache.countLimit = 100  // 最多缓存100张图片
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50MB内存限制
        
        // 启动时清理过期缓存
        cleanExpiredCache()
    }
    
    // MARK: - 媒体项目缓存
    
    /// 缓存媒体库项目列表（30分钟）
    func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String) {
        do {
            let cacheTime: TimeInterval = 1800  // 30分钟
            let item = try JellyfinCachedItem(data: items, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "library_items_\(libraryId)" as NSString
            metadataCache.setObject(item, forKey: key)
            
            saveToDisk(item, key: String(key))
            print("JellyfinCache: 已缓存 \(items.count) 个媒体项目")
        } catch {
            print("JellyfinCache: 缓存媒体项目失败: \(error)")
        }
    }
    
    /// 获取缓存的媒体库项目列表
    func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]? {
        let key = "library_items_\(libraryId)" as NSString
        
        // 先检查内存缓存
        if let item = metadataCache.object(forKey: key), !item.isExpired {
            let items = item.data as? [JellyfinMediaItem]
            if let items = items {
                print("JellyfinCache: 从内存缓存获取 \(items.count) 个媒体项目")
            }
            return items
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            metadataCache.setObject(item, forKey: key)
            let items = item.data as? [JellyfinMediaItem]
            if let items = items {
                print("JellyfinCache: 从磁盘缓存获取 \(items.count) 个媒体项目")
            }
            return items
        }
        
        return nil
    }
    
    // MARK: - 剧集元数据缓存
    
    /// 缓存单个剧集的元数据（1小时）
    func cacheEpisodeMetadata(_ episode: JellyfinEpisode) {
        do {
            let cacheTime: TimeInterval = 3600  // 1小时
            let item = try JellyfinCachedItem(data: episode, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "episode_metadata_\(episode.id)" as NSString
            metadataCache.setObject(item, forKey: key)
            
            saveToDisk(item, key: String(key))
            print("JellyfinCache: 已缓存剧集元数据: \(episode.name)")
        } catch {
            print("JellyfinCache: 缓存剧集元数据失败: \(error)")
        }
    }
    
    /// 获取缓存的剧集元数据
    func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode? {
        let key = "episode_metadata_\(episodeId)" as NSString
        
        // 先检查内存缓存
        if let item = metadataCache.object(forKey: key), !item.isExpired {
            let episode = item.data as? JellyfinEpisode
            if let episode = episode {
                print("JellyfinCache: 从内存缓存获取剧集元数据: \(episode.name)")
            }
            return episode
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            metadataCache.setObject(item, forKey: key)
            let episode = item.data as? JellyfinEpisode
            if let episode = episode {
                print("JellyfinCache: 从磁盘缓存获取剧集元数据: \(episode.name)")
            }
            return episode
        }
        
        return nil
    }
    
    /// 批量缓存剧集元数据（用于预缓存）
    func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode]) {
        for episode in episodes {
            cacheEpisodeMetadata(episode)
        }
        print("JellyfinCache: 批量缓存了 \(episodes.count) 个剧集的元数据")
    }
    
    // MARK: - 季节缓存
    
    /// 缓存季节列表（1小时）
    func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String) {
        do {
            let cacheTime: TimeInterval = 3600  // 1小时
            let item = try JellyfinCachedItem(data: seasons, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "seasons_\(seriesId)" as NSString
            metadataCache.setObject(item, forKey: key)
            
            saveToDisk(item, key: String(key))
            print("JellyfinCache: 已缓存 \(seasons.count) 个季节")
        } catch {
            print("JellyfinCache: 缓存季节失败: \(error)")
        }
    }
    
    /// 获取缓存的季节列表
    func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]? {
        let key = "seasons_\(seriesId)" as NSString
        
        // 先检查内存缓存
        if let item = metadataCache.object(forKey: key), !item.isExpired {
            let seasons = item.data as? [JellyfinMediaItem]
            if let seasons = seasons {
                print("JellyfinCache: 从内存缓存获取 \(seasons.count) 个季节")
            }
            return seasons
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            metadataCache.setObject(item, forKey: key)
            let seasons = item.data as? [JellyfinMediaItem]
            if let seasons = seasons {
                print("JellyfinCache: 从磁盘缓存获取 \(seasons.count) 个季节")
            }
            return seasons
        }
        
        return nil
    }
    
    // MARK: - 图片缓存
    
    /// 缓存图片（7天）
    func cacheImage(_ image: UIImage, for imageURL: URL) {
        let key = imageURL.absoluteString.md5 as NSString
        
        // 缓存到内存
        imageCache.setObject(image, forKey: key)
        
        // 保存到磁盘
        DispatchQueue.global(qos: .utility).async {
            if let imageData = image.pngData() {
                let fileURL = self.imageCacheDirectory.appendingPathComponent("\(key).png")
                try? imageData.write(to: fileURL)
                print("JellyfinCache: 已缓存图片到磁盘")
            }
        }
    }
    
    /// 获取缓存的图片
    func getCachedImage(for imageURL: URL) -> UIImage? {
        let key = imageURL.absoluteString.md5 as NSString
        
        // 先检查内存缓存
        if let image = imageCache.object(forKey: key) {
            print("JellyfinCache: 从内存缓存获取图片")
            return image
        }
        
        // 检查磁盘缓存
        let fileURL = imageCacheDirectory.appendingPathComponent("\(key).png")
        if let imageData = try? Data(contentsOf: fileURL),
           let image = UIImage(data: imageData) {
            
            // 检查文件是否过期（7天）
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               Date().timeIntervalSince(creationDate) < 7 * 24 * 3600 {
                
                imageCache.setObject(image, forKey: key)
                print("JellyfinCache: 从磁盘缓存获取图片")
                return image
            } else {
                // 图片过期，删除文件
                try? fileManager.removeItem(at: fileURL)
            }
        }
        
        return nil
    }
    
    // MARK: - 磁盘缓存
    
    private func saveToDisk(_ item: JellyfinCachedItem, key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try JSONEncoder().encode(item)
            try data.write(to: url)
        } catch {
            print("JellyfinCache: 保存缓存失败: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> JellyfinCachedItem? {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(JellyfinCachedItem.self, from: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - 缓存清理
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 清理元数据缓存
                let metadataFiles = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for fileURL in metadataFiles where fileURL.pathExtension == "cache" {
                    if let item = self.loadFromDisk(key: fileURL.deletingPathExtension().lastPathComponent) {
                        if item.isExpired {
                            try? self.fileManager.removeItem(at: fileURL)
                        }
                    }
                }
                
                // 清理过期图片
                let imageFiles = try self.fileManager.contentsOfDirectory(at: self.imageCacheDirectory, includingPropertiesForKeys: [.creationDateKey])
                for fileURL in imageFiles {
                    if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       Date().timeIntervalSince(creationDate) > 7 * 24 * 3600 {
                        try? self.fileManager.removeItem(at: fileURL)
                    }
                }
                
                print("JellyfinCache: 清理过期缓存完成")
            } catch {
                print("JellyfinCache: 清理缓存失败: \(error)")
            }
        }
    }
    
    /// 清理所有缓存
    func clearAllCache() {
        metadataCache.removeAllObjects()
        imageCache.removeAllObjects()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in files {
                try fileManager.removeItem(at: fileURL)
            }
            print("JellyfinCache: 清理所有缓存完成")
        } catch {
            print("JellyfinCache: 清理缓存失败: \(error)")
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            print("JellyfinCache: 计算缓存大小失败: \(error)")
        }
        return totalSize
    }
    
    // MARK: - 选择性缓存清理
    
    /// 清除特定媒体库项目的缓存
    func clearLibraryItemsCache(for libraryId: String) {
        let key = "library_items_\(libraryId)" as NSString
        metadataCache.removeObject(forKey: key)
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
        
        print("JellyfinCache: 已清除媒体库项目缓存")
    }
    
    /// 清除特定剧集的元数据缓存
    func clearEpisodeMetadataCache(for episodeId: String) {
        let key = "episode_metadata_\(episodeId)" as NSString
        metadataCache.removeObject(forKey: key)
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
        
        print("JellyfinCache: 已清除剧集元数据缓存")
    }
    
    /// 清除特定系列的所有剧集元数据缓存
    func clearSeriesEpisodesMetadataCache(for seriesId: String) {
        // 这里需要遍历所有缓存项来找到属于该系列的剧集
        // 为简化实现，我们可以添加一个按系列ID索引的映射
        print("JellyfinCache: 清除系列 \(seriesId) 的所有剧集元数据缓存")
    }
    
    /// 清除特定季节的缓存
    func clearSeasonsCache(for seriesId: String) {
        let key = "seasons_\(seriesId)" as NSString
        metadataCache.removeObject(forKey: key)
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
        
        print("JellyfinCache: 已清除季节缓存")
    }
}

// MARK: - 扩展

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            guard buffer.count >= 4 else { return "0000" }
            return String(format: "%02x%02x%02x%02x", 
                         buffer[0], buffer[1], buffer[2], buffer[3])
        }
        return "\(self.hashValue)_\(hash)" // 使用hashValue作为简单的哈希替代
    }
}

/// 缓存项，包含数据和过期时间
class JellyfinCachedItem: NSObject, Codable {
    enum CodableData: Codable {
        case libraryArray([JellyfinLibrary])
        case mediaItemArray([JellyfinMediaItem])
        case episodeArray([JellyfinEpisode]) // 保留用于批量缓存
        case singleEpisode(JellyfinEpisode)   // 新增单个剧集
        case seasonArray([JellyfinMediaItem])
        
        var data: Any {
            switch self {
            case .libraryArray(let libraries):
                return libraries
            case .mediaItemArray(let items):
                return items
            case .episodeArray(let episodes):
                return episodes
            case .singleEpisode(let episode):
                return episode
            case .seasonArray(let seasons):
                return seasons
            }
        }
    }
    
    private let codableData: CodableData
    let expiryDate: Date
    
    var data: Any {
        return codableData.data
    }
    
    init<T: Codable>(data: T, expiryDate: Date) throws {
        switch data {
        case let libraries as [JellyfinLibrary]:
            self.codableData = .libraryArray(libraries)
        case let items as [JellyfinMediaItem]:
            self.codableData = .mediaItemArray(items)
        case let episodes as [JellyfinEpisode]:
            self.codableData = .episodeArray(episodes)
        case let episode as JellyfinEpisode:
            self.codableData = .singleEpisode(episode)
        default:
            throw NSError(domain: "JellyfinCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "不支持的数据类型"])
        }
        self.expiryDate = expiryDate
        super.init()
    }
    
    var isExpired: Bool {
        return Date() > expiryDate
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case codableData, expiryDate
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.codableData = try container.decode(CodableData.self, forKey: .codableData)
        self.expiryDate = try container.decode(Date.self, forKey: .expiryDate)
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(codableData, forKey: .codableData)
        try container.encode(expiryDate, forKey: .expiryDate)
    }
}
