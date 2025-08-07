/// 弹弹Play API缓存管理器
import Foundation

/// 弹弹Play API数据缓存管理
class DanDanPlayCache {
    static let shared = DanDanPlayCache()
    
    private let cache = NSCache<NSString, CachedItem>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 创建缓存目录
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("DanDanPlayCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 配置内存缓存
        cache.countLimit = 100  // 最多缓存100个条目
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB内存限制
        
        // 启动时清理过期缓存
        cleanExpiredCache()
    }
    
    // MARK: - 搜索结果缓存
    
    /// 缓存搜索结果（2-6小时）
    func cacheSearchResult(_ result: [DanDanPlayEpisode], for query: String) {
        do {
            let cacheTime: TimeInterval = 4 * 3600  // 4小时
            let item = try CachedItem(data: result, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "search_\(query.lowercased())" as NSString
            cache.setObject(item, forKey: key)
            
            // 同时保存到磁盘
            saveToDisk(item, key: String(key))
        } catch {
            print("缓存搜索结果失败: \(error)")
        }
    }
    
    /// 获取缓存的搜索结果
    func getCachedSearchResult(for query: String) -> [DanDanPlayEpisode]? {
        let key = "search_\(query.lowercased())" as NSString
        
        // 先检查内存缓存
        if let item = cache.object(forKey: key), !item.isExpired {
            return item.data as? [DanDanPlayEpisode]
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            cache.setObject(item, forKey: key)  // 重新加载到内存
            return item.data as? [DanDanPlayEpisode]
        }
        
        return nil
    }
    
    // MARK: - 弹幕数据缓存
    
    /// 缓存弹幕数据
    func cacheDanmaku(_ data: Data, for episodeId: Int, isHotAnime: Bool = false) {
        do {
            // 热门番剧缓存时间短一些，老番剧缓存时间长一些
            let cacheTime: TimeInterval = isHotAnime ? 2 * 3600 : 24 * 3600  // 2小时 vs 24小时
            let item = try CachedItem(data: data, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "danmaku_\(episodeId)" as NSString
            cache.setObject(item, forKey: key)
            
            // 保存到磁盘
            saveToDisk(item, key: String(key))
        } catch {
            print("缓存弹幕数据失败: \(error)")
        }
    }
    
    /// 获取缓存的弹幕数据
    func getCachedDanmaku(for episodeId: Int) -> Data? {
        let key = "danmaku_\(episodeId)" as NSString
        
        // 先检查内存缓存
        if let item = cache.object(forKey: key), !item.isExpired {
            return item.data as? Data
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            cache.setObject(item, forKey: key)
            return item.data as? Data
        }
        
        return nil
    }
    
    // MARK: - 剧集信息缓存
    
    /// 缓存剧集信息（长期缓存，7天）
    func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileHash: String) {
        do {
            let cacheTime: TimeInterval = 7 * 24 * 3600  // 7天
            let item = try CachedItem(data: episode, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "episode_\(fileHash)" as NSString
            cache.setObject(item, forKey: key)
            
            saveToDisk(item, key: String(key))
        } catch {
            print("缓存剧集信息失败: \(error)")
        }
    }
    
    /// 获取缓存的剧集信息
    func getCachedEpisodeInfo(for fileHash: String) -> DanDanPlayEpisode? {
        let key = "episode_\(fileHash)" as NSString
        
        if let item = cache.object(forKey: key), !item.isExpired {
            return item.data as? DanDanPlayEpisode
        }
        
        if let item = loadFromDisk(key: String(key)), !item.isExpired {
            cache.setObject(item, forKey: key)
            return item.data as? DanDanPlayEpisode
        }
        
        return nil
    }
    
    // MARK: - 磁盘缓存
    
    private func saveToDisk(_ item: CachedItem, key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try JSONEncoder().encode(item)
            try data.write(to: url)
        } catch {
            print("保存缓存失败: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> CachedItem? {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CachedItem.self, from: data)
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
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for fileURL in files {
                    if let item = self.loadFromDisk(key: fileURL.deletingPathExtension().lastPathComponent) {
                        if item.isExpired {
                            try? self.fileManager.removeItem(at: fileURL)
                        }
                    }
                }
            } catch {
                print("清理缓存失败: \(error)")
            }
        }
    }
    
    /// 清理所有缓存
    func clearAllCache() {
        cache.removeAllObjects()
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in files {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("清理缓存失败: \(error)")
        }
    }
    
    // MARK: - 字幕缓存管理
    
    /// 获取弹幕数据缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            print("计算缓存大小失败: \(error)")
        }
        return totalSize
    }
    
    /// 清理指定剧集的相关缓存（包括弹幕和字幕）
    func clearEpisodeCache(episodeId: Int, episodeNumber: Int? = nil) {
        // 清理弹幕缓存
        let danmakuKey = "danmaku_\(episodeId)" as NSString
        cache.removeObject(forKey: danmakuKey)
        
        let danmakuFileURL = cacheDirectory.appendingPathComponent("\(danmakuKey).cache")
        try? fileManager.removeItem(at: danmakuFileURL)
        
        // 清理字幕缓存
        DanmakuToSubtitleConverter.clearCachedSubtitles(episodeId: episodeId, episodeNumber: episodeNumber)
        
        print("已清理剧集 \(episodeId) 的所有缓存")
    }
    
    /// 获取总缓存大小（包括字幕缓存）
    func getTotalCacheSize() -> Int64 {
        let danmakuCacheSize = getCacheSize()
        let subtitleCacheSize = DanmakuToSubtitleConverter.getSubtitleCacheSize()
        return danmakuCacheSize + subtitleCacheSize
    }
    
    /// 清理所有缓存（包括字幕缓存）
    func clearAllCacheIncludingSubtitles() {
        clearAllCache()
        DanmakuToSubtitleConverter.clearAllCachedSubtitles()
        print("已清理所有弹幕和字幕缓存")
    }
}

// MARK: - 缓存项

/// 缓存项，包含数据和过期时间
class CachedItem: NSObject, Codable {
    enum CodableData: Codable {
        case episodeArray([DanDanPlayEpisode])
        case singleEpisode(DanDanPlayEpisode)
        case data(Data)
        
        init(from data: Any) throws {
            if let episodeArray = data as? [DanDanPlayEpisode] {
                self = .episodeArray(episodeArray)
            } else if let episode = data as? DanDanPlayEpisode {
                self = .singleEpisode(episode)
            } else if let rawData = data as? Data {
                self = .data(rawData)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Unsupported data type: \(type(of: data))")
                )
            }
        }
        
        var value: Any {
            switch self {
            case .episodeArray(let array):
                return array
            case .singleEpisode(let episode):
                return episode
            case .data(let data):
                return data
            }
        }
    }
    
    private let codableData: CodableData
    let expiryDate: Date
    
    var data: Any {
        return codableData.value
    }
    
    init(data: Any, expiryDate: Date) throws {
        self.codableData = try CodableData(from: data)
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
