/// Jellyfin媒体详情页面
import SwiftUI

/// 显示Jellyfin媒体项目的详细信息
@available(tvOS 17.0, *)
struct JellyfinMediaDetailView: View {
    let item: JellyfinMediaItem
    let viewModel: JellyfinMediaLibraryViewModel
    
    @State private var episodes: [JellyfinEpisode] = []
    @State private var isDetailLoading = false
    @State private var isPlayerLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: JellyfinMediaItem?
    @State private var showingVideoPlayer = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题区域
                    headerSection
                    
                    // 概述
                    if let overview = item.overview, !overview.isEmpty {
                        overviewSection(overview)
                    }
                    
                    // 统一的剧集列表显示（电影被当作只有一季一集的剧集）
                    episodesSection
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            }
            .navigationTitle(item.name)
            .onAppear {
                print("[JellyfinMediaDetailView] onAppear called")
                // 统一加载剧集结构（电影被当作只有一季一集的剧集）
                loadEpisodesForUnifiedStructure()
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let selectedItem = selectedItem {
                // 直接在详情页调用播放器
                JellyfinVideoPlayerWrapper(
                    item: selectedItem,
                    viewModel: viewModel,
                    onDismiss: {
                        showingVideoPlayer = false
                        self.selectedItem = nil
                    }
                )
            }
        }
    }
    
    // MARK: - 子视图
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 20) {
            // 海报
            AsyncImage(url: viewModel.getImageUrl(for: item, maxWidth: 300)) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 200, height: 300)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 200, height: 300)
                    .overlay(
                        Image(systemName: item.type == "Movie" ? "film" : "tv")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    )
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 12) {
                Text(item.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack {
                    if let year = item.productionYear {
                        Text(String(year))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let rating = item.officialRating {
                        Text(rating)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let rating = item.communityRating {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                
                if let genres = item.genres, !genres.isEmpty {
                    HStack {
                        ForEach(genres.prefix(3), id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .cornerRadius(8)
                        }
                    }
                }
                
                if let duration = item.duration {
                    Text("时长: \(formatDuration(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("剧情简介")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(overview)
                .font(.body)
                .lineLimit(nil)
                .focusable()
        }
    }
    
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.type == "Movie" ? "播放" : "剧集")
                .font(.title2)
                .fontWeight(.semibold)
            if isDetailLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载剧集中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
            } else if let errorMessage = errorMessage {
                VStack {
                    Text("加载失败: \(errorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("重试") {
                        loadEpisodesForUnifiedStructure()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 20)
            } else if episodes.isEmpty {
                Text("没有找到剧集")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(episodes) { episode in
                        EpisodeCard(
                            episode: episode,
                            viewModel: viewModel,
                            onPlay: playItem
                        )
                        if isPlayerLoading && selectedItem?.id == episode.id {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("正在准备播放...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 方法
    
    /// 播放媒体项目
    /// 根据项目API：点击后传入视频原始文件名，视频流媒体Url和字幕Url进入播放界面
    private func playItem(_ mediaItem: JellyfinMediaItem) {
        // 验证可播放性
        guard viewModel.validatePlayability(for: mediaItem) else {
            // 可以在这里显示错误提示
            return
        }
        // 先显示播放器加载状态
        isPlayerLoading = true
        errorMessage = nil
        selectedItem = mediaItem
        // 预处理媒体（包括获取字幕）
        viewModel.prepareMediaForPlayback(item: mediaItem) { playbackURL, subtitleURLs in
            DispatchQueue.main.async {
                self.isPlayerLoading = false
                // 设置要播放的项目
                self.selectedItem = mediaItem
                self.showingVideoPlayer = true
            }
        }
    }
    
    /// 统一加载剧集结构（电影被当作只有一季一集的剧集）
    private func loadEpisodesForUnifiedStructure() {
        print("[JellyfinMediaDetailView] loadEpisodesForUnifiedStructure called")
        isDetailLoading = true
        errorMessage = nil
        print("[JellyfinMediaDetailView] isDetailLoading set to true")
        viewModel.getEpisodesForUnifiedStructure(for: item) { result in
            Task { @MainActor in
                self.isDetailLoading = false
                print("[JellyfinMediaDetailView] isDetailLoading set to false (callback)")
                switch result {
                case .success(let episodes):
                    self.episodes = episodes.sorted {
                        (($0.parentIndexNumber ?? 0), ($0.indexNumber ?? 0)) <
                        (($1.parentIndexNumber ?? 0), ($1.indexNumber ?? 0))
                    }
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
