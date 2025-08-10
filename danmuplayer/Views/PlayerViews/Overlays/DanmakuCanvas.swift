import SwiftUI
import UIKit
import Combine

// 弹幕缓存管理器 - 缓存已渲染的弹幕视图
@available(tvOS 17.0, *)
class DanmakuCacheManager: ObservableObject {
    private var cache: [UUID: AnyView] = [:]
    private let maxCacheSize = 1000
    
    func getCachedView(for id: UUID) -> AnyView? {
        return cache[id]
    }
    
    func cacheView(_ view: AnyView, for id: UUID) {
        if cache.count >= maxCacheSize {
            // 清理最旧的缓存
            let oldestKey = cache.keys.first
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }
        cache[id] = view
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// 弹幕轨道管理器 - 参考知乎文章的高效轨道分配算法
@available(tvOS 17.0, *)
class DanmakuLaneManager: ObservableObject {
    private var scrollingLanes: [Int: Double] = [:] // 轨道号 -> 结束时间
    private var topLanes: [Int: Double] = [:]
    private var bottomLanes: [Int: Double] = [:]
    
    var maxLanes: Int {
        didSet {
            // 当最大轨道数变化时，清理超出范围的轨道
            scrollingLanes = scrollingLanes.filter { $0.key < maxLanes }
            topLanes = topLanes.filter { $0.key < maxLanes }
            bottomLanes = bottomLanes.filter { $0.key < maxLanes }
        }
    }
    
    init(maxLanes: Int) {
        self.maxLanes = maxLanes
    }
    
    // 为滚动弹幕分配轨道
    func assignScrollingLane(for comment: DanmakuComment, duration: Double) -> Int {
        let currentTime = comment.time
        let endTime = currentTime + duration
        
        // 清理已结束的弹幕
        scrollingLanes = scrollingLanes.filter { $0.value > currentTime }
        
        // 寻找空闲轨道
        for lane in 0..<maxLanes {
            if scrollingLanes[lane] == nil || scrollingLanes[lane]! <= currentTime {
                scrollingLanes[lane] = endTime
                return lane
            }
        }
        
        // 如果没有空闲轨道，选择最早结束的轨道
        let earliestLane = scrollingLanes.min { $0.value < $1.value }?.key ?? 0
        scrollingLanes[earliestLane] = endTime
        return earliestLane
    }
    
    // 为顶部弹幕分配轨道
    func assignTopLane(for comment: DanmakuComment, duration: Double) -> Int {
        let currentTime = comment.time
        let endTime = currentTime + duration
        
        topLanes = topLanes.filter { $0.value > currentTime }
        
        for lane in 0..<maxLanes {
            if topLanes[lane] == nil || topLanes[lane]! <= currentTime {
                topLanes[lane] = endTime
                return lane
            }
        }
        
        let earliestLane = topLanes.min { $0.value < $1.value }?.key ?? 0
        topLanes[earliestLane] = endTime
        return earliestLane
    }
    
    // 为底部弹幕分配轨道
    func assignBottomLane(for comment: DanmakuComment, duration: Double) -> Int {
        let currentTime = comment.time
        let endTime = currentTime + duration
        
        bottomLanes = bottomLanes.filter { $0.value > currentTime }
        
        for lane in 0..<maxLanes {
            if bottomLanes[lane] == nil || bottomLanes[lane]! <= currentTime {
                bottomLanes[lane] = endTime
                return lane
            }
        }
        
        let earliestLane = bottomLanes.min { $0.value < $1.value }?.key ?? 0
        bottomLanes[earliestLane] = endTime
        return earliestLane
    }
    
    // 清理过期轨道
    func cleanupExpiredLanes(currentTime: Double) {
        scrollingLanes = scrollingLanes.filter { $0.value > currentTime }
        topLanes = topLanes.filter { $0.value > currentTime }
        bottomLanes = bottomLanes.filter { $0.value > currentTime }
    }
    
    // 获取轨道使用情况统计
    func getLaneUsageStats() -> (scrolling: Int, top: Int, bottom: Int) {
        return (
            scrolling: scrollingLanes.count,
            top: topLanes.count,
            bottom: bottomLanes.count
        )
    }
}

// 弹幕性能监控器
@available(tvOS 17.0, *)
class DanmakuPerformanceMonitor: ObservableObject {
    @Published var fps: Double = 0
    @Published var renderTime: Double = 0
    @Published var visibleCount: Int = 0
    @Published var cacheHitRate: Double = 0
    
    private var lastFrameTime: Date = Date()
    private var frameCount: Int = 0
    private var totalRenderTime: Double = 0
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    func startFrame() {
        lastFrameTime = Date()
    }
    
    func endFrame(renderTime: Double, visibleCount: Int, cacheHit: Bool) {
        let frameTime = Date().timeIntervalSince(lastFrameTime)
        frameCount += 1
        
        if cacheHit {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }
        
        totalRenderTime += renderTime
        self.visibleCount = visibleCount
        
        // 计算FPS（每10帧更新一次）
        if frameCount % 10 == 0 {
            fps = 10.0 / frameTime
            self.renderTime = totalRenderTime / 10.0
            cacheHitRate = Double(cacheHits) / Double(cacheHits + cacheMisses)
            
            // 重置计数器
            totalRenderTime = 0
        }
    }
}

// 弹幕渲染器 - 高效的自绘弹幕层
@available(tvOS 17.0, *)
struct DanmakuCanvas: View {
    let comments: [DanmakuComment]
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @Binding var settings: DanmakuSettings
    
    @StateObject private var laneManager: DanmakuLaneManager
    @StateObject private var cacheManager = DanmakuCacheManager()
    @StateObject private var performanceMonitor = DanmakuPerformanceMonitor()
    @State private var laneAssignments: [UUID: Int] = [:]
    @State private var showPerformanceStats = false
    // 移除在渲染阶段可能被修改的缓存，避免在View更新中修改状态
    private var textWidthCache: [UUID: CGFloat] { [:] }
    
    init(comments: [DanmakuComment], currentTime: Binding<Double>, isPlaying: Binding<Bool>, settings: Binding<DanmakuSettings>) {
        self.comments = comments
        self._currentTime = currentTime
        self._isPlaying = isPlaying
        self._settings = settings
        // 根据显示区域百分比和字体大小计算初始最大行数（静态计算）
        let displayHeight = UIScreen.main.bounds.height * CGFloat(settings.wrappedValue.displayAreaPercent)
        let lineHeight = CGFloat(settings.wrappedValue.fontSize * 1.2)
        let initialMaxLines = max(1, Int(displayHeight / lineHeight))
        self._laneManager = StateObject(wrappedValue: DanmakuLaneManager(maxLanes: initialMaxLines))
    }
    
    // 获取可见弹幕
    private var visibleComments: [DanmakuComment] {
        // 根据屏幕宽度与速度估算需要保留的最早时间，避免滚动弹幕尚未完全滚出就被过早移除
        let screenWidth = Double(UIScreen.main.bounds.width)
        let conservativeExtra: Double = 800 // 预留文本宽度与边距
        let pixelsPerSecond = max(60.0, 100.0 * Double(settings.speed))
        let estimatedScrollTime = (screenWidth + conservativeExtra) / pixelsPerSecond
        let fixedDuration = 4.0
        let lookBack = max(estimatedScrollTime, fixedDuration)
        let window: ClosedRange<Double> = (currentTime - lookBack)...(currentTime + 10)
        var filtered = comments.filter { window.contains($0.time) }
        
        // 根据设置过滤弹幕类型
        if !settings.showScrolling { filtered.removeAll { $0.isScrolling } }
        if !settings.showTop { filtered.removeAll { $0.isTop } }
        if !settings.showBottom { filtered.removeAll { $0.isBottom } }
        
        // 密度控制
        let maxVisible = max(1, Int(Double(settings.maxCount) * settings.density))
        if filtered.count > maxVisible {
            filtered = Array(filtered.prefix(maxVisible))
        }
        
        return filtered.sorted { $0.time < $1.time }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                // 分层渲染：背景层、弹幕层、UI层
                // 弹幕层
                ForEach(visibleComments) { comment in
                    danmakuView(for: comment, size: size)
                }
                
                // 性能统计UI（调试模式）
                if showPerformanceStats {
                    performanceStatsView
                        .position(x: 100, y: 50)
                }
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            .allowsHitTesting(false)
            .onAppear { 
                updateLaneManager()
                performanceMonitor.startFrame()
            }
            .onChange(of: settings.displayAreaPercent) { _, _ in 
                updateMaxLinesFromSettings()
            }
            .onChange(of: settings.fontSize) { _, _ in 
                updateMaxLinesFromSettings()
            }
            .onChange(of: comments.count) { _, _ in updateLaneManager() }
            .onChange(of: currentTime) { _, _ in
                // 每帧性能监控
                let startTime = Date()
                let visibleCount = visibleComments.count
                let cacheHit = false // 简化版本，实际可以检查缓存命中
                
                DispatchQueue.main.async {
                    performanceMonitor.endFrame(
                        renderTime: Date().timeIntervalSince(startTime),
                        visibleCount: visibleCount,
                        cacheHit: cacheHit
                    )
                }
            }
            .onLongPressGesture(minimumDuration: 1.0) {
                showPerformanceStats.toggle()
            }
        }
    }
    
    // 性能统计视图
    private var performanceStatsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(String(format: "%.1f", performanceMonitor.fps))")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Text("Render: \(String(format: "%.2fms", performanceMonitor.renderTime * 1000))")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Text("Visible: \(performanceMonitor.visibleCount)")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Text("Cache: \(String(format: "%.1f%%", performanceMonitor.cacheHitRate * 100))")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    // 更新轨道管理器
    private func updateLaneManager() {
        // 改为在评论/设置变化时清空并全量重算，避免旧分配残留导致重叠/错位
        laneAssignments.removeAll(keepingCapacity: true)
        laneManager.cleanupExpiredLanes(currentTime: currentTime)
        let sorted = comments.sorted { $0.time < $1.time }
        for comment in sorted {
            let lane: Int
            if comment.isScrolling {
                // 与实际滚动持续时间一致，减小碰撞概率
                let textW = textWidthCache[comment.id] ?? measureTextWidth(text: comment.content, fontSize: computeFontSize(lineHeight: computeLineHeight(size: CGSize(width: 1920, height: 1080))))
                let pixelsPerSecond: CGFloat = max(60, 100 * CGFloat(settings.speed))
                let estDuration = Double((textW + 1920) / pixelsPerSecond)
                lane = laneManager.assignScrollingLane(for: comment, duration: max(2.0, estDuration))
            } else if comment.isTop {
                lane = laneManager.assignTopLane(for: comment, duration: 4.0)
            } else {
                lane = laneManager.assignBottomLane(for: comment, duration: 4.0)
            }
            laneAssignments[comment.id] = lane
        }
    }
    
    // 渲染单个弹幕
    @ViewBuilder
    private func danmakuView(for comment: DanmakuComment, size: CGSize) -> some View {
        let lane = laneAssignments[comment.id] ?? 0
        let lineHeight = computeLineHeight(size: size)
        let fontSize = computeFontSize(lineHeight: lineHeight)
        
        createDanmakuView(comment: comment, lane: lane, size: size, fontSize: fontSize)
    }
    
    // 创建弹幕视图
    @ViewBuilder
    private func createDanmakuView(comment: DanmakuComment, lane: Int, size: CGSize, fontSize: CGFloat) -> some View {
        if comment.isScrolling {
            scrollingDanmakuView(comment: comment, lane: lane, size: size, fontSize: fontSize)
        } else if comment.isTop {
            fixedDanmakuView(comment: comment, lane: lane, size: size, fontSize: fontSize, position: .top)
        } else {
            fixedDanmakuView(comment: comment, lane: lane, size: size, fontSize: fontSize, position: .bottom)
        }
    }
    
    // 滚动弹幕视图
    @ViewBuilder
    private func scrollingDanmakuView(comment: DanmakuComment, lane: Int, size: CGSize, fontSize: CGFloat) -> some View {
        // 计算文本宽度以确保完全进入/离开屏幕（带缓存）
        let textW: CGFloat = {
            // 直接计算，不写入状态
            let w = measureTextWidth(text: comment.content, fontSize: fontSize)
            return w
        }()
        let padding: CGFloat = 30
        let startX: CGFloat = size.width + textW / 2 + padding
        let endX: CGFloat = -textW / 2 - padding
        let totalDistance: CGFloat = startX - endX
        // 像素速度（px/s），与设置速度成正比
        let pixelsPerSecond: CGFloat = max(60, 100 * CGFloat(settings.speed))
        let totalDuration = Double(totalDistance / pixelsPerSecond)
        let elapsed = max(0, currentTime - comment.time)
        let progress = max(0, min(1, elapsed / totalDuration))
        let x = startX + (endX - startX) * CGFloat(progress)
        let y = computeLineY(for: lane, size: size)
        
        Text(comment.content)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(Color(rgb: comment.colorValue))
            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
            .position(x: x, y: y)
            .opacity(settings.isEnabled ? settings.opacity : 0)
            .lineLimit(1)
            .fixedSize()
    }
    
    // 固定位置弹幕视图
    @ViewBuilder
    private func fixedDanmakuView(comment: DanmakuComment, lane: Int, size: CGSize, fontSize: CGFloat, position: DanmakuPosition) -> some View {
        let x = size.width / 2
        let y = computeLineY(for: lane, size: size)
        
        Text(comment.content)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(Color(rgb: comment.colorValue))
            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
            .position(x: x, y: y)
            .opacity(settings.isEnabled ? settings.opacity : 0)
    }
    
    // 计算行高
    private func computeLineHeight(size: CGSize) -> CGFloat {
        // 基于字体大小计算行高，添加一些间距
        let fontSize = max(16, settings.fontSize)
        return CGFloat(fontSize * 1.2) // 行高 = 字体大小 * 1.2
    }
    
    // 计算字体大小
    private func computeFontSize(lineHeight: CGFloat) -> CGFloat {
        // 直接使用设置中的字体大小
        return CGFloat(max(16, settings.fontSize))
    }
    
    // 根据显示区域百分比和字体大小计算最大行数
    private func computeMaxLines(screenHeight: CGFloat, displayPercent: Double, fontSize: Double) -> Int {
        let displayHeight = screenHeight * CGFloat(displayPercent)
        let lineHeight = CGFloat(fontSize * 1.2)
        return max(1, Int(displayHeight / lineHeight))
    }
    
    // 更新最大行数
    private func updateMaxLinesFromSettings() {
        let maxLines = computeMaxLines(
            screenHeight: UIScreen.main.bounds.height,
            displayPercent: settings.displayAreaPercent,
            fontSize: settings.fontSize
        )
        laneManager.maxLanes = max(1, maxLines)
        updateLaneManager()
    }
    
    // 计算行的 Y 坐标，从屏幕顶部开始
    private func computeLineY(for lane: Int, size: CGSize) -> CGFloat {
        let lineHeight = computeLineHeight(size: size)
        // 从屏幕顶部开始计算显示区域
        return lineHeight * CGFloat(lane) + lineHeight * 0.5
    }

    // 估算文本宽度（UIKit 字体测量）
    private func measureTextWidth(text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return ceil(size.width)
    }
}

// 弹幕位置枚举
enum DanmakuPosition {
    case top
    case bottom
}

private extension Color {
    init(rgb: Int) {
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}


