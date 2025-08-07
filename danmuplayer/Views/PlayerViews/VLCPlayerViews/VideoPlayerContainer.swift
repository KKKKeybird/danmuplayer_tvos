/// 统一的视频播放器容器 - 重定向到新的统一实现
import SwiftUI

/// 视频播放器容器，现在使用统一的SwiftfinStyle UI
@available(tvOS 17.0, *)
struct VideoPlayerContainer: View {
    let videoItem: WebDAVItem
    let subtitleFiles: [WebDAVItem]
    let webDAVClient: WebDAVClient
    
    var body: some View {
        // 使用新的统一播放器容器
        UnifiedVideoPlayerContainer(
            videoItem: videoItem,
            subtitleFiles: subtitleFiles,
            webDAVClient: webDAVClient
        )
    }
}
