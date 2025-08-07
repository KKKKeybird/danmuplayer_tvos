# DanDanPlay API 重构总结

## 重构目的

1. **术语准确性**: 将 `DanDanPlaySeries` 重命名为 `DanDanPlayEpisode`，因为API实际返回的是单集（episode）信息，不是整部作品（series）信息
2. **使用场景区分**: 区分自动识别和手动选择的场景，提供更合适的API接口
3. **缓存优化**: 更新缓存系统以保留偏移时间等重要信息

## 主要变更

### 1. 模型重命名
- `DanDanPlaySeries` → `DanDanPlayEpisode`
- `DanDanPlaySeries.swift` → `DanDanPlayEpisode.swift`
- 更新了所有相关的方法和属性名称

### 2. API方法重构

#### 原来的方法：
```swift
func identifySeries(for videoURL: URL, completion: @escaping (Result<DanDanPlaySeries, Error>) -> Void)
func fetchCandidateSeriesList(for videoURL: URL, completion: @escaping (Result<[DanDanPlaySeries], Error>) -> Void)
```

#### 新的方法：
```swift
// 自动识别：返回最佳匹配的单个剧集
func identifyEpisode(for videoURL: URL, completion: @escaping (Result<DanDanPlayEpisode, Error>) -> Void)

// 手动选择：返回所有候选剧集供用户选择
func fetchCandidateEpisodeList(for videoURL: URL, completion: @escaping (Result<[DanDanPlayEpisode], Error>) -> Void)
```

### 3. 使用场景优化

#### 自动识别场景 (`identifyEpisode`)：
- 系统自动选择最佳匹配（API返回的第一个结果）
- 适用于播放器自动加载弹幕的场景
- 缓存所有匹配结果供后续手动选择使用

#### 手动选择场景 (`fetchCandidateEpisodeList`)：
- 返回所有可能的匹配结果
- 用户可以手动选择最合适的剧集
- 适用于用户需要精确控制的场景

### 4. 搜索API响应格式修复

#### 更新了搜索API的响应模型：
```swift
struct DanDanPlaySearchResult: Codable {
    let errorCode: Int          // 错误代码，0表示没有发生错误
    let success: Bool           // 接口是否调用成功
    let errorMessage: String?   // 错误信息，可为空
    let hasMore: Bool           // 是否有更多未显示的搜索结果
    let animes: [SearchEpisodesAnime]? // 搜索结果列表，可为空
}
```

### 5. 偏移时间信息保留

- 在 `DanDanPlayEpisode` 中添加了 `shift: Double?` 字段
- 从match API获取的结果会保留偏移时间信息
- 从search API获取的结果偏移时间为 `nil`（因为搜索API不提供此信息）
- 添加了 `shiftDescription` 计算属性来格式化显示偏移时间

### 6. 缓存系统更新

- 更新了所有缓存相关的方法和数据结构
- `cacheSeriesInfo` → `cacheEpisodeInfo`  
- `getCachedSeriesInfo` → `getCachedEpisodeInfo`
- 更新了序列化相关的枚举类型

## 向后兼容性

由于这是一次重大重构，涉及到以下破坏性变更：

1. **类型名称变更**: `DanDanPlaySeries` → `DanDanPlayEpisode`
2. **方法名称变更**: 所有相关的API方法名都有变化
3. **缓存键名变更**: 缓存的key从 "series_" 前缀改为 "episode_" 前缀

## 使用示例

### 自动识别（推荐用于播放器）：
```swift
danDanPlayAPI.identifyEpisode(for: videoURL) { result in
    switch result {
    case .success(let episode):
        print("自动识别到剧集: \(episode.displayTitle)")
        if let shiftDesc = episode.shiftDescription {
            print("偏移时间: \(shiftDesc)")
        }
        // 加载弹幕...
    case .failure(let error):
        print("识别失败: \(error)")
    }
}
```

### 手动选择（推荐用于设置界面）：
```swift
danDanPlayAPI.fetchCandidateEpisodeList(for: videoURL) { result in
    switch result {
    case .success(let episodes):
        // 显示候选列表供用户选择
        showEpisodeSelectionUI(episodes: episodes)
    case .failure(let error):
        print("获取候选列表失败: \(error)")
    }
}
```

## 总结

这次重构解决了以下问题：

1. ✅ **术语准确性**: 使用正确的 Episode 概念
2. ✅ **偏移时间保留**: 缓存和传递中保留了重要的时间偏移信息
3. ✅ **场景区分**: 明确区分了自动识别和手动选择的使用场景
4. ✅ **API规范**: 修正了搜索API的响应格式以符合实际规范
5. ✅ **代码质量**: 提高了代码的可读性和维护性

重构后的代码更加清晰、准确，并且更好地支持了不同的使用场景。
