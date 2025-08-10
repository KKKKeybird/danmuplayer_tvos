import SwiftUI

/// WebDAV 文件排序选择页（全屏View）
@available(tvOS 15.0, *)
struct WebDAVSortView: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    @Binding var isAscending: Bool
    let onSelectionChanged: (FileBrowserViewModel.SortOption, Bool) -> Void
    
    private let sortOptions: [FileBrowserViewModel.SortOption] = [.name, .date, .size]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("排序方式")) {
                    ForEach(sortOptions, id: \.self) { option in
                        Button {
                            selectedOption = option
                            // 不要立即关闭，让用户选择完顺序后再应用
                        } label: {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.displayName)
                                Spacer()
                                if selectedOption == option { Image(systemName: "checkmark") }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section(header: Text("顺序")) {
                    Button {
                        isAscending = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up")
                            Text("升序")
                            Spacer()
                            if isAscending { Image(systemName: "checkmark") }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        isAscending = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down")
                            Text("降序")
                            Spacer()
                            if !isAscending { Image(systemName: "checkmark") }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("排序")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onSelectionChanged(selectedOption, isAscending)
                        isPresented = false
                    }
                }
            }
        }
    }
    
}
