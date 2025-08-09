import SwiftUI

@available(tvOS 17.0, *)
struct JellyfinSortView: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: JellyfinMediaLibraryView.SortOption

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("排序方式")) {
                    ForEach(JellyfinMediaLibraryView.SortOption.allCases, id: \.self) { option in
                        Button {
                            selectedOption = option
                            isPresented = false
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
            }
            .listStyle(PlainListStyle())
            .navigationTitle("排序")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
    }
}
