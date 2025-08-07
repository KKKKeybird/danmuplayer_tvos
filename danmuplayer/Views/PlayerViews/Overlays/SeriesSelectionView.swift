/// 番剧识别列表选择页面
import SwiftUI

/// 番剧识别候选列表页面，供用户选择匹配的番剧
@available(tvOS 17.0, *)
struct SeriesSelectionView: View {
    let seriesList: [DanDanPlayEpisode]
    let onSelection: (DanDanPlayEpisode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if seriesList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("未找到匹配的番剧")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("请尝试重新搜索或手动输入番剧信息")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ForEach(seriesList) { series in
                        Button(action: {
                            onSelection(series)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(series.animeTitle)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Text(series.episodeTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Text("动画ID: \(series.animeId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("剧集ID: \(series.episodeId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("选择番剧")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}
