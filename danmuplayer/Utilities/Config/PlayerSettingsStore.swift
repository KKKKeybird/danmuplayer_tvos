import Foundation

@available(tvOS 17.0, *)
class PlayerSettingsStore: ObservableObject {
    static let shared = PlayerSettingsStore()

    @Published var isDanmakuEnabled: Bool {
        didSet { persist() }
    }

    @Published var danmakuSettings: DanmakuSettings {
        didSet { persist() }
    }

    private init() {
        // 默认值
        var enabled = true
        var settings = DanmakuSettings()

        // 读取持久化
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.isDanmakuEnabled) != nil {
            enabled = defaults.bool(forKey: Keys.isDanmakuEnabled)
        }
        if let data = defaults.data(forKey: Keys.danmakuSettings),
           let decoded = try? JSONDecoder().decode(DanmakuSettings.self, from: data) {
            settings = decoded
        }

        self.isDanmakuEnabled = enabled
        self.danmakuSettings = settings
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(isDanmakuEnabled, forKey: Keys.isDanmakuEnabled)
        if let data = try? JSONEncoder().encode(danmakuSettings) {
            defaults.set(data, forKey: Keys.danmakuSettings)
        }
    }

    private enum Keys {
        static let isDanmakuEnabled = "player.isDanmakuEnabled"
        static let danmakuSettings = "player.danmakuSettings"
    }
}


