import Foundation

/// DanDanPlay API配置管理
/// 
/// 安全提醒：
/// 1. AppSecret不应在客户端应用中硬编码
/// 2. 发布时应对代码进行混淆以防止AppSecret泄露
/// 3. 使用签名验证模式而非凭证模式
/// 
/// 申请地址：https://doc.dandanplay.com/open/#_3-%E7%94%B3%E8%AF%B7-appid-%E5%92%8C-appsecret
struct DanDanPlayConfig {
    /// API AppId - 需要从DanDanPlay开发者后台获取
    /// 申请邮箱：kaedei@dandanplay.net
    /// 邮件标题：弹弹play开放平台申请
    static let appId: String = "YOUR_APP_ID" // TODO: 替换为实际的AppId
    
    /// API AppSecret - 需要从DanDanPlay开发者后台获取
    /// 安全警告：请不要在生产环境中硬编码AppSecret
    /// 发布前请确保代码混淆以防止密钥泄露
    private static let appSecret: String = "YOUR_APP_SECRET" // TODO: 替换为实际的AppSecret
    
    /// 获取AppSecret（内部使用）
    /// 使用私有方法避免直接暴露AppSecret
    static var secretKey: String {
        return appSecret
    }
    
    /// 检查是否已配置API密钥
    static var isConfigured: Bool {
        return appId != "YOUR_APP_ID" && 
               appSecret != "YOUR_APP_SECRET" && 
               !appId.isEmpty && 
               !appSecret.isEmpty
    }
    
    /// 验证配置有效性
    /// - Returns: 配置状态和错误信息
    static func validateConfiguration() -> (isValid: Bool, errorMessage: String?) {
        if appId.isEmpty || appId == "YOUR_APP_ID" {
            return (false, "AppId未配置，请联系开发者获取")
        }
        
        if appSecret.isEmpty || appSecret == "YOUR_APP_SECRET" {
            return (false, "AppSecret未配置，请联系开发者")
        }
        
        return (true, nil)
    }
}
