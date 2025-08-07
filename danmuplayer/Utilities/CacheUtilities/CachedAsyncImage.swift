/// 异步图片加载器，支持缓存
import SwiftUI
import UIKit

/// 异步图片加载器，集成Jellyfin缓存
@MainActor
class AsyncImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private(set) var url: URL
    private var task: URLSessionDataTask?
    
    init(url: URL) {
        self.url = url
    }
    
    func updateURL(_ newURL: URL) {
        guard newURL != url else { return }
        
        // 取消当前任务
        cancel()
        
        // 清除当前状态
        image = nil
        error = nil
        
        // 更新 URL
        url = newURL
        
        // 开始加载新图片
        load()
    }
    
    func load() {
        // 先检查缓存
        if let cachedImage = JellyfinCache.shared.getCachedImage(for: url) {
            self.image = cachedImage
            return
        }
        
        // 如果没有缓存，从网络加载
        isLoading = true
        error = nil
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data, let loadedImage = UIImage(data: data) else {
                    self.error = NSError(domain: "AsyncImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"])
                    return
                }
                
                // 缓存图片
                JellyfinCache.shared.cacheImage(loadedImage, for: self.url)
                
                self.image = loadedImage
            }
        }
        
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
    
    deinit {
        Task { @MainActor in
            self.cancel()
        }
    }
}

/// 带缓存的异步图片视图
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    
    @StateObject private var loader: AsyncImageLoader
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
        self._loader = StateObject(wrappedValue: AsyncImageLoader(url: url ?? URL(string: "about:blank")!))
    }
    
    var body: some View {
        content(currentPhase)
            .onAppear {
                if let url = url {
                    if loader.url != url {
                        loader.updateURL(url)
                    } else {
                        loader.load()
                    }
                }
            }
            .onDisappear {
                loader.cancel()
            }
    }
    
    private var currentPhase: AsyncImagePhase {
        if let image = loader.image {
            return .success(Image(uiImage: image))
        } else if loader.isLoading {
            return .empty
        } else if let error = loader.error {
            return .failure(error)
        } else {
            return .empty
        }
    }
}

/// 异步图片加载阶段
enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
    
    var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }
    
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
