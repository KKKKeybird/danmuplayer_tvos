/// 文件列表UI
import SwiftUI

/// 文件列表页面，展示WebDAV目录下的文件和文件夹
@available(tvOS 17.0, *)
struct FileListView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    @State private var sortOption: FileBrowserViewModel.SortOption = .name
    @State private var selectedVideoItem: WebDAVItem?
    @State private var showingVideoPlayer = false

    var body: some View {
        VStack {
            Picker("排序", selection: $sortOption) {
                Text("名称").tag(FileBrowserViewModel.SortOption.name)
                Text("日期").tag(FileBrowserViewModel.SortOption.date)
                Text("大小").tag(FileBrowserViewModel.SortOption.size)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: sortOption) { oldValue, newValue in
                viewModel.sortItems(by: newValue)
            }

            if viewModel.isLoading {
                ProgressView("加载中..")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.loadDirectory()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text("目录为空")
                        .font(.headline)
                    Text("此目录中没有文件或文件夹")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("刷新") {
                        viewModel.loadDirectory()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.items) { item in
                    if item.isDirectory {
                        NavigationLink(destination: FileListView(viewModel: viewModel.createChildViewModel(for: item.path))) {
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
    }
    
    private func videoPlayerViewWrapper(videoItem: WebDAVItem, subtitleFiles: [WebDAVItem], webDAVClient: WebDAVClient) -> some View {
        VideoPlayerContainer(
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
