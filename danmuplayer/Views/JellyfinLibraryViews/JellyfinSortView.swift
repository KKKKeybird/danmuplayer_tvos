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
                        HStack {
                            Image(systemName: option.systemImage)
                            Text(option.rawValue)
                            Spacer()
                            if selectedOption == option { Image(systemName: "checkmark") }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOption = option
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
