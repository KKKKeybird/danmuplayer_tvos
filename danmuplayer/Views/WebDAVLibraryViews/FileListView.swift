/// 文件列表UI
import SwiftUI

/// 文件列表页面，展示WebDAV目录下的文件和文件夹
@available(tvOS 17.0, *)
struct FileListView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    @State private var sortOption: FileBrowserViewModel.SortOption = .name
    @State private var selectedVideoItem: WebDAVItem?
    @State private var showingVideoPlayer = false
    @State private var showingSortMenu = false
    @State private var isPreparingPlayback = false

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
                    List(viewModel.items) { item in
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
                    onSelectionChanged: { option in
                        viewModel.sortItems(by: option)
                    }
                )
            }
        }
        .navigationTitle(viewModel.currentDirectoryName)
        .onAppear {
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
    
    @State private var container: VLCPlayerContainer?
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
                container = VLCPlayerContainer.create(
                    videoURL: url,
                    originalFileName: videoItem.name,
                    subtitleURLs: subtitles,
                    onDismiss: onDismiss
                )
                isLoading = false
            }
        }
    }
}
