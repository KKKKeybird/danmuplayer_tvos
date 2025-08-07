/// 异步图片加载器，支持缓存
import SwiftUI
import UIKit

/// 异步图片加载器，集成Jellyfin缓存
@MainActor
class AsyncImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let url: URL
    private var task: URLSessionDataTask?
    
    init(url: URL) {
        self.url = url
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
        cancel()
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
                if let url = url, loader.url != url {
                    // 需要加载新的图片
                    let newLoader = AsyncImageLoader(url: url)
                    _loader.wrappedValue = newLoader
                    newLoader.load()
                } else if url != nil {
                    loader.load()
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
