/// WebDAV文件排序选择组件
import SwiftUI

/// WebDAV文件排序选择覆盖层
@available(tvOS 17.0, *)
struct WebDAVSortSelectionPopover: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    let onSelectionChanged: (FileBrowserViewModel.SortOption) -> Void
    
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
                ForEach([FileBrowserViewModel.SortOption.name, .date, .size], id: \ .self) { option in
                    Button {
                        selectedOption = option
                        onSelectionChanged(option)
                        isPresented = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundStyle(selectedOption == option ? .accentColor : .primary)
                            Text(option.displayName)
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
                    if option != .size {
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
    @State var selectedOption = FileBrowserViewModel.SortOption.name
    
    return WebDAVSortSelectionPopover(
        isPresented: $isPresented,
        selectedOption: $selectedOption,
        onSelectionChanged: { _ in }
    )
}
