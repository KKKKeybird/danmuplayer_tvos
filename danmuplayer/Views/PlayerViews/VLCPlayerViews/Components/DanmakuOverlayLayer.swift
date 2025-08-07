import SwiftUI

@available(tvOS 17.0, *)
struct DanmakuOverlayLayer: View {
    let comments: [DanmakuComment]
    let settings: DanmakuSettings
    let currentTime: Int
    
    @State private var displayingComments: [DisplayingComment] = []
    
    struct DisplayingComment: Identifiable {
        let id = UUID()
        let comment: DanmakuComment
        let startTime: Date
        var position: CGPoint
        let speed: CGFloat
        
        var isExpired: Bool {
            Date().timeIntervalSince(startTime) > 8.0 // 8秒后消失
        }
    }
    
    enum DanmakuType {
        case scroll, top, bottom
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(displayingComments) { displayingComment in
                    Text(displayingComment.comment.content)
                        .font(.system(size: CGFloat(settings.fontSize)))
                        .foregroundColor(displayingComment.comment.color)
                        .shadow(color: .black, radius: 1, x: 1, y: 1)
                        .position(displayingComment.position)
                        .transition(.opacity)
                }
            }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                updateDisplayingComments(in: geometry.size)
            }
            .onChange(of: currentTime) { _, newTime in
                addNewComments(for: newTime, in: geometry.size)
            }
        }
    }
    
    private func updateDisplayingComments(in size: CGSize) {
        // 移除过期弹幕
        displayingComments.removeAll { $0.isExpired }
        
        // 更新弹幕位置
        for i in displayingComments.indices {
            let elapsed = Date().timeIntervalSince(displayingComments[i].startTime)
            let progress = elapsed / 8.0 // 8秒内滑过屏幕
            
            if displayingComments[i].comment.isScrolling {
                // 滚动弹幕：从右到左
                displayingComments[i].position.x = size.width - CGFloat(progress) * (size.width + 200)
            }
            // 顶部和底部弹幕保持固定位置
        }
    }
    
    private func addNewComments(for time: Int, in size: CGSize) {
        let newComments = comments.filter { comment in
            abs(Int(comment.time) - time) <= 1 && // 当前时间前后1秒内的弹幕
            !displayingComments.contains { $0.comment.id == comment.id }
        }
        
        for comment in newComments {
            let position = calculateInitialPosition(for: comment, in: size)
            let speed = calculateSpeed(for: comment, in: size)
            
            let displayingComment = DisplayingComment(
                comment: comment,
                startTime: Date(),
                position: position,
                speed: speed
            )
            
            displayingComments.append(displayingComment)
        }
    }
    
    private func calculateInitialPosition(for comment: DanmakuComment, in size: CGSize) -> CGPoint {
        let y: CGFloat
        
        if comment.isScrolling {
            // 滚动弹幕：随机高度，避开顶部和底部
            let availableHeight = size.height * 0.6 // 使用屏幕中间60%的高度
            let startY = size.height * 0.2 // 从屏幕20%处开始
            y = startY + CGFloat.random(in: 0...availableHeight)
        } else if comment.isTop {
            // 顶部弹幕
            y = size.height * 0.15
        } else if comment.isBottom {
            // 底部弹幕
            y = size.height * 0.85
        } else {
            // 默认滚动弹幕
            let availableHeight = size.height * 0.6
            let startY = size.height * 0.2
            y = startY + CGFloat.random(in: 0...availableHeight)
        }
        
        let x: CGFloat = comment.isScrolling ? size.width + 100 : size.width / 2
        
        return CGPoint(x: x, y: y)
    }
    
    private func calculateSpeed(for comment: DanmakuComment, in size: CGSize) -> CGFloat {
        if comment.isScrolling {
            return (size.width + 200) / (8.0 * 60) // 8秒内滑过屏幕，60fps
        } else {
            return 0 // 固定弹幕不移动
        }
    }
}
