/// Jellyfin媒体库视图模型
import Foundation
import SwiftUI

/// 管理Jellyfin媒体库数据的视图模型
@MainActor
@available(tvOS 17.0, *)
class JellyfinMediaLibraryViewModel: ObservableObject {
    @Published var libraries: [JellyfinLibrary] = []
    @Published var mediaItems: [JellyfinMediaItem] = []
    @Published var seasons: [JellyfinMediaItem] = []
    @Published var episodes: [JellyfinEpisode] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedLibrary: JellyfinLibrary?
    @Published var selectedSeries: JellyfinMediaItem?
    @Published var selectedSeason: JellyfinMediaItem?
    @Published var currentLevel: BrowsingLevel = .libraries
    @Published var isAuthenticated = false
    @Published var isPerformingDetailedTest = false
    @Published var connectionTestResults: [String] = []
    @Published var showingLibrarySelection = false
    
    enum BrowsingLevel {
        case libraries
        case mediaItems
        case seasons
        case episodes
    }
    
    private let client: JellyfinClient
    private let config: MediaLibraryConfig
    private var serverId: String {
        return config.serverURL
    }
    
    @StateObject private var configManager = JellyfinLibraryConfigManager.shared
    
    // 暴露 JellyfinClient 用于设置界面
    var jellyfinClient: JellyfinClient {
        return client
    }
    
    init(config: MediaLibraryConfig) {
        self.config = config
        if let client = config.createJellyfinClient() {
            self.client = client
        } else {
            // 如果无法通过config创建，使用基本构造函数
            self.client = JellyfinClient(
                serverURL: URL(string: config.serverURL)!,
                username: config.username,
                password: config.password
            )
        }
    }
    
