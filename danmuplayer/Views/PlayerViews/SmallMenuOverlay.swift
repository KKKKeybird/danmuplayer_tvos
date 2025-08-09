//
// 通用小菜单覆盖层 - 适配tvOS
//

import SwiftUI

/// 通用小菜单覆盖层（精简版）
struct SmallMenuOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let content: () -> Content

    init(isPresented: Binding<Bool>, title: String, @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.content = content
    }

    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // 弹窗卡片
            VStack(spacing: 20) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                content()
                    .padding(.horizontal)

                Button("关闭") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 600)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding()
            .focusSection()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .onExitCommand { isPresented = false }
    }
}