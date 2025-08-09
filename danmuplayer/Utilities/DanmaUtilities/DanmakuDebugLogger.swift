import Foundation
import SwiftUI

/// 弹幕调试日志收集器
@MainActor
class DanmakuDebugLogger: ObservableObject {
    static let shared = DanmakuDebugLogger()
    
    @Published private(set) var logs: [String] = []
    private let maxLines = 400
    
    private init() {}
    
    func clear() {
        logs.removeAll()
    }
    
    func add(_ message: String) {
        let timestamp = Self.timestampString()
        logs.append("[\(timestamp)] \(message)")
        if logs.count > maxLines {
            logs.removeFirst(logs.count - maxLines)
        }
        #if DEBUG
        print("[DanmakuDebug] \(message)")
        #endif
    }
    
    func add(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        add("\(message)  (@ \((file as NSString).lastPathComponent):\(line) \(function))")
    }
    
    private static func timestampString() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df.string(from: Date())
    }
}


