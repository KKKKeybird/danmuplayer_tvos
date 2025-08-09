/// 弹弹Play API缓存管理器
import Foundation

/// 弹弹Play API数据缓存管理
class DanDanPlayCache {
    static let shared = DanDanPlayCache()
    
    private let cache = NSCache<NSString, DanDanPlayCachedItem>()
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
    
    
    // MARK: - ASS字幕缓存
    
    /// 缓存ASS字幕文件（2小时）
    func cacheASSSubtitle(_ assContent: String, for episodeId: Int) {
        do {
            let cacheTime: TimeInterval = 2 * 3600  // 2小时
            let item = try DanDanPlayCachedItem(data: assContent.data(using: .utf8) ?? Data(), expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "ass_\(episodeId)" as NSString
            cache.setObject(item, forKey: key)
            
            // 保存到磁盘
            saveToDisk(item, key: String(key))
        } catch {
            print("缓存ASS字幕失败: \(error)")
        }
    }
    
    /// 获取缓存的ASS字幕内容
    func getCachedASSSubtitle(for episodeId: Int) -> String? {
        let key = "ass_\(episodeId)" as NSString
        
        // 先检查内存缓存
        if let item = cache.object(forKey: key), !item.isExpired,
           let data = item.data as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        // 检查磁盘缓存
        if let item = loadFromDisk(key: String(key)), !item.isExpired,
           let data = item.data as? Data {
            cache.setObject(item, forKey: key)
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - 剧集信息缓存
    
    /// 缓存剧集信息（长期缓存，7天）
    func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileurl: URL) {
        do {
            let cacheTime: TimeInterval = 7 * 24 * 3600  // 7天
            let item = try DanDanPlayCachedItem(data: episode, expiryDate: Date().addingTimeInterval(cacheTime))
            let key = "episode_\(fileurl.absoluteString)" as NSString
            cache.setObject(item, forKey: key)
            
            saveToDisk(item, key: String(key))
        } catch {
            print("缓存剧集信息失败: \(error)")
        }
    }
    
    /// 获取缓存的剧集信息
    func getCachedEpisodeInfo(for fileurl: URL) -> DanDanPlayEpisode? {
        let key = "episode_\(fileurl.absoluteString)" as NSString
        
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
    
    private func saveToDisk(_ item: DanDanPlayCachedItem, key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try JSONEncoder().encode(item)
            try data.write(to: url)
        } catch {
            print("保存缓存失败: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> DanDanPlayCachedItem? {
        let url = cacheDirectory.appendingPathComponent("\(key).cache")
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(DanDanPlayCachedItem.self, from: data)
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
    
    // MARK: - 缓存管理
    
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
    
    /// 清理指定剧集的相关缓存（包括弹幕和ASS字幕）
    func clearEpisodeCache(episodeId: Int, episodeNumber: Int? = nil) {
        // 清理ASS字幕缓存
        let assKey = "ass_\(episodeId)" as NSString
        cache.removeObject(forKey: assKey)
        
        let assFileURL = cacheDirectory.appendingPathComponent("\(assKey).cache")
        try? fileManager.removeItem(at: assFileURL)
        
        print("已清理剧集 \(episodeId) 的相关缓存")
    }
}

// MARK: - 缓存项

/// 弹弹Play缓存项，包含数据和过期时间
class DanDanPlayCachedItem: NSObject, Codable {
    enum CodableData: Codable {
        case singleEpisode(DanDanPlayEpisode)
        case data(Data)
        
        init(from data: Any) throws {
            if let episode = data as? DanDanPlayEpisode {
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
