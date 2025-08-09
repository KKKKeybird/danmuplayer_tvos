import SwiftUI

/// WebDAV 文件排序选择覆盖层（tvOS 样式）
@available(tvOS 15.0, *)
struct WebDAVSortSelectionPopover: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    let onSelectionChanged: (FileBrowserViewModel.SortOption) -> Void
    
    @FocusState private var focusedOption: FileBrowserViewModel.SortOption?
    @Namespace private var focusNamespace
    
    private let sortOptions: [FileBrowserViewModel.SortOption] = [.name, .date, .size]
    
    var body: some View {
        ZStack {
            backgroundOverlay
            mainContent
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented)
        .onAppear {
            focusedOption = selectedOption
        }
    }
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                isPresented = false
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            optionsList
        }
        .frame(width: 500)
        .background(popoverBackground)
        .focusScope(focusNamespace)
    }
    
    private var headerView: some View {
        HStack {
            Text("排序方式")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var popoverBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.black.opacity(0.95))
            .shadow(radius: 25)
    }
    
    private var optionsList: some View {
        VStack(spacing: 0) {
            ForEach(sortOptions, id: \.self) { option in
                optionRow(for: option)
                if option != sortOptions.last {
                    Divider()
                        .padding(.leading, 66)
                }
            }
        }
    }
    
    private func optionRow(for option: FileBrowserViewModel.SortOption) -> some View {
        Button {
            selectedOption = option
            onSelectionChanged(option)
            isPresented = false
        } label: {
            optionContent(for: option)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($focusedOption, equals: option)
    }
    
    private func optionContent(for option: FileBrowserViewModel.SortOption) -> some View {
        HStack(spacing: 16) {
            Image(systemName: option.systemImage)
                .font(.title3)
                .frame(width: 30)
            Text(option.displayName)
                .font(.title3)
            Spacer()
            if selectedOption == option {
                Image(systemName: "checkmark")
                    .font(.title3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(focusedOption == option ? Color.accentColor.opacity(0.3) : Color.clear)
    }
}
