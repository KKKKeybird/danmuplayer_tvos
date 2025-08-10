import SwiftUI

@available(tvOS 17.0, *)
struct JellyfinSortView: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: JellyfinMediaLibraryView.SortOption
    @Binding var isAscending: Bool
    let onApply: (() -> Void)?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("排序方式")) {
                    ForEach(JellyfinMediaLibraryView.SortOption.allCases, id: \.self) { option in
                        Button {
                            selectedOption = option
                            // 不要立即关闭，让用户选择完顺序后再应用
                        } label: {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.rawValue)
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
                        onApply?()
                        isPresented = false
                    }
                }
            }
        }
    }
}
