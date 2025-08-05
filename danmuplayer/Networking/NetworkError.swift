/// 网络错误定义
import Foundation

/// 网络请求相关错误类型
enum NetworkError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case parseError
    case connectionFailed
    case authenticationFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "未收到数据"
        case .invalidResponse:
            return "无效的响应"
        case .unauthorized:
            return "未授权，请检查用户名和密码"
        case .forbidden:
            return "访问被拒绝"
        case .notFound:
            return "资源未找到"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .parseError:
            return "数据解析失败"
        case .connectionFailed:
            return "连接失败"
        case .authenticationFailed:
            return "API身份验证失败，请检查AppId和AppSecret配置"
        }
    }
}