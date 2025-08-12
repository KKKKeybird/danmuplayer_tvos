/// 视频播放设置视图 - 长按中心键进入
import SwiftUI
import VLCKitSPM
import VLCUI

/// 视频播放设置视图，整合所有播放器控制功能
@available(tvOS 17.0, *)
struct VideoPlayerSettingsView: View {
    @Binding var isPresented: Bool
    let vlcPlayer: VLCMediaPlayer?
    let externalSubtitles: [SubtitleFileInfo]
    let onDismiss: () -> Void
    let videoURL: URL
    let originalFileName: String
    let onSelectEpisode: (DanDanPlayEpisode) -> Void
    @Binding var isDanmakuEnabled: Bool
    @Binding var danmakuSettings: DanmakuSettings
    
    // 弹幕相关（使用全局绑定）
    
    // 音轨/字幕/匹配（合并内嵌显示）
    @State private var audioTracks: [AudioTrackSettingsView.AudioTrackInfo] = []
    @State private var currentAudioTrackIndex: Int = 0
    
    struct SubtitleTrackRowInfo {
        let index: Int
        let name: String
        let language: String?
        let isExternal: Bool
        let url: URL?
    }
    @State private var subtitleTracks: [SubtitleTrackRowInfo] = []
    @State private var currentSubtitleTrackIndex: Int = 0
    
    @State private var candidateEpisodes: [DanDanPlayEpisode] = []
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // 主内容（类 MediaLibraryConfig 的分节布局）
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("播放器设置")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button("关闭") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Divider()
                    .background(Color.gray)
                
