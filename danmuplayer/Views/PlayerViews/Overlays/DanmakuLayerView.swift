import SwiftUI
import QuartzCore
import UIKit

@available(tvOS 17.0, *)
struct DanmakuLayerView: UIViewRepresentable {
    let comments: [DanmakuComment]
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @Binding var settings: DanmakuSettings

    func makeUIView(context: Context) -> DanmakuCoreView {
        let view = DanmakuCoreView()
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: DanmakuCoreView, context: Context) {
        uiView.applySettings(settings)
        uiView.update(comments: comments, currentTime: currentTime, isPlaying: isPlaying)
    }
}

@available(tvOS 17.0, *)
final class DanmakuCoreView: UIView {
    private var laneManager = DanmakuLaneManager(maxLanes: 12)
    private var activeLayers: [UUID: CATextLayer] = [:]
    private var spawned: Set<UUID> = []
    private var lastSize: CGSize = .zero
    private var lastSettings: DanmakuSettings = DanmakuSettings()
    private var lastTime: Double = 0

    // 播放控制
    private var isPaused: Bool = false
    private var pausedTime: CFTimeInterval = 0

    override class var layerClass: AnyClass { CALayer.self }

    func applySettings(_ settings: DanmakuSettings) {
        // 设置变化时更新显示区域和最大行数
        if settings.displayAreaPercent != lastSettings.displayAreaPercent || 
           settings.fontSize != lastSettings.fontSize {
            updateDisplayArea()
        }
        lastSettings = settings
    }
    
    private func updateDisplayArea() {
        // 根据显示区域百分比和字体大小计算最大行数
        let displayHeight = bounds.height * CGFloat(lastSettings.displayAreaPercent)
        let lineHeight = computeLineHeight()
        let maxLines = max(1, Int(displayHeight / lineHeight))
        laneManager.maxLanes = maxLines
    }

    func update(comments: [DanmakuComment], currentTime: Double, isPlaying: Bool) {
        if bounds.size != lastSize { 
            lastSize = bounds.size 
            updateDisplayArea()  // 屏幕尺寸变化时重新计算显示区域
        }

        // 播放/暂停
        if isPlaying && isPaused {
            resumeAll()
        } else if !isPlaying && !isPaused {
            pauseAll()
        }

        // 仅在播放时推进；暂停时不生成新弹幕
        guard isPlaying, lastSettings.isEnabled, bounds.width > 1, bounds.height > 1 else { return }

        // 可见窗口（生成即开始动画，所以窗口短一点）
        let window: ClosedRange<Double> = currentTime...(currentTime + 2.0)
        let filtered = comments.filter { c in
            guard !spawned.contains(c.id) else { return false }
            if c.isScrolling && !lastSettings.showScrolling { return false }
            if c.isTop && !lastSettings.showTop { return false }
            if c.isBottom && !lastSettings.showBottom { return false }
            return window.contains(c.time)
        }.sorted { $0.time < $1.time }

        // 按密度控制生成数量，播放开始时更严格限制
        let maxVisible = max(1, Int(Double(lastSettings.maxCount) * lastSettings.density))
        
        // 播放开始的前10秒内，更严格地控制弹幕数量
        let timeSinceStart = max(0, currentTime)
        let isEarlyPlayback = timeSinceStart < 10.0
        
        let maxPerFrame: Int
        if isEarlyPlayback {
            // 前10秒：每帧最多2条弹幕，随时间逐渐增加
            let progressRatio = timeSinceStart / 10.0
            maxPerFrame = min(2 + Int(progressRatio * 3), min(5, maxVisible))
        } else {
            // 正常播放：每帧最多5条弹幕
            maxPerFrame = min(5, maxVisible)
        }
        
        let toSpawn = Array(filtered.prefix(maxPerFrame))

        for c in toSpawn {
            spawn(comment: c, currentTime: currentTime)
        }

        lastTime = currentTime
    }

