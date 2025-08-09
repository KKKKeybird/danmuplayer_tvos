/// 视频字幕选择浮窗
import SwiftUI
import VLCKitSPM
import VLCUI

/// 视频字幕选择浮窗，显示可用的字幕轨道供用户选择
@available(tvOS 17.0, *)
struct SubTrackPopover: View {
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
        let url: URL?
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("选择字幕")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if subtitleTracks.isEmpty && externalSubtitles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "captions.bubble")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                            Text("没有可用的字幕")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        if !subtitleTracks.isEmpty {
                            Text("内嵌字幕")
                                .font(.headline)
                                .padding(.top, 8)
                            ForEach(Array(subtitleTracks.enumerated()), id: \ .offset) { _, track in
                                subtitleTrackRow(track: track)
                            }
                        }
                        if !externalSubtitles.isEmpty {
                            Text("外部字幕")
                                .font(.headline)
                                .padding(.top, 12)
                            ForEach(Array(externalSubtitles.enumerated()), id: \ .offset) { index, subtitle in
                                externalSubtitleRow(subtitle: subtitle, index: index)
                            }
                        }
                        // 禁用字幕选项
                        Button(action: {
                            disableSubtitle()
                        }) {
                            HStack {
                                Text("关闭字幕")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentTrackIndex == -1 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
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
                Button("刷新") { loadSubtitleTracks() }
                    .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.98))
                .shadow(radius: 16)
        )
        .onAppear {
            loadSubtitleTracks()
        }
    }
    
    // MARK: - 子视图
    
    private func subtitleTrackRow(track: SubtitleTrackInfo) -> some View {
        Button(action: {
            selectSubtitleTrack(index: track.index)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let language = track.language {
                        Text(language)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if track.index == currentTrackIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func externalSubtitleRow(subtitle: SubtitleFileInfo, index: Int) -> some View {
        Button(action: {
            loadExternalSubtitle(subtitle: subtitle)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let language = subtitle.language {
                        Text(language)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("外部字幕文件")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                Image(systemName: "doc.text")
                    .foregroundStyle(.orange)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 私有方法
    
    private func loadSubtitleTracks() {
        guard let player = vlcPlayer else {
            subtitleTracks = []
            return
        }
        
        var tracks: [SubtitleTrackInfo] = []
        currentTrackIndex = Int(player.currentVideoSubTitleIndex)
        
        // 获取字幕轨道信息
        let subtitleIndexes = player.videoSubTitlesIndexes as? [NSNumber] ?? []
        let subtitleNames = player.videoSubTitlesNames as? [String] ?? []
        
        for (index, trackIndex) in subtitleIndexes.enumerated() {
            let trackName = index < subtitleNames.count ? subtitleNames[index] : "字幕 \(trackIndex.intValue)"
            let language = extractLanguageFromTrackName(trackName)
            
            tracks.append(SubtitleTrackInfo(
                index: trackIndex.intValue,
                name: trackName,
                language: language,
                isExternal: false,
                url: nil
            ))
        }
        
        self.subtitleTracks = tracks
    }
    
    private func selectSubtitleTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        
        player.currentVideoSubTitleIndex = Int32(index)
        currentTrackIndex = index
        
        // 延迟关闭浮窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
    
    private func loadExternalSubtitle(subtitle: SubtitleFileInfo) {
        guard let player = vlcPlayer,
              let subtitleURL = subtitle.url else { return }
        
        // 添加外部字幕文件到播放器
        if player.addPlaybackSlave(subtitleURL, type: .subtitle, enforce: true) == 0 {
            // 成功添加字幕
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 重新加载字幕轨道列表
                loadSubtitleTracks()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPresented = false
            }
        }
    }
    
    private func disableSubtitle() {
        guard let player = vlcPlayer else { return }
        
        player.currentVideoSubTitleIndex = -1
        currentTrackIndex = -1
        
        // 延迟关闭浮窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
    
    private func extractLanguageFromTrackName(_ trackName: String) -> String? {
        // 尝试从轨道名称中提取语言信息
        let lowercaseName = trackName.lowercased()
        
        if lowercaseName.contains("chinese") || lowercaseName.contains("中文") || lowercaseName.contains("zh") || lowercaseName.contains("chs") || lowercaseName.contains("cht") {
            return "中文"
        } else if lowercaseName.contains("english") || lowercaseName.contains("英文") || lowercaseName.contains("en") {
            return "English"
        } else if lowercaseName.contains("japanese") || lowercaseName.contains("日文") || lowercaseName.contains("ja") || lowercaseName.contains("jpn") {
            return "日本語"
        } else if lowercaseName.contains("korean") || lowercaseName.contains("韩文") || lowercaseName.contains("ko") || lowercaseName.contains("kor") {
            return "한국어"
        } else if lowercaseName.contains("spanish") || lowercaseName.contains("西班牙") || lowercaseName.contains("es") {
            return "Español"
        } else if lowercaseName.contains("french") || lowercaseName.contains("法语") || lowercaseName.contains("fr") {
            return "Français"
        }
        
        return nil
    }
}

// MARK: - 字幕文件信息结构
struct SubtitleFileInfo {
    let name: String
    let url: URL?
    let language: String?
}

// MARK: - 预览