                // 设置选项（合并四个弹出为内嵌分节）
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 音轨
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("音轨选择").font(.headline).foregroundColor(.white)
                                Spacer()
                                Button("刷新") { loadAudioTracks() }.font(.caption).foregroundColor(.white)
                            }
                            if audioTracks.isEmpty {
                                Text("没有可用的音轨").font(.caption).foregroundColor(.gray)
                            } else {
                                ForEach(Array(audioTracks.enumerated()), id: \.offset) { _, track in
                                    Button(action: { selectAudioTrack(index: track.index) }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(track.name).foregroundColor(.white)
                                                if let lang = track.language { Text(lang).font(.caption).foregroundColor(.gray) }
                                            }
                                            Spacer()
                                            if track.index == currentAudioTrackIndex {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                        .background(track.index == currentAudioTrackIndex ? Color.blue.opacity(0.08) : Color.clear)
                                        .cornerRadius(8)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        Divider().background(Color.gray.opacity(0.4))
                        
                        // 字幕
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("字幕设置").font(.headline).foregroundColor(.white)
                                Spacer()
                                Button("刷新") { loadSubtitleTracks() }.font(.caption).foregroundColor(.white)
                            }
                            if subtitleTracks.isEmpty && externalSubtitles.isEmpty {
                                Text("没有可用的字幕").font(.caption).foregroundColor(.gray)
                            } else {
                                if !subtitleTracks.isEmpty {
                                    Text("内嵌字幕").font(.subheadline).foregroundColor(.white).padding(.top, 4)
                                    ForEach(Array(subtitleTracks.filter { !$0.isExternal }.enumerated()), id: \.offset) { _, track in
                                        subtitleTrackRow(track: track)
                                    }
                                }
                                if !externalSubtitles.isEmpty {
                                    Text("外部字幕").font(.subheadline).foregroundColor(.white).padding(.top, 8)
                                    ForEach(Array(externalSubtitles.enumerated()), id: \.offset) { index, sub in
                                        externalSubtitleRow(subtitle: sub, index: index)
                                    }
                                }
                                Button("关闭字幕") { disableSubtitle() }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 8)
                            }
                        }
                        Divider().background(Color.gray.opacity(0.4))
                        
                        // 弹幕开关/设置
                        VStack(alignment: .leading, spacing: 12) {
                            Text("弹幕设置").font(.headline).foregroundColor(.white)
                            Toggle("启用弹幕", isOn: $isDanmakuEnabled).tint(.blue)
                            Group {
                                settingStepper(title: "透明度", displayText: "\(Int(danmakuSettings.opacity * 100))%", onMinus: {
                                    if danmakuSettings.opacity > 0.0 { danmakuSettings.opacity = max(0.0, danmakuSettings.opacity - 0.1) }
                                }, onPlus: {
                                    if danmakuSettings.opacity < 1.0 { danmakuSettings.opacity = min(1.0, danmakuSettings.opacity + 0.1) }
                                })
                                settingStepper(title: "字体大小", displayText: "\(Int(danmakuSettings.fontSize))", onMinus: {
                                    if danmakuSettings.fontSize > 24 { danmakuSettings.fontSize = max(24, danmakuSettings.fontSize - 1) }
                                }, onPlus: {
                                    if danmakuSettings.fontSize < 60 { danmakuSettings.fontSize = min(60, danmakuSettings.fontSize + 1) }
                                })
                                settingStepper(title: "弹幕显示区域", displayText: "\(Int(danmakuSettings.displayAreaPercent * 100))%", onMinus: {
                                    if danmakuSettings.displayAreaPercent > 0.1 { danmakuSettings.displayAreaPercent = max(0.1, danmakuSettings.displayAreaPercent - 0.1) }
                                }, onPlus: {
                                    if danmakuSettings.displayAreaPercent < 1.0 { danmakuSettings.displayAreaPercent = min(1.0, danmakuSettings.displayAreaPercent + 0.1) }
                                })
                                settingStepper(title: "滚动速度", displayText: String(format: "%.1fx", danmakuSettings.speed), onMinus: {
                                    if danmakuSettings.speed > 0.5 { danmakuSettings.speed = max(0.5, danmakuSettings.speed - 0.1) }
                                }, onPlus: {
                                    if danmakuSettings.speed < 3.0 { danmakuSettings.speed = min(3.0, danmakuSettings.speed + 0.1) }
                                })
                                settingStepper(title: "最大弹幕数", displayText: "\(danmakuSettings.maxCount)", onMinus: {
                                    if danmakuSettings.maxCount > 10 { danmakuSettings.maxCount = max(10, danmakuSettings.maxCount - 10) }
                                }, onPlus: {
                                    if danmakuSettings.maxCount < 200 { danmakuSettings.maxCount = min(200, danmakuSettings.maxCount + 10) }
                                })
                                settingStepper(title: "弹幕密度", displayText: "\(Int(danmakuSettings.density * 100))%", onMinus: {
                                    if danmakuSettings.density > 0.1 { danmakuSettings.density = max(0.1, danmakuSettings.density - 0.1) }
                                }, onPlus: {
                                    if danmakuSettings.density < 1.0 { danmakuSettings.density = min(1.0, danmakuSettings.density + 0.1) }
                                })
                            }
                            HStack {
                                Toggle("滚动弹幕", isOn: $danmakuSettings.showScrolling)
                                Toggle("顶部弹幕", isOn: $danmakuSettings.showTop)
                                Toggle("底部弹幕", isOn: $danmakuSettings.showBottom)
                            }
                            Button("重置为默认设置") { danmakuSettings = DanmakuSettings() }
                                .foregroundColor(.red)
                        }
                        Divider().background(Color.gray.opacity(0.4))
                        
                        // 弹幕匹配（简版）
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("弹幕匹配").font(.headline).foregroundColor(.white)
                                Spacer()
                                Button("刷新") { fetchCandidateEpisodes() }.font(.caption).foregroundColor(.white)
                            }
                            if candidateEpisodes.isEmpty {
                                Text("暂无候选剧集").font(.caption).foregroundColor(.gray)
                            } else {
                                ForEach(candidateEpisodes, id: \.id) { ep in
                                    Button(action: { onSelectEpisode(ep); isPresented = false }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ep.animeTitle).foregroundColor(.white)
                                            Text(ep.episodeTitle).font(.caption).foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                        .background(Color.blue.opacity(0.08))
                                        .cornerRadius(8)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // 调试
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("DanmakuDebugToggle"), object: nil)
                                isPresented = false
                            } label: {
                                HStack {
                                    Image(systemName: "ladybug").foregroundColor(.white)
                                    Text("打开调试信息").foregroundColor(.white)
                            }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                    .background(Color.gray)
                
                // 底部按钮
                HStack {
                    Spacer()
                    Button("返回播放器") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 900)
            .frame(maxHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .shadow(radius: 20)
            )
        }
        .onExitCommand {
            isPresented = false
        }
        .onAppear {
            loadAudioTracks()
            loadSubtitleTracks()
            fetchCandidateEpisodes()
        }
    }
}

