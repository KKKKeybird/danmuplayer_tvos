```swift
JellyfinCache{
    func cacheLibraryItems(_ items: [JellyfinMediaItem], for libraryId: String) // 缓存媒体库项目列表（30分钟）
    func getCachedLibraryItems(for libraryId: String) -> [JellyfinMediaItem]? // 获取缓存的媒体库项目列表
    func cacheEpisodeMetadata(_ episode: JellyfinEpisode) // 缓存单个剧集的元数据（1小时）
    func getCachedEpisodeMetadata(for episodeId: String) -> JellyfinEpisode? // 获取缓存的剧集元数据
    func batchCacheEpisodesMetadata(_ episodes: [JellyfinEpisode]) // 批量缓存剧集元数据（用于预缓存）
    func cacheSeasons(_ seasons: [JellyfinMediaItem], for seriesId: String) // 缓存季节列表（1小时）
    func getCachedSeasons(for seriesId: String) -> [JellyfinMediaItem]? // 获取缓存的季节列表
    func cacheImage(_ image: UIImage, for imageURL: URL) // 缓存图片（7天）
    func getCachedImage(for imageURL: URL) -> UIImage? // 获取缓存的图片
    func clearAllCache() // 清理所有缓存
    func getCacheSize() -> Int64 // 获取缓存大小
    func clearLibraryItemsCache(for libraryId: String) // 清除特定媒体库项目的缓存
    func clearEpisodeMetadataCache(for episodeId: String) // 清除特定剧集的元数据缓存
    func clearSeriesEpisodesMetadataCache(for seriesId: String) // 清除特定系列的所有剧集元数据缓存
    func clearSeasonsCache(for seriesId: String) // 清除特定季节的缓存
}
DanDanPlayCache{
    func cacheASSSubtitle(_ assContent: String, for episodeId: Int) // 缓存ASS字幕文件（2小时）
    func getCachedASSSubtitle(for episodeId: Int) -> String? // 获取缓存的ASS字幕内容
    func cacheEpisodeInfo(_ episode: DanDanPlayEpisode, for fileurl: String) // 缓存剧集信息（长期缓存，7天）
    func getCachedEpisodeInfo(for fileurl: String) -> DanDanPlayEpisode? // 获取缓存的剧集信息
    func clearAllCache() // 清理所有缓存
    func getCacheSize() -> Int64 // 获取弹幕数据缓存大小
    func clearEpisodeCache(episodeId: Int, episodeNumber: Int? = nil) // 清理指定剧集的相关缓存（包括弹幕和ASS字幕）
}
DanDanPlayAPI{
    func identifyEpisode(for videoURL: URL, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void) // 自动识别剧集（返回最佳匹配结果）
    func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void) // 获取候选剧集列表供用户手动选择
    func loadDanmakuAsASS(for episode: DanDanPlayEpisode, completion: @escaping (Result<String, Error>) -> Void) // 加载弹幕并转换为ASS格式（新版简化API）
}
```