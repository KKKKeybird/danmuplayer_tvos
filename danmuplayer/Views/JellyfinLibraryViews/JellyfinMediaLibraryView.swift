/// Jellyfin媒体库主页
import SwiftUI

/// Jellyfin媒体库主页，展示海报墙和媒体内容
@available(tvOS 17.0, *)
struct JellyfinMediaLibraryView: View {
    let config: MediaLibraryConfig
    @StateObject private var viewModel: JellyfinMediaLibraryViewModel
    @StateObject private var sortStore = MediaLibrarySortStore.shared
    @State private var selectedItem: JellyfinMediaItem?
    @State private var showingMediaDetail = false
    @State private var sortOption: SortOption = .recentlyWatched
    @State private var isAscending: Bool = true
    @State private var showingSortMenu = false
    @State private var refreshTrigger = UUID()
    
    enum SortOption: String, CaseIterable, Hashable {
        case recentlyWatched = "最近观看"
        case dateAdded = "添加时间"
        case name = "名称"
        case releaseDate = "上映时间"
        case rating = "评分"
        
        var systemImage: String {
            switch self {
            case .recentlyWatched: return "clock.arrow.circlepath"
            case .dateAdded: return "calendar.badge.plus"
            case .name: return "textformat.abc"
            case .releaseDate: return "calendar"
            case .rating: return "star"
            }
        }
    }
    
    init(config: MediaLibraryConfig) {
        self.config = config
        self._viewModel = StateObject(wrappedValue: JellyfinMediaLibraryViewModel(config: config))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.libraries.isEmpty && viewModel.mediaItems.isEmpty {
                LoadingStateView(
                    message: viewModel.isAuthenticated ? "加载媒体库中..." : "正在连接..."
                )
            } else if !viewModel.isAuthenticated {
                JellyfinAuthenticationView(
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    isPerformingDetailedTest: viewModel.isPerformingDetailedTest,
                    connectionTestResults: viewModel.connectionTestResults,
                    onAuthenticate: {
                        viewModel.authenticate()
                    },
                    onPerformDetailedTest: {
                        await viewModel.performDetailedConnectionTest()
                    }
                )
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(
                    message: errorMessage,
                    retryAction: {
                        viewModel.refresh()
                    }
                )
            } else {
                mediaGridView
            }
        }
        .navigationTitle("媒体库")
        .onAppear {
            // 仅在首次或无数据时触发，避免重复认证导致长时间 isLoading
            if !viewModel.isAuthenticated && !viewModel.isLoading && viewModel.libraries.isEmpty && viewModel.mediaItems.isEmpty {
                viewModel.authenticate()
            }
        }
        .refreshable {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingMediaDetail) {
            if let selectedItem = selectedItem {
                JellyfinMediaDetailView(
                    item: selectedItem, 
                    viewModel: viewModel
                )
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var sortedMediaItems: [JellyfinMediaItem] {
        // 依赖 refreshTrigger 确保排序变化时视图刷新
        _ = refreshTrigger
        return viewModel.mediaItems.sorted { item1, item2 in
            switch sortOption {
            case .recentlyWatched:
                // 按播放进度排序，优先显示有播放记录的项目
                let progress1 = item1.userData?.playbackPositionTicks ?? 0
                let progress2 = item2.userData?.playbackPositionTicks ?? 0
                let playCount1 = item1.userData?.playCount ?? 0
                let playCount2 = item2.userData?.playCount ?? 0
                var result: Bool
                if (progress1 > 0 || playCount1 > 0) && (progress2 == 0 && playCount2 == 0) {
                    result = true
                } else if (progress1 == 0 && playCount1 == 0) && (progress2 > 0 || playCount2 > 0) {
                    result = false
                } else {
                    result = progress1 > progress2
                }
                return isAscending ? result : !result
                
            case .dateAdded:
                // 将字符串日期转换为Date进行比较
                let date1 = parseDateString(item1.dateCreated) ?? Date.distantPast
                let date2 = parseDateString(item2.dateCreated) ?? Date.distantPast
                let result = date1 > date2
                return isAscending ? result : !result
                
            case .name:
                let result = item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                return isAscending ? result : !result
                
            case .releaseDate:
                let year1 = item1.productionYear ?? 0
                let year2 = item2.productionYear ?? 0
                let result = year1 > year2
                return isAscending ? result : !result
                
            case .rating:
                let rating1 = item1.communityRating ?? 0
                let rating2 = item2.communityRating ?? 0
                let result = rating1 > rating2
                return isAscending ? result : !result
            }
        }
    }
    
    // MARK: - 子视图
    
    private var mediaGridView: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 30)
                ], spacing: 30) {
                    ForEach(sortedMediaItems) { item in
                        MediaItemCard(
                            item: item,
                            imageUrl: viewModel.getImageUrl(for: item),
                            onTap: {
                                handleItemTap(item)
                            }
                        )
                        .frame(width: 220, height: 420)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSortMenu.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sortOption.systemImage)
                                .font(.system(size: 16, weight: .medium))
                            Text("排序")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingSortMenu) {
                JellyfinSortView(
                    isPresented: $showingSortMenu,
                    selectedOption: $sortOption,
                    isAscending: $isAscending,
                    onApply: {
                        // 强制触发刷新
                        saveSortConfig()
                        refreshTrigger = UUID()
                    }
                )
            }
            .onAppear {
                loadSortConfig()
            }
            .onChange(of: sortOption) { _, _ in
                saveSortConfig()
                refreshTrigger = UUID() // 强制刷新视图
            }
            .onChange(of: isAscending) { _, _ in
                saveSortConfig()
                refreshTrigger = UUID() // 强制刷新视图
            }
        }
    }
    
    // MARK: - 点击逻辑处理
    
    private func handleItemTap(_ item: JellyfinMediaItem) {
        selectedItem = item
        
        // 根据项目API设计：所有播放逻辑都在JellyfinMediaDetailView中处理
        // 这里只负责显示详情页
        showingMediaDetail = true
    }
    
    // MARK: - 排序配置管理
    
    private func loadSortConfig() {
        let libraryId = config.id.uuidString
        let config = sortStore.getJellyfinSortConfig(for: libraryId)
        
        // 将字符串转换为SortOption
        if let option = SortOption(rawValue: config.sortOption) {
            sortOption = option
        }
        isAscending = config.isAscending
    }
    
    private func saveSortConfig() {
        let libraryId = config.id.uuidString
        sortStore.setJellyfinSortConfig(for: libraryId, sortOption: sortOption.rawValue, isAscending: isAscending)
    }
    
    // MARK: - 辅助方法
    
    /// 解析Jellyfin日期字符串为Date对象
    private func parseDateString(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 尝试完整格式解析
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
