/// 弹幕匹配浮窗
import SwiftUI

/// 弹幕匹配浮窗，将当前播放视频Url传入DanDanPlayAPI获取全部剧集可能列表，用户选择后重新加载弹幕轨并播放
@available(tvOS 17.0, *)
struct DanmaSelectPopover: View {
    let candidateEpisodes: [DanDanPlayEpisode]
    let videoURL: URL
    let onEpisodeSelected: (DanDanPlayEpisode) -> Void
    let onReloadDanmaku: (DanDanPlayEpisode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("选择弹幕匹配")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        if candidateEpisodes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                                Text("未找到匹配的弹幕")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("请尝试重新搜索或手动输入番剧信息")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(candidateEpisodes) { episode in
                                Button(action: {
                                    onEpisodeSelected(episode)
                                    onReloadDanmaku(episode)
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(episode.animeTitle)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Text(episode.episodeTitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                        HStack {
                                            Text("动画ID: \(episode.animeId)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("剧集ID: \(episode.episodeId)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 8)
                                    .background(Color.blue.opacity(0.08))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(20)
                }
                Divider()
                HStack {
                    Spacer()
                    Button("取消") { dismiss() }
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.98))
                    .shadow(radius: 16)
            )
        }
    }
}
