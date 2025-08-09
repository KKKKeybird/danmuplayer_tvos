/// 弹幕设置浮窗
import SwiftUI

/// 弹幕设置浮窗，可以设置弹幕字体大小，速度，同屏最多弹幕密度，弹幕透明度
@available(tvOS 17.0, *)
struct DanmaSettingPopover: View {
    @Binding var settings: DanmakuSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("弹幕设置")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle("启用弹幕", isOn: $settings.isEnabled)
                        .padding(.top, 10)
                    Group {
                        settingStepper(title: "透明度", value: Int(settings.opacity * 100), unit: "%", onMinus: {
                            if settings.opacity > 0.1 { settings.opacity = max(0.0, settings.opacity - 0.1) }
                        }, onPlus: {
                            if settings.opacity < 1.0 { settings.opacity = min(1.0, settings.opacity + 0.1) }
                        })
                        settingStepper(title: "字体大小", value: Int(settings.fontSize), unit: "", onMinus: {
                            if settings.fontSize > 10 { settings.fontSize = max(10, settings.fontSize - 1) }
                        }, onPlus: {
                            if settings.fontSize < 30 { settings.fontSize = min(30, settings.fontSize + 1) }
                        })
                        settingStepper(title: "滚动速度", value: Int(settings.speed * 10), unit: "x", onMinus: {
                            if settings.speed > 0.5 { settings.speed = max(0.5, settings.speed - 0.1) }
                        }, onPlus: {
                            if settings.speed < 3.0 { settings.speed = min(3.0, settings.speed + 0.1) }
                        }, displayValue: String(format: "%.1f", settings.speed))
                        settingStepper(title: "最大弹幕数", value: settings.maxCount, unit: "", onMinus: {
                            if settings.maxCount > 10 { settings.maxCount = max(10, settings.maxCount - 10) }
                        }, onPlus: {
                            if settings.maxCount < 100 { settings.maxCount = min(100, settings.maxCount + 10) }
                        })
                        settingStepper(title: "弹幕密度", value: Int(settings.density * 100), unit: "%", onMinus: {
                            if settings.density > 0.1 { settings.density = max(0.1, settings.density - 0.1) }
                        }, onPlus: {
                            if settings.density < 1.0 { settings.density = min(1.0, settings.density + 0.1) }
                        })
                    }
                    Group {
                        Toggle("滚动弹幕", isOn: $settings.showScrolling)
                        Toggle("顶部弹幕", isOn: $settings.showTop)
                        Toggle("底部弹幕", isOn: $settings.showBottom)
                    }
                    Button("重置为默认设置") {
                        settings = DanmakuSettings()
                    }
                    .foregroundStyle(.red)
                }
                .padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .padding(.horizontal, 20)
                Button("完成") { dismiss() }
                    .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.98))
                .shadow(radius: 16)
        )
    }

    // MARK: - 小组件
    private func settingStepper(title: String, value: Int, unit: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void, displayValue: String? = nil) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(displayValue ?? String(value))\(unit)")
            HStack {
                Button("-") { onMinus() }
                    .buttonStyle(BorderedButtonStyle())
                Spacer()
                Text("\(displayValue ?? String(value))\(unit)")
                    .frame(minWidth: 50)
                Spacer()
                Button("+") { onPlus() }
                    .buttonStyle(BorderedButtonStyle())
            }
        }
    }
}
