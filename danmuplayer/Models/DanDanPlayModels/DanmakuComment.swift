/// 弹幕数据模型
import Foundation
import SwiftUI

/// 弹幕评论数据模型
struct DanmakuComment: Codable, Identifiable, Equatable {
    let id = UUID()
    let time: Double // 显示时间（秒）
    let mode: Int // 弹幕类型：1-滚动，4-底部，5-顶部
    let fontSize: Int // 字体大小
    let colorValue: Int // 颜色值
    let timestamp: TimeInterval // 发送时间戳
    let content: String // 弹幕内容
    
    enum CodingKeys: String, CodingKey {
        case time = "p"
        case mode, fontSize
        case colorValue = "color"
        case timestamp, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解析弹弹Play的p字段格式：时间,模式,字体大小,颜色,时间戳
        let pString = try container.decode(String.self, forKey: .time)
        let pComponents = pString.components(separatedBy: ",")
        
        guard pComponents.count >= 5 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid p field format")
            )
        }
        
        self.time = Double(pComponents[0]) ?? 0
        self.mode = Int(pComponents[1]) ?? 1
        self.fontSize = Int(pComponents[2]) ?? 16
        self.colorValue = Int(pComponents[3]) ?? 0xFFFFFF
        self.timestamp = Double(pComponents[4]) ?? 0
        self.content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let pString = "\(time),\(mode),\(fontSize),\(colorValue),\(Int(timestamp))"
        try container.encode(pString, forKey: .time)
        try container.encode(content, forKey: .content)
    }
    
    /// 便利初始化器 - 用于从解析的弹幕数据创建
    init(time: Double, mode: Int, fontSize: Int = 25, colorValue: Int, timestamp: TimeInterval, content: String) {
        self.time = time
        self.mode = mode
        self.fontSize = fontSize
        self.colorValue = colorValue
        self.timestamp = timestamp
        self.content = content
    }
    
    /// 获取弹幕颜色
    var color: Color {
        let red = Double((colorValue >> 16) & 0xFF) / 255.0
        let green = Double((colorValue >> 8) & 0xFF) / 255.0
        let blue = Double(colorValue & 0xFF) / 255.0
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
    
    /// 判断是否为滚动弹幕
    var isScrolling: Bool {
        return mode == 1 || mode == 6
    }
    
    /// 判断是否为顶部弹幕
    var isTop: Bool {
        return mode == 5
    }
    
    /// 判断是否为底部弹幕
    var isBottom: Bool {
        return mode == 4
    }
    
    // MARK: - Equatable
    static func == (lhs: DanmakuComment, rhs: DanmakuComment) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 弹弹Play API响应格式
struct DanmakuResponse: Codable {
    let count: Int
    let comments: [DanmakuComment]
}
