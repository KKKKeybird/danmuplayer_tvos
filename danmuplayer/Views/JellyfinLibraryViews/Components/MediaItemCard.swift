/// 媒体项目卡片组件
import SwiftUI

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
                CachedAsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                            .clipped()
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.3))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                Image(systemName: item.type == "Movie" ? "film" : "tv")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
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

#Preview {
    MediaItemCard(
        item: JellyfinMediaItem(
            id: "preview",
            name: "示例电影",
            type: "Movie",
            productionYear: 2023,
            communityRating: 8.5,
            userData: nil,
            dateCreated: nil
        ),
        imageUrl: nil,
        onTap: {}
    )
    .frame(width: 200)
    .padding()
}
