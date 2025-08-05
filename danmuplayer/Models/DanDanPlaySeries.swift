/// 番剧信息模型
import Foundation

/// 表示弹弹Play识别出的番剧信息
struct DanDanPlaySeries: Identifiable, Codable {
    let animeId: Int
    let animeTitle: String
    let episodeId: Int
    let episodeTitle: String
    
    var id: Int { episodeId }
    
    var displayTitle: String {
        return "\(animeTitle) - \(episodeTitle)"
    }
}
