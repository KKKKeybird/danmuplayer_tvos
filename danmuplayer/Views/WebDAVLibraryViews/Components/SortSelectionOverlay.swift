/// WebDAV文件排序选择组件
import SwiftUI

/// WebDAV文件排序选择覆盖层
@available(tvOS 17.0, *)
struct SortSelectionOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: FileBrowserViewModel.SortOption
    let onSelectionChanged: (FileBrowserViewModel.SortOption) -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // 排序选项卡片
            VStack(spacing: 0) {
                // 标题
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
                .background(Color(.systemGray6))
                
                Divider()
                
                // 排序选项列表
                VStack(spacing: 0) {
                    ForEach([FileBrowserViewModel.SortOption.name, .date, .size], id: \.self) { option in
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
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .frame(width: 400)
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

#Preview {
    @State var isPresented = true
    @State var selectedOption = FileBrowserViewModel.SortOption.name
    
    return SortSelectionOverlay(
        isPresented: $isPresented,
        selectedOption: $selectedOption,
        onSelectionChanged: { _ in }
    )
}
