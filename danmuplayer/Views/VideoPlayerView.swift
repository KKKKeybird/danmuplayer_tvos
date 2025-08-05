/// 播放UI，带弹幕及字幕控制
import SwiftUI
import AVKit

/// 视频播放页面，支持弹幕和字幕加载
@available(tvOS 17.0, *)
struct VideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var showingDanmakuSettings = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 视频播放区域
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(height: geometry.size.height * 0.75) // tvOS上使用更大的播放区域
                        .overlay(
                            // 弹幕覆盖层
                            DanmakuOverlayView(
                                comments: viewModel.danmakuComments,
                                settings: viewModel.danmakuSettings,
                                currentTime: viewModel.player?.currentItem?.currentTime() ?? CMTime.zero,
                                frameSize: CGSize(width: geometry.size.width, height: geometry.size.height * 0.75)
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.9))
                        .frame(height: geometry.size.height * 0.75)
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(2)
                                Text("加载中...")
                                    .foregroundStyle(.white)
                                    .padding(.top)
                            }
                        )
                }
                
                // 控制区域 - 针对tvOS优化
                VStack(spacing: 20) {
                    // 番剧信息
                    if let series = viewModel.series {
                        VStack(alignment: .center, spacing: 8) {
                            Text("当前识别:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(series.displayTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)
                    } else if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("识别番剧中...")
                                .font(.title3)
                        }
                    } else {
                        Text("未识别到番剧")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 控制按钮 - tvOS风格
                    HStack(spacing: 60) {
                        Button(action: {
                            viewModel.fetchCandidateSeriesList()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "list.bullet")
                                    .font(.title)
                                Text("选择番剧")
                                    .font(.caption)
                            }
                            .frame(width: 120, height: 80)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isLoading)
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            showingDanmakuSettings = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title)
                                Text("弹幕设置")
                                    .font(.caption)
                            }
                            .frame(width: 120, height: 80)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if !viewModel.subtitleFiles.isEmpty {
                            Menu {
                                ForEach(viewModel.subtitleFiles, id: \.id) { subtitle in
                                    Button(subtitle.name) {
                                        viewModel.loadSubtitle(subtitleFile: subtitle)
                                    }
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "captions.bubble")
                                        .font(.title)
                                    Text("字幕")
                                        .font(.caption)
                                }
                                .frame(width: 120, height: 80)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(height: geometry.size.height * 0.25)
                .background(Color.primary.opacity(0.1))
            }
        }
        .navigationTitle("视频播放")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("完成") {
                    // 返回文件列表
                }
            }
        }
        .sheet(isPresented: $showingDanmakuSettings) {
            DanmakuSettingsView(settings: $viewModel.danmakuSettings)
        }
        .sheet(isPresented: $viewModel.showingSeriesSelection) {
            SeriesSelectionView(
                seriesList: viewModel.candidateSeriesList,
                onSelection: { series in
                    viewModel.updateSeriesSelection(to: series)
                }
            )
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            if let player = viewModel.player {
                player.play()
            }
        }
        .onDisappear {
            viewModel.player?.pause()
        }
    }
}

/// 弹幕覆盖层视图
@available(tvOS 17.0, *)
struct DanmakuOverlayView: View {
    let comments: [DanmakuComment]
    let settings: DanmakuSettings
    let currentTime: CMTime
    let frameSize: CGSize
    
    private var currentTimeSeconds: Double {
        return currentTime.seconds.isNaN ? 0 : currentTime.seconds
    }
    
    private var visibleComments: [DanmakuComment] {
        guard settings.isEnabled else { return [] }
        
        // 获取当前时间范围内的弹幕（前3秒，tvOS上时间窗口稍小）
        let timeRange = 3.0
        return comments.filter { comment in
            let commentTime = comment.time
            return commentTime >= currentTimeSeconds - timeRange && 
                   commentTime <= currentTimeSeconds + timeRange &&
                   shouldShowComment(comment)
        }.prefix(settings.maxCount).map { $0 }
    }
    
    var body: some View {
        ZStack {
            // 滚动弹幕
            if settings.showScrolling {
                ForEach(visibleComments.filter { $0.isScrolling }) { comment in
                    DanmakuItemView(comment: comment, settings: settings)
                        .position(
                            x: calculateScrollingX(for: comment),
                            y: calculateScrollingY(for: comment)
                        )
                }
            }
            
            // 顶部弹幕
            if settings.showTop {
                VStack {
                    ForEach(visibleComments.filter { $0.isTop }.prefix(2)) { comment in
                        DanmakuItemView(comment: comment, settings: settings)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                }
                .padding(.top, 40)
            }
            
            // 底部弹幕
            if settings.showBottom {
                VStack {
                    Spacer()
                    ForEach(visibleComments.filter { $0.isBottom }.prefix(2)) { comment in
                        DanmakuItemView(comment: comment, settings: settings)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // 状态指示器
            if settings.isEnabled && !comments.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Text("弹幕: \(comments.count)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.primary.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func shouldShowComment(_ comment: DanmakuComment) -> Bool {
        switch (comment.isScrolling, comment.isTop, comment.isBottom) {
        case (true, _, _): return settings.showScrolling
        case (_, true, _): return settings.showTop
        case (_, _, true): return settings.showBottom
        default: return settings.showScrolling
        }
    }
    
    private func calculateScrollingX(for comment: DanmakuComment) -> CGFloat {
        let screenWidth = frameSize.width
        let elapsed = currentTimeSeconds - comment.time
        let duration = 10.0 / settings.speed // tvOS上弹幕持续时间稍长
        let progress = elapsed / duration
        
        return screenWidth + 150 - CGFloat(progress) * (screenWidth + 300)
    }
    
    private func calculateScrollingY(for comment: DanmakuComment) -> CGFloat {
        let playAreaHeight = frameSize.height - 80 // 减去顶部和底部边距
        let trackHeight = CGFloat(settings.fontSize + 8) // tvOS上轨道间距更大
        let trackCount = Int(playAreaHeight / trackHeight)
        let track = abs(comment.content.hashValue) % trackCount
        
        return 40 + CGFloat(track) * trackHeight + trackHeight / 2
    }
}

/// 单个弹幕项视图
@available(tvOS 17.0, *)
struct DanmakuItemView: View {
    let comment: DanmakuComment
    let settings: DanmakuSettings
    
    var body: some View {
        Text(comment.content)
            .font(.system(size: settings.fontSize))
            .foregroundStyle(comment.color)
            .opacity(settings.opacity)
    }
}
