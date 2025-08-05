import Foundation
import SwiftUI

/// 弹幕数据解析器
struct DanmakuParser {
    
    /// 解析的弹幕数据
    struct ParsedComment {
        let time: Double        // 出现时间（秒）
        let mode: Int          // 弹幕模式：1-普通，4-底部，5-顶部
        let color: Color       // 弹幕颜色
        let userId: String     // 用户ID
        let content: String    // 弹幕内容
    }
    
    /// 从DanDanPlay API响应解析弹幕数据
    /// - Parameter data: API返回的JSON数据
    /// - Returns: 解析后的弹幕数组
    static func parseComments(from data: Data) -> [ParsedComment] {
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: data) else {
            print("无法解析弹幕JSON数据")
            return []
        }
        
        return commentResult.comments.compactMap { comment in
            parseComment(p: comment.p, m: comment.m)
        }
    }
    
    /// 解析单条弹幕
    /// - Parameters:
    ///   - p: 弹幕参数字符串，格式：时间,模式,颜色,用户ID
    ///   - m: 弹幕内容
    /// - Returns: 解析后的弹幕对象
    private static func parseComment(p: String, m: String) -> ParsedComment? {
        let parts = p.split(separator: ",")
        guard parts.count >= 4 else {
            print("弹幕参数格式错误: \(p)")
            return nil
        }
        
        // 解析时间
        guard let time = Double(parts[0]) else {
            print("无法解析弹幕时间: \(parts[0])")
            return nil
        }
        
        // 解析模式
        guard let mode = Int(parts[1]) else {
            print("无法解析弹幕模式: \(parts[1])")
            return nil
        }
        
        // 解析颜色
        guard let colorInt = Int(parts[2]) else {
            print("无法解析弹幕颜色: \(parts[2])")
            return nil
        }
        let color = parseColor(from: colorInt)
        
        // 解析用户ID
        let userId = String(parts[3])
        
        return ParsedComment(
            time: time,
            mode: mode,
            color: color,
            userId: userId,
            content: m
        )
    }
    
    /// 将整数颜色值转换为SwiftUI Color
    /// 算法：R×256×256 + G×256 + B
    /// - Parameter colorInt: 32位整数颜色值
    /// - Returns: SwiftUI Color对象
    private static func parseColor(from colorInt: Int) -> Color {
        let red = Double((colorInt >> 16) & 0xFF) / 255.0
        let green = Double((colorInt >> 8) & 0xFF) / 255.0
        let blue = Double(colorInt & 0xFF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
}

/// 弹幕模式枚举
enum DanmakuMode: Int, CaseIterable {
    case normal = 1     // 普通弹幕
    case bottom = 4     // 底部弹幕
    case top = 5        // 顶部弹幕
    
    var description: String {
        switch self {
        case .normal:
            return "普通弹幕"
        case .bottom:
            return "底部弹幕"
        case .top:
            return "顶部弹幕"
        }
    }
}
