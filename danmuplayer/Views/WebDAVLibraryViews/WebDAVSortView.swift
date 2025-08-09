import SwiftUI

/// WebDAV 文件排序选择页（全屏View）
@available(tvOS 15.0, *)
struct WebDAVSortView: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    let onSelectionChanged: (FileBrowserViewModel.SortOption) -> Void
    
    private let sortOptions: [FileBrowserViewModel.SortOption] = [.name, .date, .size]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("排序方式")) {
                    ForEach(sortOptions, id: \.self) { option in
                        HStack {
                            Image(systemName: option.systemImage)
                            Text(option.displayName)
                            Spacer()
                            if selectedOption == option { Image(systemName: "checkmark") }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOption = option
                            onSelectionChanged(option)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("排序")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
    }
    
}
