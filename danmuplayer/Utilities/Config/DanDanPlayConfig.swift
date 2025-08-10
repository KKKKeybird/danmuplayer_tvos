import Foundation

/// DanDanPlay API配置管理
/// 
/// 配置说明：
/// 1. 敏感信息（AppId 和 AppSecret）存储在 DanDanPlaySecrets.swift 文件中
/// 2. 如果没有 DanDanPlaySecrets.swift，请复制 DanDanPlaySecrets.swift.template 并重命名
/// 3. DanDanPlaySecrets.swift 已被添加到 .gitignore，不会被提交到版本控制
/// 
/// 安全提醒：
/// 1. AppSecret不应在客户端应用中硬编码
/// 2. 发布时应对代码进行混淆以防止AppSecret泄露
/// 3. 使用签名验证模式而非凭证模式
/// 
/// 申请地址：https://doc.dandanplay.com/open/#_3-%E7%94%B3%E8%AF%B7-appid-%E5%92%8C-appsecret
struct DanDanPlayConfig {
    /// API AppId - 从 DanDanPlaySecrets 获取
    static let appId: String = DanDanPlaySecrets.appId
    
    /// 获取AppSecret（内部使用）
    /// 使用私有方法避免直接暴露AppSecret
    static var secretKey: String {
        return DanDanPlaySecrets.appSecret
    }
    
    /// 检查是否已配置API密钥
    static var isConfigured: Bool {
        return appId != "YOUR_APP_ID_HERE" && 
               DanDanPlaySecrets.appSecret != "YOUR_APP_SECRET_HERE" && 
               !appId.isEmpty && 
               !DanDanPlaySecrets.appSecret.isEmpty
    }
    
    /// 验证配置有效性
    /// - Returns: 配置状态和错误信息
    static func validateConfiguration() -> (isValid: Bool, errorMessage: String?) {
        if appId.isEmpty || appId == "YOUR_APP_ID_HERE" {
            return (false, "AppId未配置，请检查 DanDanPlaySecrets.swift 文件")
        }
        
        if DanDanPlaySecrets.appSecret.isEmpty || DanDanPlaySecrets.appSecret == "YOUR_APP_SECRET_HERE" {
            return (false, "AppSecret未配置，请检查 DanDanPlaySecrets.swift 文件")
        }
        
        return (true, nil)
    }
}
