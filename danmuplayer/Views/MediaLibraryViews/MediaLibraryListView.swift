/// 媒体库选择页面
import SwiftUI
import Combine

/// 媒体库选择页面，展示多个WebDAV媒体库入口
@available(tvOS 17.0, *)
struct MediaLibraryListView: View {
    @ObservedObject var viewModel: MediaLibraryViewModel
    @State private var showingAddConfig = false
    @State private var editingConfig: MediaLibraryConfig?

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.mediaLibraries) { library in
                    NavigationLink(destination: destinationView(for: library)
                        .id(library.id.uuidString + "|" + library.config.serverURL + "|" + (library.config.username ?? ""))
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(library.name)
                                    .font(.headline)
                                HStack {
                                    Text(library.serverTypeDisplayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(library.config.serverType == .webdav ? Color.blue : Color.purple)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                Text(library.config.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if library.config.username != nil {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption2)
                                        Text("已配置认证")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            Spacer()
                            if let status = viewModel.connectionStatus[library.id] {
                                Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(status ? .green : .red)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button("测试连接") {
                            viewModel.testConnection(for: library.id)
                        }
                        Button("编辑") {
                            editingConfig = library.config
                        }
                        Button("删除", role: .destructive) {
                            viewModel.removeLibrary(withId: library.id)
                        }
                    }
                }
                .onDelete(perform: deleteLibraries)
            }
            .navigationTitle("媒体库")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加") {
                        showingAddConfig = true
                    }
                }
            }
            .sheet(isPresented: $showingAddConfig, onDismiss: {
                viewModel.refreshLibraries()
                viewModel.testAllConnections()
            }) {
                MediaLibraryConfigView(configManager: viewModel.configManager)
            }
            .sheet(item: $editingConfig, onDismiss: {
                viewModel.refreshLibraries()
                viewModel.testAllConnections()
            }) { config in
                MediaLibraryConfigView(configManager: viewModel.configManager, editingConfig: config)
            }
            .onAppear {
                viewModel.refreshLibraries()
                viewModel.testAllConnections()
            }
            .refreshable {
                viewModel.testAllConnections()
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for library: MediaLibrary) -> some View {
        switch library.config.serverType {
        case .webdav:
            if let webDAVClient = library.config.createWebDAVClient() {
                FileListView(viewModel: FileBrowserViewModel(client: webDAVClient))
            } else {
                Text("WebDAV客户端创建失败")
                    .foregroundColor(.red)
            }
        case .jellyfin:
            if library.config.createJellyfinClient() != nil {
                JellyfinMediaLibraryView(config: library.config)
            } else {
                Text("Jellyfin客户端创建失败")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func deleteLibraries(offsets: IndexSet) {
        for index in offsets {
            let library = viewModel.mediaLibraries[index]
            viewModel.removeLibrary(withId: library.id)
        }
    }
}
