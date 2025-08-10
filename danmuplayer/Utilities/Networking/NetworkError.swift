/// 网络错误定义
import Foundation

    // MARK: - 网络请求相关错误类型
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
    case timeout
    case serverUnavailable
    case networkUnavailable
    case unknown
    
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
            return "无法连接到服务器，请检查网络连接和服务器地址"
        case .authenticationFailed:
            return "API身份验证失败，请检查AppId和AppSecret配置"
        case .timeout:
            return "请求超时，请检查网络连接"
        case .serverUnavailable:
            return "服务器暂时不可用，请稍后重试"
        case .networkUnavailable:
            return "网络不可用，请检查网络连接"
        case .unknown:
            return "未知错误"
        }
    }
    
    /// 根据 NSURLError 创建对应的 NetworkError
    static func from(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .networkUnavailable
            case .cannotConnectToHost, .cannotFindHost:
                return .connectionFailed
            case .timedOut:
                return .timeout
            case .badServerResponse:
                return .invalidResponse
            case .userAuthenticationRequired:
                return .unauthorized
            case .badURL:
                return .invalidURL
            default:
                return .connectionFailed
            }
        }
        return .connectionFailed
    }
}