    // MARK: - 认证并加载媒体库
    func authenticate() {
        guard !isAuthenticated else {
            loadLibraries()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 首先测试服务器连接
        client.testConnection { testResult in
            Task { @MainActor in
                switch testResult {
                case .success:
                    // 服务器可达，尝试认证
                    self.performAuthentication()
                case .failure(let error):
                    self.isLoading = false
                    if let networkError = error as? NetworkError {
                        self.errorMessage = "服务器连接失败: \(networkError.localizedDescription)"
                    } else {
                        self.errorMessage = "服务器连接失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// 执行认证
    private func performAuthentication() {
        client.authenticate { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success:
                    self.isAuthenticated = true
                    self.loadLibraries()
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = "认证失败: \(networkError.localizedDescription)"
                    } else {
                        self.errorMessage = "认证失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// 加载媒体库列表
    private func loadLibraries() {
        isLoading = true
        errorMessage = nil
        
        client.getLibraries { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let libraries):
                    self.libraries = libraries.filter { library in
                        // 只显示电影和电视剧媒体库
                        library.collectionType == "movies" || library.collectionType == "tvshows" || library.collectionType == nil
                    }
                    
                    // 直接加载合并后的媒体内容，不再显示媒体库选择界面
                    self.loadMergedMediaItems()
                    
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "加载媒体库失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// 加载合并后的媒体内容
    private func loadMergedMediaItems() {
        isLoading = true
        errorMessage = nil
        currentLevel = .mediaItems
        
        client.getMergedLibraryItems(serverId: serverId) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let items):
                    self.mediaItems = items
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = "加载媒体内容失败: \(networkError.localizedDescription)"
                    } else {
                        self.errorMessage = "加载媒体内容失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - 显示媒体库选择界面
    func showLibrarySelection() {
        showingLibrarySelection = true
    }
    
    // MARK: - 选择媒体库并加载内容
    func selectLibrary(_ library: JellyfinLibrary) {
        selectedLibrary = library
        currentLevel = .mediaItems
        loadMediaItems(from: library)
    }
    
    // MARK: - 选择系列并加载季节
    func selectSeries(_ series: JellyfinMediaItem) {
        selectedSeries = series
        if series.type == "Series" {
            currentLevel = .seasons
            loadSeasons(for: series.id)
        }
        // 电影播放现在通过UI层的统一逻辑处理，不再在ViewModel中直接处理
    }
    
    // MARK: - 选择季节并加载剧集
    func selectSeason(_ season: JellyfinMediaItem) {
        selectedSeason = season
        currentLevel = .episodes
        if let seriesId = selectedSeries?.id {
            loadEpisodes(for: seriesId, seasonId: season.id)
        }
    }
    
    // MARK: - 返回上一级
    func goBack() {
        switch currentLevel {
        case .libraries:
            break // 已经在顶级
        case .mediaItems:
            currentLevel = .libraries
            selectedLibrary = nil
        case .seasons:
            currentLevel = .mediaItems
            selectedSeries = nil
            seasons = []
        case .episodes:
            currentLevel = .seasons
            selectedSeason = nil
            episodes = []
        }
    }
    
    /// 加载媒体库中的项目
    private func loadMediaItems(from library: JellyfinLibrary) {
        isLoading = true
        errorMessage = nil
        mediaItems = []
        
        client.getLibraryItems(libraryId: library.id) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let items):
                    print("JellyfinMediaLibraryViewModel: Loaded \(items.count) media items")
                    self.mediaItems = items
                case .failure(let error):
                    print("JellyfinMediaLibraryViewModel: Failed to load media items: \(error)")
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "加载媒体项目失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// 加载系列的季节
    private func loadSeasons(for seriesId: String) {
        isLoading = true
        errorMessage = nil
        seasons = []
        
        client.getSeasons(seriesId: seriesId) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let seasons):
                    print("JellyfinMediaLibraryViewModel: Loaded \(seasons.count) seasons")
                    self.seasons = seasons
                case .failure(let error):
                    print("JellyfinMediaLibraryViewModel: Failed to load seasons: \(error)")
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "加载季节失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// 加载剧集
    private func loadEpisodes(for seriesId: String, seasonId: String? = nil) {
        isLoading = true
        errorMessage = nil
        episodes = []
        
        client.getEpisodes(seriesId: seriesId) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let allEpisodes):
                    // 如果指定了季节ID，过滤出该季节的剧集
                    let filteredEpisodes: [JellyfinEpisode]
                    if let seasonId = seasonId {
                        filteredEpisodes = allEpisodes.filter { $0.seasonId == seasonId }
                    } else {
                        filteredEpisodes = allEpisodes
                    }
                    print("JellyfinMediaLibraryViewModel: Loaded \(filteredEpisodes.count) episodes")
                    self.episodes = filteredEpisodes
                case .failure(let error):
                    print("JellyfinMediaLibraryViewModel: Failed to load episodes: \(error)")
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "加载剧集失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - 刷新当前媒体库
    func refresh() {
        switch currentLevel {
        case .libraries:
            loadLibraries()
        case .mediaItems:
            // 刷新合并后的媒体内容
            loadMergedMediaItems()
        case .seasons:
            if let selectedSeries = selectedSeries {
                loadSeasons(for: selectedSeries.id)
            }
        case .episodes:
            if let selectedSeries = selectedSeries {
                loadEpisodes(for: selectedSeries.id, seasonId: selectedSeason?.id)
            }
        }
    }
    
    // MARK: - 获取媒体项目的海报图片URL
    func getImageUrl(for item: JellyfinMediaItem, type: String = "Primary", maxWidth: Int = 600) -> URL? {
        return client.getImageUrl(itemId: item.id, type: type, maxWidth: maxWidth)
    }
    
    // MARK: - 字幕处理（由ViewModel负责）
    
    /// 为播放准备媒体（包括获取并缓存所有可用字幕）
    /// - Parameters:
    ///   - item: 媒体项
    ///   - completion: 完成回调，返回播放URL和所有字幕URL数组
    func prepareMediaForPlayback(item: JellyfinMediaItem, completion: @escaping (URL, [URL]) -> Void) {
        // 优先使用直链（支持 Range），失败再回退至转码/流链接
        let playbackURL = client.getDirectFileUrl(itemId: item.id) ?? client.getPlaybackUrl(itemId: item.id)
        guard let playbackURL = playbackURL else {
            DispatchQueue.main.async { completion(URL(string: "")!, []) }
            return
        }
        
        // 获取所有字幕轨道
        client.getSubtitleTracks(for: item.id) { [weak self] result in
            guard let self = self else {
                DispatchQueue.main.async { completion(playbackURL, []) }
                return
            }
            switch result {
            case .success(let tracks):
                if tracks.isEmpty {
                    DispatchQueue.main.async { completion(playbackURL, []) }
                    return
                }
                // 下载所有字幕并缓存
                let group = DispatchGroup()
                var subtitleURLs: [URL] = []
                for track in tracks {
                    group.enter()
                    self.client.downloadAndConvertSubtitle(itemId: item.id, track: track) { url in
                        if let url = url {
                            subtitleURLs.append(url)
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    completion(playbackURL, subtitleURLs)
                }
            case .failure(_):
                DispatchQueue.main.async { completion(playbackURL, []) }
            }
        }
    }
    
    // MARK: - 播放逻辑方法
    
    /// 验证媒体项目是否可以播放（检查播放URL可用性）
    func validatePlayability(for item: JellyfinMediaItem) -> Bool {
        return client.getPlaybackUrl(itemId: item.id) != nil
    }
    
    // MARK: - 获取剧集列表
    func getEpisodes(for seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) {
        client.getEpisodes(seriesId: seriesId, completion: completion)
    }
    
    // MARK: - 统一剧集结构：为电影创建虚拟剧集
    func getEpisodesForUnifiedStructure(for item: JellyfinMediaItem, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) {
        if item.type == "Movie" {
            // 将电影包装为一个虚拟剧集（第1季第1集）
            let movieAsEpisode = JellyfinEpisode(
                id: item.id,
                name: item.name,
                serverId: item.serverId,
                etag: item.etag,
                dateCreated: item.dateCreated,
                canDelete: item.canDelete,
                canDownload: item.canDownload,
                sortName: item.sortName,
                type: "Episode", // 转换为Episode类型
                locationType: item.locationType,
                userData: item.userData,
                productionYear: item.productionYear,
                status: item.status,
                endDate: item.endDate,
                overview: item.overview,
                communityRating: item.communityRating,
                officialRating: item.officialRating,
                runTimeTicks: item.runTimeTicks,
                genres: item.genres,
                tags: item.tags,
                imageTags: item.imageTags,
                seriesName: item.name, // 剧集名称使用电影名称
                seriesId: item.id,
                seasonId: item.id,
                seasonName: "第一季",
                indexNumber: 1, // 第1集
                parentIndexNumber: 1, // 第1季
                primaryImageAspectRatio: item.primaryImageAspectRatio
            )
            completion(.success([movieAsEpisode]))
        } else if item.type == "Series" {
            // 对于真正的剧集，调用原有方法
            getEpisodes(for: item.id, completion: completion)
        } else {
            completion(.failure(NSError(domain: "JellyfinMediaLibraryViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "不支持的媒体类型: \(item.type)"])))
        }
    }
    
    // MARK: - 执行详细的连接测试
    @MainActor
    func performDetailedConnectionTest() async {
        isPerformingDetailedTest = true
        connectionTestResults = []
        
        // 1. 基本URL连接测试
        await addTestResult("基本URL连接测试") {
            return try await withCheckedThrowingContinuation { continuation in
                self.client.testConnection { result in
                    switch result {
                    case .success(let isConnected):
                        if isConnected {
                            continuation.resume(returning: "连接成功")
                        } else {
                            continuation.resume(throwing: NetworkError.connectionFailed)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        // 2. URL格式验证
        await addTestResult("URL格式验证") {
            guard let url = URL(string: config.serverURL) else {
                throw NetworkError.invalidURL
            }
            guard let scheme = url.scheme, (scheme == "http" || scheme == "https") else {
                throw NetworkError.invalidURL
            }
            guard let host = url.host, !host.isEmpty else {
                throw NetworkError.invalidURL
            }
            let port = url.port ?? (scheme == "https" ? 443 : 80)
            return "格式正确: \(scheme)://\(host):\(port)"
        }
        
        // 3. 服务器可达性测试
        await addTestResult("服务器可达性测试") {
            let url = URL(string: config.serverURL)!
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return "HTTP状态码: \(httpResponse.statusCode)"
            } else {
                return "服务器响应正常"
            }
        }
        
        // 4. Jellyfin API端点测试
        await addTestResult("Jellyfin API测试") {
            let apiURL = URL(string: config.serverURL)!.appendingPathComponent("System/Info")
            var request = URLRequest(url: apiURL)
            request.timeoutInterval = 10.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let version = json["Version"] as? String {
                        return "Jellyfin版本: \(version)"
                    }
                    return "API响应正常"
                } else {
                    return "API错误，状态码: \(httpResponse.statusCode)"
                }
            }
            throw NetworkError.serverUnavailable
        }
        
        // 5. 认证测试
        if let username = config.username, let password = config.password,
           !username.isEmpty && !password.isEmpty {
            await addTestResult("用户认证测试") {
                return try await withCheckedThrowingContinuation { continuation in
                    self.client.authenticate { result in
                        switch result {
                        case .success(let user):
                            continuation.resume(returning: "认证成功: \(user.name)")
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
        
        isPerformingDetailedTest = false
    }
    
    private func addTestResult(_ testName: String, test: () async throws -> String) async {
        do {
            let result = try await test()
            connectionTestResults.append("\(testName): ✅ \(result)")
        } catch {
            connectionTestResults.append("\(testName): ❌ \(error.localizedDescription)")
        }
    }
}
