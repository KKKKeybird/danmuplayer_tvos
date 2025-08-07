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
                                if isVideoFile(item.name) {
                                    // 使用ViewModel的方法来播放视频
                                    viewModel.playVideo(item: item)
                                    selectedVideoItem = item
                                    showingVideoPlayer = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: getFileIcon(for: item.name))
                                        .foregroundStyle(getFileColor(for: item.name))
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
                                    if isVideoFile(item.name) {
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
            
            // 排序选择覆盖层
            if showingSortMenu {
                SortSelectionOverlay(
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
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoItem = selectedVideoItem {
                videoPlayerViewWrapper(
                    videoItem: videoItem,
                    subtitleFiles: viewModel.findSubtitleFiles(for: videoItem),
                    webDAVClient: viewModel.client
                )
            }
        }
        .onChange(of: viewModel.showingVideoPlayer) { oldValue, newValue in
            if newValue {
                selectedVideoItem = viewModel.selectedVideoItem
                showingVideoPlayer = true
            }
        }
        .onChange(of: viewModel.selectedVideoItem) { oldValue, newValue in
            if let newValue = newValue {
                selectedVideoItem = newValue
            }
        }
    }
    
    private func videoPlayerViewWrapper(videoItem: WebDAVItem, subtitleFiles: [WebDAVItem], webDAVClient: WebDAVClient) -> some View {
        WebDAVPlayerContainer(
            videoItem: videoItem,
            subtitleFiles: subtitleFiles,
            webDAVClient: webDAVClient
        )
    }
    
    private func playVideo(item: WebDAVItem) {
        selectedVideoItem = item
        showingVideoPlayer = true
    }
    
    private func isVideoFile(_ filename: String) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm"]
        let ext = (filename as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
    
    private func getFileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm":
            return "play.rectangle.fill"
        case "srt", "ass", "ssa", "vtt":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp":
            return "photo.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func getFileColor(for filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm":
            return .blue
        case "srt", "ass", "ssa", "vtt":
            return .green
        case "jpg", "jpeg", "png", "gif", "bmp":
            return .orange
        case "zip", "rar", "7z":
            return .purple
        default:
            return .gray
        }
    }
}
