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
        // 仅渲染弹窗内容，由外层 SmallMenuOverlay 负责背景与标题
        VStack(spacing: 0) {
            optionsList
        }
        .frame(width: 500)
        .background(popoverBackground)
        .focusScope(focusNamespace)
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        .onAppear { focusedOption = selectedOption }
    }
    
    // 头部已交由 SmallMenuOverlay 提供标题与关闭按钮
    
    private var popoverBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.9))
            .shadow(radius: 20)
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
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(focusedOption == option ? Color.accentColor.opacity(0.25) : Color.clear)
        }
    }
}
