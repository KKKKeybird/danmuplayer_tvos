//
// 通用小菜单覆盖层 - 适配tvOS
//

import SwiftUI
import VLCKitSPM

/// 通用小菜单覆盖层，用于替换tvOS不支持的popover
struct SmallMenuOverlay<Content: View>: View {
    
    @Binding var isPresented: Bool
    let title: String
    let content: () -> Content
    
    @FocusState private var isFocused: Bool
    
    init(isPresented: Binding<Bool>, title: String, @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.content = content
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                // 菜单内容
                VStack(spacing: 20) {
                    // 标题
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    // 内容区域
                    content()
                        .padding(.horizontal)
                    
                    // 关闭按钮
                    Button("关闭") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
                .frame(maxWidth: 600)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding()
                .focusable()
                .focused($isFocused)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .onAppear {
                isFocused = true
            }
            .onExitCommand {
                isPresented = false
            }
        }
    }
}