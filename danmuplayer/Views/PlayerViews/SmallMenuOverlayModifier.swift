//
// SmallMenuOverlay视图修饰符 - 简化使用
//

import SwiftUI

extension View {
    /// 精简包装：在顶层覆盖一个小菜单弹窗
    func smallMenuOverlay<Content: View>(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            // 背景禁用交互
            self
                .allowsHitTesting(!isPresented.wrappedValue)
                .disabled(isPresented.wrappedValue)

            if isPresented.wrappedValue {
                SmallMenuOverlay(isPresented: isPresented, title: title, content: content)
                    .zIndex(1000)
            }
        }
    }
}
