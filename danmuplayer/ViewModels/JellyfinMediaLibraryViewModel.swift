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
    
    // MARK: - 创建统一的视频播放器视图模型
    func createVideoPlayerViewModel(for item: JellyfinMediaItem) -> VideoPlayerViewModel {
        // 使用统一播放器工厂创建Jellyfin播放器
        guard let playbackURL = client.getPlaybackUrl(itemId: item.id) else {
            // 如果无法获取播放URL，返回基本的ViewModel并设置错误
            let viewModel = VideoPlayerViewModel()
            viewModel.errorMessage = "无法获取播放地址"
            return viewModel
        }
        
        // 使用统一的数据源适配器
        let dataSource = JellyfinDataSource(
            mediaItem: item,
            videoURL: playbackURL
        )
        
        let viewModel = VideoPlayerViewModel(dataSource: dataSource)
        // dismiss 将在视图中设置
        return viewModel
    }
    
    // MARK: - 获取剧集列表
    func getEpisodes(for seriesId: String, completion: @escaping (Result<[JellyfinEpisode], Error>) -> Void) {
        client.getEpisodes(seriesId: seriesId, completion: completion)
    }
    
    // MARK: - 诊断连接问题
    func diagnoseConnection() -> String {
        var diagnosis = "连接诊断信息:\n\n"
        diagnosis += "服务器地址: \(config.serverURL)\n"
        
        if let url = URL(string: config.serverURL) {
            diagnosis += "协议: \(url.scheme ?? "未知")\n"
            diagnosis += "主机: \(url.host ?? "未知")\n"
            diagnosis += "端口: \(url.port?.description ?? "默认")\n"
        }
        
        diagnosis += "\n可能的解决方案:\n"
        diagnosis += "1. 检查服务器是否正在运行\n"
        diagnosis += "2. 验证服务器地址是否正确\n"
        diagnosis += "3. 确认网络连接正常\n"
        diagnosis += "4. 检查防火墙设置\n"
        diagnosis += "5. 如果使用 HTTPS，确认证书有效\n"
        diagnosis += "6. 尝试在浏览器中访问该地址\n"
        diagnosis += "7. 检查 Jellyfin 服务器是否允许外部连接"
        
        return diagnosis
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
