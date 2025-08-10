import SwiftUI
import UIKit

/// 异步图片加载器，集成 Jellyfin 缓存
@MainActor
final class AsyncImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private(set) var url: URL
    private var task: URLSessionDataTask?
    
    init(url: URL) {
        self.url = url
    }
    
    /// 更新图片地址并重新加载
    func updateURL(_ newURL: URL) {
        guard newURL != url else { return }
        cancel()
        image = nil
        error = nil
        url = newURL
        load()
    }
    
    func load() {
        guard !isLoading else { return }
        
        // 检查缓存
        if let cachedImage = JellyfinCache.shared.getCachedImage(for: url) {
            image = cachedImage
            return
        }
        
        isLoading = true
        error = nil
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let err {
                    self.error = err
                    return
                }
                
                guard let data,
                    let loadedImage = UIImage(data: data) else {
                    self.error = NSError(
                        domain: "AsyncImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"]
                    )
                    return
                }
                
                JellyfinCache.shared.cacheImage(loadedImage, for: self.url)
                self.image = loadedImage
            }
        }
        task?.resume()
    }

    
    /// 取消下载任务
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
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
        _loader = StateObject(wrappedValue: AsyncImageLoader(url: url ?? URL(string: "about:blank")!))
    }
    
    var body: some View {
        content(currentPhase)
            .onAppear {
                if let url {
                    if loader.url != url {
                        loader.updateURL(url)
                    } else {
                        loader.load()
                    }
                }
            }
            .onDisappear {
                Task {
                    await MainActor.run {
                        loader.cancel()
                    }
                }
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
        if case .success(let image) = self { image }
        else { nil }
    }
    
    var error: Error? {
        if case .failure(let err) = self { err }
        else { nil }
    }
}
