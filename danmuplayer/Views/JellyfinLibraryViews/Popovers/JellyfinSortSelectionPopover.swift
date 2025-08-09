import SwiftUI

@available(tvOS 17.0, *)
struct JellyfinSortSelectionPopoverTV: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: JellyfinMediaLibraryView.SortOption
    @FocusState private var focusedOption: JellyfinMediaLibraryView.SortOption?
    @Namespace private var focusNamespace

    var body: some View {
        // 仅渲染列表内容，背景与标题由 SmallMenuOverlay 提供
        VStack(spacing: 0) {
            optionsList
        }
        .frame(width: 660)
        .background(popoverBackground)
        .focusScope(focusNamespace)
        .animation(.easeOut(duration: 0.25), value: isPresented)
        .onAppear { focusedOption = selectedOption }
    }
    
    // 头部由 SmallMenuOverlay 提供
    
    private var optionsList: some View {
        VStack(spacing: 8) {
            ForEach(JellyfinMediaLibraryView.SortOption.allCases, id: \.self) { option in
                optionButton(for: option)
            }
        }
        .padding()
    }
    
    private func optionButton(for option: JellyfinMediaLibraryView.SortOption) -> some View {
        Button {
            selectedOption = option
            isPresented = false
        } label: {
            HStack {
                Text(option.rawValue)
                    .font(.title2)
                    .opacity(selectedOption == option ? 1 : 0.8)
                Spacer()
                if selectedOption == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(focusedOption == option ? Color.accentColor.opacity(0.25) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .focused($focusedOption, equals: option)
    }
    
    private var popoverBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.9))
            .shadow(radius: 20)
    }
}
