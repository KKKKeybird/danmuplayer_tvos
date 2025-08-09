import SwiftUI

// 轻量自绘弹幕层（容器自适应尺寸；暂停时依赖 currentTime 停滞以暂停滚动）
@available(tvOS 17.0, *)
struct DanmakuCanvas: View {
    let comments: [DanmakuComment]
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @Binding var settings: DanmakuSettings

    // 稳定轨道分配：仅在“准备出现”时确定轨道，同类互斥，不同类互不干涉
    @State private var scrollingLaneById: [UUID: Int] = [:]
    @State private var topLaneById: [UUID: Int] = [:]
    @State private var bottomLaneById: [UUID: Int] = [:]

    // 预计算：按时间窗口过滤，简单实现
    private var visibleComments: [DanmakuComment] {
        let window: ClosedRange<Double> = (currentTime - 1)...(currentTime + 8)
        var filtered = comments.filter { window.contains($0.time) }
        if !settings.showScrolling { filtered.removeAll { $0.isScrolling } }
        if !settings.showTop { filtered.removeAll { $0.isTop } }
        if !settings.showBottom { filtered.removeAll { $0.isBottom } }
        // 密度限制（简单抽样）
        let maxVisible = max(1, Int(Double(settings.maxCount) * settings.density))
        if filtered.count > maxVisible { filtered = Array(filtered.prefix(maxVisible)) }
        return filtered
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                // 按时间排序确保先到先分配，避免同一时间批量落入同一轨道
                ForEach(visibleComments.sorted { $0.time < $1.time }) { c in
                    if c.isScrolling {
                        let lane = laneForScrolling(comment: c)
                        scrollingView(for: c, lane: lane, size: size)
                    } else if c.isTop {
                        let lane = laneForTop(comment: c)
                        let lineH = lineHeight(size: size)
                        fixedView(for: c, x: size.width/2, y: CGFloat(lane)*lineH + lineH/2)
                    } else {
                        let lane = laneForBottom(comment: c)
                        let lineH = lineHeight(size: size)
                        fixedView(for: c, x: size.width/2, y: size.height - CGFloat(lane)*lineH - lineH/2)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .onChange(of: comments) { _ in recomputeLanes() }
            .onChange(of: settings.maxLines) { _ in recomputeLanes() }
            .onAppear { recomputeLanes() }
        }
    }

    private func fixedView(for c: DanmakuComment, x: CGFloat, y: CGFloat) -> some View {
        Text(c.content)
            .font(.system(size: computedFontSize(for: UIScreen.main.bounds.size)))
            .foregroundColor(Color(rgb: c.colorValue))
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 0)
            .position(x: x, y: y)
            .opacity(settings.isEnabled ? settings.opacity : 0)
    }

    private func scrollingView(for c: DanmakuComment, lane: Int, size: CGSize) -> some View {
        // 简单线性滚动，从右到左，8秒。暂停时 currentTime 不前进，位置保持不变
        let duration: Double = 8.0 / settings.speed
        let progress = max(0, min(1, (currentTime - c.time) / duration))
        let x = size.width * (1 - progress) + 50
        let y = CGFloat( (lineHeight(size: size) * CGFloat(lane)) + lineHeight(size: size) * 0.6 )

        return Text(c.content)
            .font(.system(size: computedFontSize(for: size)))
            .foregroundColor(Color(rgb: c.colorValue))
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 0)
            .position(x: x, y: y)
            .opacity(settings.isEnabled ? settings.opacity : 0)
    }

    // 基于容器高度与最大行数，计算单行高度与字号
    private func lineHeight(size: CGSize) -> CGFloat {
        let lines = max(1, settings.maxLines)
        return max(16, size.height / CGFloat(lines + 2)) // 上下留白
    }

    private func computedFontSize(for size: CGSize) -> CGFloat {
        // 字号约为行高的 0.8
        return lineHeight(size: size) * 0.8
    }

    // MARK: - 轨道分配（仅首次出现时确定）
    private func laneForScrolling(comment c: DanmakuComment) -> Int { scrollingLaneById[c.id] ?? 0 }
    private func laneForTop(comment c: DanmakuComment) -> Int { topLaneById[c.id] ?? 0 }
    private func laneForBottom(comment c: DanmakuComment) -> Int { bottomLaneById[c.id] ?? 0 }

    // 预分配轨道：仅在 comments / maxLines / speed 变化时重算，避免在 body 中改 State
    private func recomputeLanes() {
        let lines = max(1, settings.maxLines)
        let fiveSec = 5.0
        // 滚动
        var queue: [(time: Double, lane: Int)] = []
        var used: [UUID: Int] = [:]
        for c in comments.filter({ $0.isScrolling }).sorted(by: { $0.time < $1.time }) {
            // 移除窗口外
            queue.removeAll { $0.time < c.time - fiveSec }
            let usedLanes = Set(queue.map { $0.lane })
            var chosen = 0
            for lane in 0..<lines { if !usedLanes.contains(lane) { chosen = lane; break } }
            used[c.id] = chosen
            queue.append((c.time, chosen))
        }
        scrollingLaneById = used
        // 顶部
        queue.removeAll(); used.removeAll()
        for c in comments.filter({ $0.isTop }).sorted(by: { $0.time < $1.time }) {
            queue.removeAll { $0.time < c.time - fiveSec }
            let usedLanes = Set(queue.map { $0.lane })
            var chosen = 0
            for lane in 0..<lines { if !usedLanes.contains(lane) { chosen = lane; break } }
            used[c.id] = chosen
            queue.append((c.time, chosen))
        }
        topLaneById = used
        // 底部
        queue.removeAll(); used.removeAll()
        for c in comments.filter({ $0.isBottom }).sorted(by: { $0.time < $1.time }) {
            queue.removeAll { $0.time < c.time - fiveSec }
            let usedLanes = Set(queue.map { $0.lane })
            var chosen = 0
            for lane in 0..<lines { if !usedLanes.contains(lane) { chosen = lane; break } }
            used[c.id] = chosen
            queue.append((c.time, chosen))
        }
        bottomLaneById = used
    }
}

private extension Color {
    init(rgb: Int) {
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}


