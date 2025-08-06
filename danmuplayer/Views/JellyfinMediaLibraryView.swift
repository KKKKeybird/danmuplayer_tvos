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
    
    init(config: MediaLibraryConfig) {
        self.config = config
        self._viewModel = StateObject(wrappedValue: JellyfinMediaLibraryViewModel(config: config))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.libraries.isEmpty && viewModel.mediaItems.isEmpty {
                loadingView
            } else if !viewModel.isAuthenticated {
                authenticationView
            } else if viewModel.libraries.isEmpty && !viewModel.isLoading {
                emptyLibrariesView
            } else if viewModel.selectedLibrary == nil {
                librarySelectionView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else {
                mediaGridView
            }
        }
        .navigationTitle(viewModel.selectedLibrary?.name ?? config.name)
        .onAppear {
            viewModel.authenticate()
        }
        .refreshable {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let selectedItem = selectedItem {
                VideoPlayerView(viewModel: viewModel.createVideoPlayerViewModel(for: selectedItem))
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
    
    // MARK: - 子视图
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
            Text(viewModel.isAuthenticated ? "加载媒体库中..." : "正在连接...")
                .font(.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var authenticationView: some View {
        VStack(spacing: 30) {
            Text("连接到Jellyfin服务器")
                .font(.title2)
            
            if viewModel.isLoading {
                ProgressView("正在连接...")
            } else {
                VStack(spacing: 20) {
                    Button("登录并加载媒体库") {
                        viewModel.authenticate()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // 连接诊断按钮
                    Button("连接诊断") {
                        Task {
                            await viewModel.performDetailedConnectionTest()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPerformingDetailedTest)
                    
                    if viewModel.isPerformingDetailedTest {
                        ProgressView("正在执行诊断测试...")
                            .padding(.top)
                    }
                    
                    // 显示诊断结果
                    if !viewModel.connectionTestResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("诊断结果:")
                                .font(.headline)
                                .padding(.top)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(viewModel.connectionTestResults, id: \.self) { result in
                                        Text(result)
                                            .font(.caption)
                                            .foregroundColor(result.contains("✅") ? .green : .red)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
    
    private var emptyLibrariesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("没有找到媒体库")
                .font(.title2)
                .fontWeight(.semibold)
            Text("请在 Jellyfin 服务器中配置电影或电视剧媒体库")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("刷新") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var librarySelectionView: some View {
        VStack(spacing: 30) {
            Text("选择媒体库")
                .font(.title)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)
            ], spacing: 20) {
                ForEach(viewModel.libraries) { library in
                    Button(action: {
                        viewModel.selectLibrary(library)
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: library.collectionType == "movies" ? "film" : "tv")
                                .font(.system(size: 40))
                                .foregroundStyle(.purple)
                            
                            Text(library.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(library.collectionType == "movies" ? "电影" : 
                                 library.collectionType == "tvshows" ? "电视剧" : "媒体")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mediaGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 20)
            ], spacing: 30) {
                ForEach(viewModel.mediaItems) { item in
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
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(viewModel.libraries) { library in
                        Button(library.name) {
                            viewModel.selectLibrary(library)
                        }
                    }
                } label: {
                    Label("切换媒体库", systemImage: "switch.2")
                }
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 媒体项目卡片
@available(tvOS 17.0, *)
struct MediaItemCard: View {
    let item: JellyfinMediaItem
    let imageUrl: URL?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 海报图片
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(
                            Image(systemName: item.type == "Movie" ? "film" : "tv")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                        )
                }
                .cornerRadius(8)
                
                // 标题和信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let year = item.productionYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let rating = item.communityRating {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 观看进度
                    if let userData = item.userData, userData.played {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("已观看")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else if let userData = item.userData, 
                              let percentage = userData.playedPercentage, 
                              percentage > 0 {
                        ProgressView(value: percentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(percentage))% 已观看")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
