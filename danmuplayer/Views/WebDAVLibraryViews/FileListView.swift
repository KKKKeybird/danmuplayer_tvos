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
                                    // 根据API要求：寻找字幕文件，传入视频原始文件名，视频流媒体Url和字幕Url进入播放界面
                                    selectedVideoItem = item
                                    
                                    // 使用增强的ViewModel方法创建播放器容器
                                    viewModel.createVideoPlayerContainer(for: item) { container in
                                        if let container = container {
                                            // 设置播放器容器并显示
                                            self.showingVideoPlayer = true
                                        } else {
                                            // 处理创建失败的情况
                                            print("创建视频播放器容器失败")
                                        }
                                    }
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
                VLCPlayerContainerWrapper(
                    videoItem: videoItem,
                    viewModel: viewModel
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

// MARK: - VLC播放器容器包装器
@available(tvOS 17.0, *)
struct VLCPlayerContainerWrapper: View {
    let videoItem: WebDAVItem
    let viewModel: FileBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var playerContainer: VLCPlayerContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("准备播放器...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("播放错误")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Button("返回") {
                        dismiss()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let container = playerContainer {
                container
            }
        }
        .onAppear {
            setupPlayerContainer()
        }
    }
    
    private func setupPlayerContainer() {
        // 获取流媒体URL和字幕文件
        viewModel.getVideoStreamingURL(for: videoItem) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let streamingURL):
                    // 查找字幕文件
                    let subtitleFiles = viewModel.findSubtitleFiles(for: videoItem)
                    
                    // 创建VLC播放器容器
                    let container = VLCPlayerContainer.forWebDAV(
                        item: videoItem,
                        streamingURL: streamingURL,
                        subtitleFiles: subtitleFiles,
                        onDismiss: {
                            dismiss()
                        }
                    )
                    
                    self.playerContainer = container
                    self.isLoading = false
                    
                case .failure(let error):
                    self.errorMessage = "无法获取视频流: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }    private func playVideo(item: WebDAVItem) {
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
