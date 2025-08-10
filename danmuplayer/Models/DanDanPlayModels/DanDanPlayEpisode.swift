/// 番剧剧集信息模型
import Foundation

/// 表示弹弹Play识别出的剧集信息
struct DanDanPlayEpisode: Identifiable, Codable {
    let animeId: Int
    let animeTitle: String
    let episodeId: Int
    let episodeTitle: String
    let shift: Double? // 弹幕偏移时间（秒），可为空
    var id: Int { episodeId }
    var displayTitle: String {
        return "\(animeTitle) - \(episodeTitle)"
    }
}