// MARK: - 设置卡片组件

@available(tvOS 17.0, *)
struct SettingsCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 合并后的内联控件与方法
extension VideoPlayerSettingsView {
    private func settingStepper(title: String, displayText: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading) {
            Text(title).foregroundColor(.white)
            HStack {
                Button("-") { onMinus() }.buttonStyle(BorderedButtonStyle())
                Spacer()
                Text(displayText).font(.caption).foregroundColor(.gray)
                Spacer()
                Button("+") { onPlus() }.buttonStyle(BorderedButtonStyle())
            }
        }
    }
    
    private func loadAudioTracks() {
        guard let player = vlcPlayer else { audioTracks = []; return }
        var tracks: [AudioTrackSettingsView.AudioTrackInfo] = []
        if let trackIndexes = player.audioTrackIndexes as? [Int],
           let trackNames = player.audioTrackNames as? [String] {
            for (index, name) in zip(trackIndexes, trackNames) {
                let info = AudioTrackSettingsView.AudioTrackInfo(
                    index: index,
                    name: name.isEmpty ? "音轨 \(index)" : name,
                    language: extractLanguage(from: name)
                )
                tracks.append(info)
            }
        }
        audioTracks = tracks
        currentAudioTrackIndex = Int(player.currentAudioTrackIndex)
    }
    
    private func selectAudioTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        player.currentAudioTrackIndex = Int32(index)
        currentAudioTrackIndex = index
    }
    
    private func loadSubtitleTracks() {
        guard let player = vlcPlayer else { subtitleTracks = []; return }
        var tracks: [SubtitleTrackRowInfo] = []
        if let trackIndexes = player.videoSubTitlesIndexes as? [Int],
           let trackNames = player.videoSubTitlesNames as? [String] {
            for (index, name) in zip(trackIndexes, trackNames) {
                let info = SubtitleTrackRowInfo(
                    index: index,
                    name: name.isEmpty ? "字幕 \(index)" : name,
                    language: extractLanguage(from: name),
                    isExternal: false,
                    url: nil
                )
                tracks.append(info)
            }
        }
        subtitleTracks = tracks
        currentSubtitleTrackIndex = Int(player.currentVideoSubTitleIndex)
    }
    
    private func selectSubtitleTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        player.currentVideoSubTitleIndex = Int32(index)
        currentSubtitleTrackIndex = index
    }
    
    private func externalSubtitleRow(subtitle: SubtitleFileInfo, index: Int) -> some View {
        Button(action: { selectExternalSubtitle(subtitle: subtitle, index: index) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle.name).foregroundColor(.white)
                    if let language = subtitle.language {
                        Text(language).font(.caption).foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "externaldrive").foregroundColor(.gray).font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func subtitleTrackRow(track: SubtitleTrackRowInfo) -> some View {
        Button(action: { selectSubtitleTrack(index: track.index) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name).foregroundColor(.white)
                    if let language = track.language {
                        Text(language).font(.caption).foregroundColor(.gray)
                    }
                }
                Spacer()
                if track.index == currentSubtitleTrackIndex {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.title3)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(track.index == currentSubtitleTrackIndex ? Color.blue.opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func selectExternalSubtitle(subtitle: SubtitleFileInfo, index: Int) {
        guard let player = vlcPlayer else { return }
        if let url = subtitle.url {
            let result = player.addPlaybackSlave(url, type: .subtitle, enforce: false)
            if result == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.activateExternalSubtitle(subtitle: subtitle)
                }
            }
        }
    }
    
    private func activateExternalSubtitle(subtitle: SubtitleFileInfo) {
        guard let player = vlcPlayer else { return }
        if let trackIndexes = player.videoSubTitlesIndexes as? [Int],
           let trackNames = player.videoSubTitlesNames as? [String] {
            for (index, name) in zip(trackIndexes, trackNames) {
                if name.contains(subtitle.name) || (subtitle.url != nil && name.contains(subtitle.url!.lastPathComponent)) {
                    player.currentVideoSubTitleIndex = Int32(index)
                    currentSubtitleTrackIndex = index
                    break
                }
            }
        }
    }
    
    private func disableSubtitle() {
        guard let player = vlcPlayer else { return }
        player.currentVideoSubTitleIndex = -1
        currentSubtitleTrackIndex = -1
    }
    
    private func extractLanguage(from name: String) -> String? {
        let patterns: [String: String] = [
            "chinese": "中文", "english": "英文", "japanese": "日文", "korean": "韩文",
            "french": "法文", "german": "德文", "spanish": "西班牙文", "italian": "意大利文", "russian": "俄文"
        ]
        let lower = name.lowercased()
        for (k, v) in patterns { if lower.contains(k) { return v } }
        return nil
    }

    private func fetchCandidateEpisodes() {
        DanDanPlayAPI().fetchCandidateEpisodeList(for: videoURL, overrideFileName: originalFileName) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let episodes):
                    candidateEpisodes = episodes
                case .failure:
                    candidateEpisodes = []
                }
            }
        }
    }
}

