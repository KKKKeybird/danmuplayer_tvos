/// 弹幕设置浮窗
import SwiftUI

/// 弹幕设置浮窗，可以设置弹幕字体大小，速度，同屏最多弹幕密度，弹幕透明度
@available(tvOS 17.0, *)
struct DanmaSettingOverlay: View {
    @Binding var settings: DanmakuSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本设置")) {
                    Toggle("启用弹幕", isOn: $settings.isEnabled)
                    
                    VStack(alignment: .leading) {
                        Text("透明度 \(Int(settings.opacity * 100))%")
                        HStack {
                            Button("-") {
                                if settings.opacity > 0.1 {
                                    settings.opacity = max(0.0, settings.opacity - 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            Spacer()
                            Text("\(Int(settings.opacity * 100))%")
                                .frame(minWidth: 50)
                            Spacer()
                            
                            Button("+") {
                                if settings.opacity < 1.0 {
                                    settings.opacity = min(1.0, settings.opacity + 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("字体大小: \(Int(settings.fontSize))")
                        HStack {
                            Button("-") {
                                if settings.fontSize > 10 {
                                    settings.fontSize = max(10, settings.fontSize - 1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            Spacer()
                            Text("\(Int(settings.fontSize))")
                                .frame(minWidth: 50)
                            Spacer()
                            
                            Button("+") {
                                if settings.fontSize < 30 {
                                    settings.fontSize = min(30, settings.fontSize + 1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("滚动速度: \(String(format: "%.1f", settings.speed))x")
                        HStack {
                            Button("-") {
                                if settings.speed > 0.5 {
                                    settings.speed = max(0.5, settings.speed - 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            Spacer()
                            Text("\(String(format: "%.1f", settings.speed))x")
                                .frame(minWidth: 50)
                            Spacer()
                            
                            Button("+") {
                                if settings.speed < 3.0 {
                                    settings.speed = min(3.0, settings.speed + 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("最大弹幕数: \(settings.maxCount)")
                        HStack {
                            Button("-") {
                                if settings.maxCount > 10 {
                                    settings.maxCount = max(10, settings.maxCount - 10)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            Spacer()
                            Text("\(settings.maxCount)")
                                .frame(minWidth: 50)
                            Spacer()
                            
                            Button("+") {
                                if settings.maxCount < 100 {
                                    settings.maxCount = min(100, settings.maxCount + 10)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("弹幕密度: \(String(format: "%.0f", settings.density * 100))%")
                        HStack {
                            Button("-") {
                                if settings.density > 0.1 {
                                    settings.density = max(0.1, settings.density - 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            Spacer()
                            Text("\(String(format: "%.0f", settings.density * 100))%")
                                .frame(minWidth: 50)
                            Spacer()
                            
                            Button("+") {
                                if settings.density < 1.0 {
                                    settings.density = min(1.0, settings.density + 0.1)
                                }
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }
                
                Section(header: Text("弹幕类型")) {
                    Toggle("滚动弹幕", isOn: $settings.showScrolling)
                    Toggle("顶部弹幕", isOn: $settings.showTop)
                    Toggle("底部弹幕", isOn: $settings.showBottom)
                }
                
                Section {
                    Button("重置为默认设置") {
                        settings = DanmakuSettings()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("弹幕设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
