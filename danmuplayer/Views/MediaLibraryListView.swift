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
                    NavigationLink(destination: FileListView(viewModel: FileBrowserViewModel(client: library.webDAVClient))) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(library.name)
                                    .font(.headline)
                                Text(library.config.baseURL)
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
            .sheet(isPresented: $showingAddConfig) {
                MediaLibraryConfigView(configManager: viewModel.configManager)
            }
            .sheet(item: $editingConfig) { config in
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
    
    private func deleteLibraries(offsets: IndexSet) {
        for index in offsets {
            let library = viewModel.mediaLibraries[index]
            viewModel.removeLibrary(withId: library.id)
        }
    }
}
