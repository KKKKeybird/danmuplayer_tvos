/// 剧集卡片组件
import SwiftUI

/// 剧集卡片
@available(tvOS 17.0, *)
struct EpisodeCard: View {
    let episode: JellyfinEpisode
    let viewModel: JellyfinMediaLibraryViewModel
    let onPlay: (JellyfinMediaItem) -> Void
    
    var body: some View {
        Button(action: {
            onPlay(episode)
        }) {
            HStack(spacing: 16) {
                // 剧集缩略图
                CachedAsyncImage(url: viewModel.getImageUrl(for: episode, type: "Primary", maxWidth: 300)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 160, height: 90)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 160, height: 90)
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // 剧集信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let seasonNumber = episode.parentIndexNumber {
                            Text("S\(seasonNumber)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                        
                        if let episodeNumber = episode.indexNumber {
                            Text("E\(episodeNumber)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                        
                        Spacer()
                        
                        if let duration = episode.duration {
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(episode.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // 观看进度
                    if let userData = episode.userData, userData.played {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("已观看")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else if let userData = episode.userData, 
                              let percentage = userData.playedPercentage, 
                              percentage > 0 {
                        ProgressView(value: percentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(percentage))% 已观看")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // 播放图标
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.purple)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)分钟"
    }
}

#Preview {
    EpisodeCard(
        episode: JellyfinMediaItem(
            id: "preview",
            name: "示例剧集",
            serverId: "server1",
            etag: nil,
            dateCreated: nil,
            canDelete: nil,
            canDownload: nil,
            sortName: nil,
            type: "Episode",
            locationType: nil,
            userData: nil,
            productionYear: nil,
            status: nil,
            endDate: nil,
            overview: "这是一个示例剧集的概述信息，用于预览显示。",
            communityRating: nil,
            officialRating: nil,
            runTimeTicks: 162000000000, // 45分钟 (45 * 60 * 10,000,000 ticks)
            genres: nil,
            tags: nil,
            imageTags: nil,
            seriesName: nil,
            seriesId: nil,
            seasonId: nil,
            seasonName: nil,
            indexNumber: 1,
            parentIndexNumber: 1,
            primaryImageAspectRatio: nil
        ),
        viewModel: JellyfinMediaLibraryViewModel(config: MediaLibraryConfig(
            id: UUID(),
            name: "Preview",
            serverURL: "http://localhost:8096",
            serverType: .jellyfin,
            username: nil,
            password: nil,
            apiKey: nil,
            userId: nil
        )),
        onPlay: { _ in }
    )
    .padding()
}
