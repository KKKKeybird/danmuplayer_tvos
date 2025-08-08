/// Jellyfin媒体库排序选择组件
import SwiftUI

/// Jellyfin媒体库排序选择覆盖层
@available(tvOS 17.0, *)
struct JellyfinSortSelectionPopover: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: JellyfinMediaLibraryView.SortOption
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("排序方式")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Divider()
            VStack(spacing: 0) {
                ForEach(JellyfinMediaLibraryView.SortOption.allCases, id: \ .self) { option in
                    Button {
                        selectedOption = option
                        isPresented = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundStyle(selectedOption == option ? .accentColor : .primary)
                            Text(option.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedOption == option {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .foregroundStyle(.accentColor)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(selectedOption == option ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(PlainButtonStyle())
                    if option != JellyfinMediaLibraryView.SortOption.allCases.last {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
        }
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.98))
                .shadow(radius: 20)
        )
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

#Preview {
    @State var isPresented = true
    @State var selectedOption = JellyfinMediaLibraryView.SortOption.recentlyWatched
    
    return JellyfinSortSelectionPopover(
        isPresented: $isPresented,
        selectedOption: $selectedOption
    )
}
