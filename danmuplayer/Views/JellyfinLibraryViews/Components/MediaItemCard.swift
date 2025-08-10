/// 媒体项目卡片组件
import SwiftUI

/// 媒体项目卡片
@available(tvOS 17.0, *)
struct MediaItemCard: View {
    let item: JellyfinMediaItem
    let imageUrl: URL?
    let onTap: () -> Void
    
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 海报图片容器
            ZStack {
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
                
                // 选中状态效果
                if isFocused {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 3)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 0.2), value: isFocused)
                    
                    // 添加阴影效果
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                        .scaleEffect(1.05)
                }
            }
            
            // 标题和信息
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(isFocused ? .white : .primary)
                
                HStack(spacing: 16) {
                    if let year = item.productionYear {
                        Text(String(year))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let rating = item.communityRating {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 观看进度
                if let userData = item.userData, userData.played {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                        Text("已观看")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.green)
                    }
                } else if let userData = item.userData, 
                          let percentage = userData.playedPercentage, 
                          percentage > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: percentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 1.0)
                        Text("\(Int(percentage))% 已观看")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 220, height: 420)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .focusable(true)
        .focused($isFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .buttonStyle(PlainButtonStyle())
    }
}
