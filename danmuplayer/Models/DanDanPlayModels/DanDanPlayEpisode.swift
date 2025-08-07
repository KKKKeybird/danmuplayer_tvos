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
    
    /// 获取格式化的偏移时间描述
    var shiftDescription: String? {
        guard let shift = shift else { return nil }
        
        if shift == 0 {
            return "无偏移"
        } else if shift > 0 {
            return "延迟 \(String(format: "%.1f", shift)) 秒"
        } else {
            return "提前 \(String(format: "%.1f", abs(shift))) 秒"
        }
    }
}