// MARK: - 音轨设置视图

@available(tvOS 17.0, *)
struct AudioTrackSettingsView: View {
    @Binding var isPresented: Bool
    let vlcPlayer: VLCMediaPlayer?
    
    @State private var audioTracks: [AudioTrackInfo] = []
    @State private var currentTrackIndex: Int = 0
    
    struct AudioTrackInfo {
        let index: Int
        let name: String
        let language: String?
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("音轨选择")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if audioTracks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "speaker.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("没有可用的音轨")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .padding()
                        } else {
                            ForEach(Array(audioTracks.enumerated()), id: \.offset) { _, track in
                                audioTrackRow(track: track)
                            }
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("关闭") { isPresented = false }
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 500)
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.9))
            .onAppear {
                loadAudioTracks()
            }
            .onExitCommand {
                isPresented = false
            }
        }
    }
    
    private func loadAudioTracks() {
        guard let player = vlcPlayer else { return }
        
        var tracks: [AudioTrackInfo] = []
        
        if let trackIndexes = player.audioTrackIndexes as? [Int],
           let trackNames = player.audioTrackNames as? [String] {
            
            for (index, name) in zip(trackIndexes, trackNames) {
                let track = AudioTrackInfo(
                    index: index,
                    name: name.isEmpty ? "音轨 \(index)" : name,
                    language: extractLanguage(from: name)
                )
                tracks.append(track)
            }
        }
        
        audioTracks = tracks
        currentTrackIndex = Int(player.currentAudioTrackIndex)
    }
    
    private func selectAudioTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        
        player.currentAudioTrackIndex = Int32(index)
        currentTrackIndex = index
        isPresented = false
    }
    
    private func extractLanguage(from name: String) -> String? {
        let languagePatterns = [
            "chinese": "中文",
            "english": "英文",
            "japanese": "日文",
            "korean": "韩文"
        ]
        
        let lowercasedName = name.lowercased()
        for (pattern, language) in languagePatterns {
            if lowercasedName.contains(pattern) {
                return language
            }
        }
        
        return nil
    }
    
    private func audioTrackRow(track: AudioTrackInfo) -> some View {
        Button(action: {
            selectAudioTrack(index: track.index)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let language = track.language {
                        Text(language)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if track.index == currentTrackIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(track.index == currentTrackIndex ? Color.blue.opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 字幕设置视图

@available(tvOS 17.0, *)
struct SubtitleSettingsView: View {
    @Binding var isPresented: Bool
    let vlcPlayer: VLCMediaPlayer?
    let externalSubtitles: [SubtitleFileInfo]
    
    @State private var subtitleTracks: [SubtitleTrackInfo] = []
    @State private var currentTrackIndex: Int = 0
    
    struct SubtitleTrackInfo {
        let index: Int
        let name: String
        let language: String?
        let isExternal: Bool
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("字幕设置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if subtitleTracks.isEmpty && externalSubtitles.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "captions.bubble")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("没有可用的字幕")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .padding()
                        } else {
                            if !subtitleTracks.isEmpty {
                                Text("内嵌字幕")
                                    .font(.headline)
                                    .padding(.top, 8)
                                ForEach(Array(subtitleTracks.enumerated()), id: \.offset) { _, track in
                                    subtitleTrackRow(track: track)
                                }
                            }
                            
                            if !externalSubtitles.isEmpty {
                                Text("外部字幕")
                                    .font(.headline)
                                    .padding(.top, 12)
                                ForEach(Array(externalSubtitles.enumerated()), id: \.offset) { index, subtitle in
                                    externalSubtitleRow(subtitle: subtitle, index: index)
                                }
                            }
                            
                            // 禁用字幕选项
                            Button(action: {
                                disableSubtitle()
                            }) {
                                HStack {
                                    Text("关闭字幕")
                                        .foregroundColor(.white)
                                    Spacer()
                                    if currentTrackIndex == -1 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 12)
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("关闭") { isPresented = false }
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 500)
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.9))
            .onAppear {
                loadSubtitleTracks()
            }
            .onExitCommand {
                isPresented = false
            }
        }
    }
    
    private func loadSubtitleTracks() {
        guard let player = vlcPlayer else { return }
        
        var tracks: [SubtitleTrackInfo] = []
        
        if let trackIndexes = player.videoSubTitlesIndexes as? [Int],
           let trackNames = player.videoSubTitlesNames as? [String] {
            
            for (index, name) in zip(trackIndexes, trackNames) {
                let track = SubtitleTrackInfo(
                    index: index,
                    name: name.isEmpty ? "字幕 \(index)" : name,
                    language: extractLanguage(from: name),
                    isExternal: false
                )
                tracks.append(track)
            }
        }
        
        subtitleTracks = tracks
        currentTrackIndex = Int(player.currentVideoSubTitleIndex)
    }
    
    private func selectSubtitleTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        
        player.currentVideoSubTitleIndex = Int32(index)
        currentTrackIndex = index
        isPresented = false
    }
    
    private func selectExternalSubtitle(subtitle: SubtitleFileInfo, index: Int) {
        guard let player = vlcPlayer else { return }
        
        if let url = subtitle.url {
            let result = player.addPlaybackSlave(url, type: .subtitle, enforce: false)
            if result == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.activateExternalSubtitle(subtitle: subtitle)
                }
            }
        }
        
        isPresented = false
    }
    
    private func activateExternalSubtitle(subtitle: SubtitleFileInfo) {
        guard let player = vlcPlayer else { return }
        
        if let trackIndexes = player.videoSubTitlesIndexes as? [Int],
           let trackNames = player.videoSubTitlesNames as? [String] {
            
            for (index, name) in zip(trackIndexes, trackNames) {
                if name.contains(subtitle.name) || (subtitle.url != nil && name.contains(subtitle.url!.lastPathComponent)) {
                    player.currentVideoSubTitleIndex = Int32(index)
                    currentTrackIndex = index
                    break
                }
            }
        }
    }
    
    private func disableSubtitle() {
        guard let player = vlcPlayer else { return }
        
        player.currentVideoSubTitleIndex = -1
        currentTrackIndex = -1
        isPresented = false
    }
    
    private func extractLanguage(from name: String) -> String? {
        let languagePatterns = [
            "chinese": "中文",
            "english": "英文",
            "japanese": "日文",
            "korean": "韩文"
        ]
        
        let lowercasedName = name.lowercased()
        for (pattern, language) in languagePatterns {
            if lowercasedName.contains(pattern) {
                return language
            }
        }
        
        return nil
    }
    
    private func subtitleTrackRow(track: SubtitleTrackInfo) -> some View {
        Button(action: {
            selectSubtitleTrack(index: track.index)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let language = track.language {
                        Text(language)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if track.index == currentTrackIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(track.index == currentTrackIndex ? Color.blue.opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func externalSubtitleRow(subtitle: SubtitleFileInfo, index: Int) -> some View {
        Button(action: {
            selectExternalSubtitle(subtitle: subtitle, index: index)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let language = subtitle.language {
                        Text(language)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "externaldrive")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 弹幕匹配视图

@available(tvOS 17.0, *)
struct DanmakuMatchView: View {
    @Binding var isPresented: Bool
    let onEpisodeSelected: (DanDanPlayEpisode) -> Void
    
    @State private var candidateEpisodes: [DanDanPlayEpisode] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("弹幕匹配")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if candidateEpisodes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("没有找到匹配的弹幕")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .padding()
                        } else {
                            ForEach(candidateEpisodes, id: \.id) { episode in
                                episodeRow(episode: episode)
                            }
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("关闭") { isPresented = false }
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 500)
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.9))
            .onAppear {
                // 这里应该加载候选剧集
            }
            .onExitCommand {
                isPresented = false
            }
        }
    }
    
    private func episodeRow(episode: DanDanPlayEpisode) -> some View {
        Button(action: {
            onEpisodeSelected(episode)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(episode.animeTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(episode.episodeTitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 弹幕设置视图

@available(tvOS 17.0, *)
struct DanmakuSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var settings: DanmakuSettings
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("弹幕设置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 弹幕开关
                        VStack(alignment: .leading, spacing: 8) {
                            Text("显示弹幕")
                                .font(.headline)
                                .foregroundColor(.white)
                            Toggle("", isOn: $settings.isEnabled)
                        }
                        
                        // 弹幕透明度
                        VStack(alignment: .leading, spacing: 8) {
                            Text("透明度")
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack {
                                Button("-") {
                                    if settings.opacity > 0.0 {
                                        settings.opacity = max(0.0, settings.opacity - 0.1)
                                    }
                                }
                                .buttonStyle(BorderedButtonStyle())
                                Spacer()
                                Text("\(Int(settings.opacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Button("+") {
                                    if settings.opacity < 1.0 {
                                        settings.opacity = min(1.0, settings.opacity + 0.1)
                                    }
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                        
                        // 弹幕速度
                        VStack(alignment: .leading, spacing: 8) {
                            Text("滚动速度")
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack {
                                Button("-") {
                                    if settings.speed > 0.5 {
                                        settings.speed = max(0.5, settings.speed - 0.1)
                                    }
                                }
                                .buttonStyle(BorderedButtonStyle())
                                Spacer()
                                Text(String(format: "%.1fx", settings.speed))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Button("+") {
                                    if settings.speed < 3.0 {
                                        settings.speed = min(3.0, settings.speed + 0.1)
                                    }
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("关闭") { isPresented = false }
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .frame(width: 500)
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.9))
            .onExitCommand {
                isPresented = false
            }
        }
    }
}

// MARK: - 字幕文件信息结构

struct SubtitleFileInfo {
    let name: String
    let url: URL?
    let language: String?
}

// MARK: - 弹幕设置结构
// 注意：DanmakuSettings 定义在 VLCPlayerView.swift 中，这里不再重复定义
