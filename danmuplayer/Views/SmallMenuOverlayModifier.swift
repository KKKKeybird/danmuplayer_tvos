//
// SmallMenuOverlay视图修饰符 - 简化使用
//

import SwiftUI

extension View {
    /// 添加小菜单覆盖层，用于替换tvOS不支持的popover
    /// - Parameters:
    ///   - isPresented: 控制显示/隐藏的绑定
    ///   - title: 菜单标题
    ///   - content: 菜单内容视图
    /// - Returns: 修饰后的视图
    func smallMenuOverlay<Content: View>(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay {
            SmallMenuOverlay(isPresented: isPresented, title: title, content: content)
        }
    }
}
