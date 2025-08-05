/// 播放器控制逻辑（弹幕加载、参数调整）
import Foundation
import Combine
import AVFoundation

/// 管理视频播放状态、弹幕加载和番剧识别
@MainActor
@available(tvOS 17.0, *)
class VideoPlayerViewModel: ObservableObject {
    @Published var series: DanDanPlaySeries?
    @Published var candidateSeriesList: [DanDanPlaySeries] = []
    @Published var danmakuComments: [DanmakuComment] = []
    @Published var subtitleURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSeriesSelection = false
    @Published var player: AVPlayer?

    // 弹幕设置
    @Published var danmakuSettings = DanmakuSettings()

    private let danDanAPI = DanDanPlayAPI()
    private var videoURL: URL?
    var subtitleFiles: [WebDAVItem] = []

    init(videoURL: URL? = nil, subtitleFiles: [WebDAVItem] = []) {
        self.videoURL = videoURL
        self.subtitleFiles = subtitleFiles

        if let url = videoURL {
            setupPlayer(with: url)
            identifySeries(videoURL: url)
        }
    }

    /// 设置播放器
    func setupPlayer(with url: URL) {
        self.videoURL = url
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // 自动加载字幕
        if let subtitleFile = findBestSubtitleFile() {
            loadSubtitle(subtitleFile: subtitleFile)
        }
    }

    /// 根据视频URL调用番剧识别
    func identifySeries(videoURL: URL) {
        isLoading = true
        errorMessage = nil

        danDanAPI.identifySeries(for: videoURL) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let series):
                    self.series = series
                    self.loadDanmaku()
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 获取候选番剧列表
    func fetchCandidateSeriesList() {
        guard let videoURL = videoURL else { return }

        isLoading = true
        danDanAPI.fetchCandidateSeriesList(for: videoURL) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success(let seriesList):
                    self.candidateSeriesList = seriesList
                    self.showingSeriesSelection = true
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 加载识别番剧的弹幕数据
    private func loadDanmaku() {
        guard let series = series else { return }

        danDanAPI.loadDanmaku(for: series) { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    do {
                        let response = try JSONDecoder().decode(DanmakuResponse.self, from: data)
                        self.danmakuComments = response.comments
                    } catch {
                        self.errorMessage = "弹幕数据解析失败: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 加载字幕文件
    func loadSubtitle(subtitleFile: WebDAVItem) {
        // 这里可以实现字幕文件的加载逻辑
        // 对于WebDAV，需要获取字幕文件的URL
    }

    /// 查找最佳匹配的字幕文件
    private func findBestSubtitleFile() -> WebDAVItem? {
        guard let videoURL = videoURL else { return nil }
        let videoBaseName = (videoURL.lastPathComponent as NSString).deletingPathExtension.lowercased()

        // 优先选择与视频文件名最匹配的字幕
        return subtitleFiles.first { subtitle in
            let subtitleBaseName = (subtitle.name as NSString).deletingPathExtension.lowercased()
            return subtitleBaseName.contains(videoBaseName) || videoBaseName.contains(subtitleBaseName)
        }
    }

    /// 用户选择番剧后更新识别结果
    func updateSeriesSelection(to series: DanDanPlaySeries) {
        isLoading = true
        danDanAPI.updateSeriesSelection(series: series) { result in
            Task { @MainActor in
                self.isLoading = false
                switch result {
                case .success:
                    self.series = series
                    self.loadDanmaku()
                    self.showingSeriesSelection = false
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

/// 弹幕显示设置
struct DanmakuSettings {
    var isEnabled: Bool = true
    var opacity: Double = 0.8
    var fontSize: Double = 16.0
    var speed: Double = 1.0
    var maxCount: Int = 50
    var showScrolling: Bool = true
    var showTop: Bool = true
    var showBottom: Bool = true
}
