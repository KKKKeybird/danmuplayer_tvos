/// Jellyfin媒体库主页
import SwiftUI

/// Jellyfin媒体库主页，展示海报墙和媒体内容
@available(tvOS 17.0, *)
struct JellyfinMediaLibraryView: View {
    let config: MediaLibraryConfig
    @StateObject private var viewModel: JellyfinMediaLibraryViewModel
    @State private var selectedItem: JellyfinMediaItem?
    @State private var showingVideoPlayer = false
    @State private var showingMediaDetail = false
    @State private var sortOption: SortOption = .recentlyWatched
    @State private var showingSortMenu = false
    
    enum SortOption: String, CaseIterable {
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
            viewModel.authenticate()
        }
        .refreshable {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let selectedItem = selectedItem {
                // 使用新的简化播放器架构
                NewJellyfinPlayerContainer(
                    mediaItem: selectedItem,
                    jellyfinClient: viewModel.jellyfinClient
                )
            }
        }
        .sheet(isPresented: $showingMediaDetail) {
            if let selectedItem = selectedItem {
                JellyfinMediaDetailView(
                    item: selectedItem, 
                    viewModel: viewModel,
                    onPlay: { item in
                        self.selectedItem = item
                        showingVideoPlayer = true
                    }
                )
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var sortedMediaItems: [JellyfinMediaItem] {
        viewModel.mediaItems.sorted { item1, item2 in
            switch sortOption {
            case .recentlyWatched:
                // 按最近观看时间排序，优先显示有播放记录的项目
                let date1 = item1.userData?.lastPlayedDate
                let date2 = item2.userData?.lastPlayedDate
                
                switch (date1, date2) {
                case (let d1?, let d2?):
                    return d1 > d2
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (nil, nil):
                    // 如果都没有观看记录，按添加时间排序
                    return (item1.dateCreated ?? Date.distantPast) > (item2.dateCreated ?? Date.distantPast)
                }
                
            case .dateAdded:
                return (item1.dateCreated ?? Date.distantPast) > (item2.dateCreated ?? Date.distantPast)
                
            case .name:
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                
            case .releaseDate:
                let year1 = item1.productionYear ?? 0
                let year2 = item2.productionYear ?? 0
                return year1 > year2
                
            case .rating:
                let rating1 = item1.communityRating ?? 0
                let rating2 = item2.communityRating ?? 0
                return rating1 > rating2
            }
        }
    }
    
    // MARK: - 子视图
    
    private var mediaGridView: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 35)
                ], spacing: 40) {
                    ForEach(sortedMediaItems) { item in
                        MediaItemCard(
                            item: item,
                            imageUrl: viewModel.getImageUrl(for: item),
                            onTap: {
                                selectedItem = item
                                if item.type == "Episode" || (item.type == "Movie" && item.runTimeTicks != nil) {
                                    // 直接播放剧集或电影
                                    showingVideoPlayer = true
                                } else {
                                    // 显示详情页面（用于电视剧系列）
                                    showingMediaDetail = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 30)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSortMenu.toggle()
                    } label: {
                        HStack {
                            Image(systemName: sortOption.systemImage)
                            Text("排序")
                        }
                    }
                }
            }
            
            // 排序选择覆盖层
            if showingSortMenu {
                JellyfinSortSelectionOverlay(
                    isPresented: $showingSortMenu,
                    selectedOption: $sortOption
                )
            }
        }
    }
}
