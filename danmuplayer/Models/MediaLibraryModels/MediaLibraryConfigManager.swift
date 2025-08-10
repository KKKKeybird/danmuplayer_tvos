/// 媒体库配置管理器
import Foundation

/// 负责媒体库配置的持久化存储和管理
@available(tvOS 17.0, *)
class MediaLibraryConfigManager: ObservableObject {
    @Published var configs: [MediaLibraryConfig] = []
    
    private let userDefaults = UserDefaults.standard
    private let configsKey = "MediaLibraryConfigs"
    
    init() {
        loadConfigs()
    }
    
    /// 从UserDefaults加载配置
    func loadConfigs() {
        guard let data = userDefaults.data(forKey: configsKey) else {
            // 如果没有保存的配置，使用默认配置
            setDefaultConfigs()
            return
        }
        
        do {
            let decodedConfigs = try JSONDecoder().decode([MediaLibraryConfig].self, from: data)
            configs = decodedConfigs
        } catch {
            print("Failed to decode media library configs: \(error)")
            setDefaultConfigs()
        }
    }
    
    /// 保存配置到UserDefaults
    func saveConfigs() {
        do {
            let data = try JSONEncoder().encode(configs)
            userDefaults.set(data, forKey: configsKey)
        } catch {
            print("Failed to encode media library configs: \(error)")
        }
    }
    
    /// 添加新的媒体库配置
    func addConfig(_ config: MediaLibraryConfig) {
        configs.append(config)
        saveConfigs()
    }
    
    /// 更新现有配置
    func updateConfig(_ config: MediaLibraryConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
        }
    }
    
    /// 删除配置
    func removeConfig(withId id: UUID) {
        configs.removeAll { $0.id == id }
        saveConfigs()
    }
    
    /// 设置默认配置（示例）
    private func setDefaultConfigs() {
        configs = []
        saveConfigs()
    }
    
    /// 验证配置的有效性
    func validateConfig(_ config: MediaLibraryConfig) -> Bool {
        // 检查URL格式
        guard URL(string: config.baseURL) != nil else {
            return false
        }
        
        // 检查名称不为空
        guard !config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return true
    }
}