    private func spawn(comment: DanmakuComment, currentTime: Double) {
        spawned.insert(comment.id)

        let fontSize = computeFontSize()
        let textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.alignmentMode = .left
        textLayer.truncationMode = .end
        textLayer.isWrapped = false
        // 确保 CATextLayer 不覆盖 NSAttributedString 的颜色
        textLayer.foregroundColor = nil


        let textColor = UIColor(
            red: CGFloat((comment.colorValue >> 16) & 0xFF) / 255.0,
            green: CGFloat((comment.colorValue >> 8) & 0xFF) / 255.0,
            blue: CGFloat(comment.colorValue & 0xFF) / 255.0,
            alpha: CGFloat(lastSettings.opacity)
        )
        
        // 使用默认系统字体，无描边
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        textLayer.string = NSAttributedString(string: comment.content, attributes: attributes)
        textLayer.contentsScale = UIScreen.main.scale
        
        let textSize = measureText(comment.content, fontSize: fontSize)

        let lane: Int
        if comment.isScrolling {
            lane = laneManager.assignScrollingLane(for: comment, duration: 8.0 / max(0.1, lastSettings.speed))
        } else if comment.isTop {
            lane = laneManager.assignTopLane(for: comment, duration: 4.0)
        } else {
            lane = laneManager.assignBottomLane(for: comment, duration: 4.0)
        }

        let y = computeLineY(for: lane)
        let padding: CGFloat = 30
        let startX = bounds.width + textSize.width / 2 + padding
        let endX = -textSize.width / 2 - padding

        let height = max(1, textSize.height)
        textLayer.bounds = CGRect(x: 0, y: 0, width: textSize.width, height: height)
        textLayer.position = CGPoint(x: startX, y: y)
        layer.addSublayer(textLayer)
        activeLayers[comment.id] = textLayer

        // 动画：右->左
        if comment.isScrolling {
            let distance = startX - endX
            let pxPerSec: CGFloat = max(60, 100 * CGFloat(lastSettings.speed))
            let totalDuration = CFTimeInterval(distance / pxPerSec)
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = startX
            anim.toValue = endX
            anim.duration = totalDuration
            anim.timingFunction = CAMediaTimingFunction(name: .linear)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = true

            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self, weak textLayer] in
                guard let self = self, let layerRef = textLayer else { return }
                layerRef.removeFromSuperlayer()
                self.activeLayers[comment.id] = nil
            }
            textLayer.add(anim, forKey: "scroll")
            CATransaction.commit()
        } else {
            // 顶部/底部固定显示一定时间
            let displayDuration: CFTimeInterval = 4.0
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self, weak textLayer] in
                guard let self = self, let layerRef = textLayer else { return }
                layerRef.removeFromSuperlayer()
                self.activeLayers[comment.id] = nil
            }
        }

        if isPaused { 
            pause(layer: textLayer)
        }
    }

    // MARK: - Helpers
    private func computeLineHeight() -> CGFloat {
        // 基于字体大小计算行高，添加一些间距
        let fontSize = max(16, lastSettings.fontSize)
        return CGFloat(fontSize * 1.2) // 行高 = 字体大小 * 1.2
    }

    private func computeFontSize() -> CGFloat { 
        return CGFloat(max(16, lastSettings.fontSize))
    }

    private func computeLineY(for lane: Int) -> CGFloat {
        let h = computeLineHeight()
        // 从屏幕顶部开始计算显示区域
        return h * CGFloat(lane) + h * 0.5
    }

    private func measureText(_ text: String, fontSize: CGFloat) -> CGSize {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    



    // MARK: - Pause/Resume all
    private func pauseAll() {
        isPaused = true
        pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    private func resumeAll() {
        isPaused = false
        let paused = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - paused
        layer.beginTime = timeSincePause
    }

    private func pause(layer: CALayer) {
        let paused = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = paused
    }
}


