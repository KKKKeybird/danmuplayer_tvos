/// 音轨选择浮窗
import SwiftUI
import VLCKitSPM
import VLCUI

/// 音轨选择浮窗，显示可用的音频轨道供用户选择
@available(tvOS 17.0, *)
struct SoundTrackOverlay: View {
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
            List {
                if audioTracks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "speaker.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("没有可用的音轨")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(audioTracks.enumerated()), id: \.offset) { index, track in
                        Button(action: {
                            selectAudioTrack(index: track.index)
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
                }
            }
            .navigationTitle("选择音轨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("刷新") {
                        loadAudioTracks()
                    }
                }
            }
        }
        .onAppear {
            loadAudioTracks()
        }
    }
    
    // MARK: - 私有方法
    
    private func loadAudioTracks() {
        guard let player = vlcPlayer else {
            audioTracks = []
            return
        }
        
        var tracks: [AudioTrackInfo] = []
        currentTrackIndex = Int(player.currentAudioTrackIndex)
        
        // 获取音轨数量
        let audioTrackIndexes = player.audioTrackIndexes as? [NSNumber] ?? []
        let audioTrackNames = player.audioTrackNames as? [String] ?? []
        
        for (index, trackIndex) in audioTrackIndexes.enumerated() {
            let trackName = index < audioTrackNames.count ? audioTrackNames[index] : "音轨 \(trackIndex.intValue)"
            let language = extractLanguageFromTrackName(trackName)
            
            tracks.append(AudioTrackInfo(
                index: trackIndex.intValue,
                name: trackName,
                language: language
            ))
        }
        
        self.audioTracks = tracks
    }
    
    private func selectAudioTrack(index: Int) {
        guard let player = vlcPlayer else { return }
        
        player.currentAudioTrackIndex = Int32(index)
        currentTrackIndex = index
        
        // 延迟关闭浮窗，给用户看到选择效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
    
    private func extractLanguageFromTrackName(_ trackName: String) -> String? {
        // 尝试从轨道名称中提取语言信息
        let lowercaseName = trackName.lowercased()
        
        if lowercaseName.contains("chinese") || lowercaseName.contains("中文") || lowercaseName.contains("zh") {
            return "中文"
        } else if lowercaseName.contains("english") || lowercaseName.contains("英文") || lowercaseName.contains("en") {
            return "English"
        } else if lowercaseName.contains("japanese") || lowercaseName.contains("日文") || lowercaseName.contains("ja") {
            return "日本語"
        } else if lowercaseName.contains("korean") || lowercaseName.contains("韩文") || lowercaseName.contains("ko") {
            return "한국어"
        }
        
        return nil
    }
}

// MARK: - 预览

#if DEBUG
@available(tvOS 17.0, *)
struct SoundTrackOverlay_Previews: PreviewProvider {
    static var previews: some View {
        SoundTrackOverlay(
            isPresented: .constant(true),
            vlcPlayer: nil
        )
    }
}
#endif
