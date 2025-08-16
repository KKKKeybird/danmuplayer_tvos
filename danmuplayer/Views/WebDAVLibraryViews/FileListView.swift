/// 文件列表UI
import SwiftUI

/// 文件列表页面，展示WebDAV目录下的文件和文件夹
@available(tvOS 17.0, *)
struct FileListView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    @StateObject private var sortStore = MediaLibrarySortStore.shared
    @State private var sortOption: FileBrowserViewModel.SortOption = .name
    @State private var isAscending: Bool = true
    @State private var selectedVideoItem: WebDAVItem?
    @State private var showingVideoPlayer = false
    @State private var showingSortMenu = false
    @State private var isPreparingPlayback = false
    @State private var refreshTrigger = UUID()
    
    // 计算属性：根据当前排序设置返回排序后的数据
    private var sortedItems: [WebDAVItem] {
        _ = refreshTrigger // 确保排序变化时刷新
        
        let directories = viewModel.items.filter { $0.isDirectory }
        let files = viewModel.items.filter { !$0.isDirectory }
        
        var sortedDirectories: [WebDAVItem]
        var sortedFiles: [WebDAVItem]
        
        switch sortOption {
        case .name:
            sortedDirectories = directories.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased()
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased()
                return isAscending ? result : !result
            }
        case .date:
            sortedDirectories = directories.sorted { 
                let result = ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast)
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast)
                return isAscending ? result : !result
            }
        case .size:
            sortedDirectories = directories.sorted { 
                let result = $0.name.lowercased() < $1.name.lowercased() // 目录按名称排序
                return isAscending ? result : !result
            }
            sortedFiles = files.sorted { 
                let result = ($0.size ?? 0) > ($1.size ?? 0)
                return isAscending ? result : !result
            }
        }
        
        return sortedDirectories + sortedFiles
    }

    var body: some View {
        ZStack {
            VStack {
                if viewModel.isLoading {
                    WebDAVLoadingView(message: "加载中...")
                } else if let errorMessage = viewModel.errorMessage {
                    WebDAVErrorView(
                        message: errorMessage,
                        retryAction: {
                            viewModel.loadDirectory()
                        }
                    )
                } else if viewModel.items.isEmpty {
                    WebDAVEmptyView {
                        viewModel.loadDirectory()
                    }
                } else {
                    List(sortedItems) { item in
                        if item.isDirectory {
                            NavigationLink(destination: FileListView(viewModel: viewModel.createChildViewModel(for: item))) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                        if let date = item.modifiedDate {
                                            Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        } else {
                            Button(action: {
                                if WebDAVVideoPlayerWrapper.isVideoFile(item.name) {
                                    // 统一成 Jellyfin 详情页的播放流程：先准备媒体，再显示播放器容器
                                    selectedVideoItem = item
                                    isPreparingPlayback = true
                                    viewModel.prepareMediaForPlayback(item: item) { url, _ in
                                        DispatchQueue.main.async {
                                            isPreparingPlayback = false
                                            if url.absoluteString.isEmpty { return }
                                            showingVideoPlayer = true
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: WebDAVVideoPlayerWrapper.getFileIcon(for: item.name))
                                        .foregroundStyle(WebDAVVideoPlayerWrapper.getFileColor(for: item.name))
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        HStack {
                                            if let size = item.size {
                                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let date = item.modifiedDate {
                                                Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if WebDAVVideoPlayerWrapper.isVideoFile(item.name) {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.title2)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSortMenu.toggle()
                    } label: {
                        HStack {
                            Image(systemName: sortOption.systemImage)
                            Text("排序")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSortMenu) {
                WebDAVSortView(
                    isPresented: $showingSortMenu,
                    selectedOption: $sortOption,
                    isAscending: $isAscending,
                    onSelectionChanged: { option, ascending in
                        sortOption = option
                        isAscending = ascending
                        // 保存到持久化存储
                        let optionString: String
                        switch option {
                        case .name: optionString = "name"
                        case .date: optionString = "date"
                        case .size: optionString = "size"
                        }
                        sortStore.setWebDAVSortConfig(for: viewModel.currentPathString, sortOption: optionString, isAscending: ascending)
                        // 强制刷新视图
                        refreshTrigger = UUID()
                    }
                )
            }
        }
        .navigationTitle(viewModel.currentDirectoryName)
        .onAppear {
            // 加载保存的排序配置
            let config = sortStore.getWebDAVSortConfig(for: viewModel.currentPathString)
            // 将字符串转换为SortOption
            switch config.sortOption {
            case "date": sortOption = .date
            case "size": sortOption = .size
            default: sortOption = .name
            }
            isAscending = config.isAscending
            // 强制刷新视图
            refreshTrigger = UUID()
            
            viewModel.loadDirectory()
        }
        .refreshable {
            viewModel.loadDirectory()
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let videoItem = selectedVideoItem {
                WebDAVVideoPlayerWrapper(
                    videoItem: videoItem,
                    viewModel: viewModel
                )
                .ignoresSafeArea()
            }
        }
        // 播放准备中的全屏遮罩
        .overlay {
            if isPreparingPlayback {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2)
                        Text("准备播放...").foregroundStyle(.white)
                    }
                }
                .transition(.opacity)
            }
        }
        // 移除对viewModel.showingVideoPlayer和selectedVideoItem的依赖
    }
}

@available(tvOS 17.0, *)
private struct WebDAVPlaybackBridge: View {
    let videoItem: WebDAVItem
    let viewModel: FileBrowserViewModel
    let onDismiss: () -> Void
    
    @State private var container: MPVPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView().scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage).foregroundColor(.white)
                    Button("返回") { onDismiss() }
                }
            } else if let container = container {
                container
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear { setup() }
    }
    
    private func setup() {
        isLoading = true
        errorMessage = nil
        viewModel.prepareMediaForPlayback(item: videoItem) { url, subtitles in
            DispatchQueue.main.async {
                if url.absoluteString.isEmpty {
                    errorMessage = "无法获取视频流"
                    isLoading = false
                    return
                }
                container = MPVPlayerContainer.create(
                    videoURL: url,
                    originalFileName: videoItem.name,
                    subtitleURLs: subtitles,
                    onDismiss: onDismiss
                )
                isLoading = false
            }
        }
    }
    
    // MARK: - 辅助方法
    

    private func optionToString(_ option: FileBrowserViewModel.SortOption) -> String {
        switch option {
        case .name: return "name"
        case .date: return "date"
        case .size: return "size"
        }
    }
    

}
