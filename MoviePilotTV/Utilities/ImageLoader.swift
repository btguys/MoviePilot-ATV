import SwiftUI
import Combine

// MARK: - 请求去重缓存
class ImageLoaderCache {
    static let shared = ImageLoaderCache()
    private var loadingTasks: [String: AnyCancellable] = [:]
    private let queue = DispatchQueue(label: "com.imageloader.cache")
    
    private init() {}
    
    func isLoading(url: URL) -> Bool {
        queue.sync { loadingTasks[url.absoluteString] != nil }
    }
    
    func setLoading(_ cancellable: AnyCancellable, for url: URL) {
        queue.async { [weak self] in
            self?.loadingTasks[url.absoluteString] = cancellable
        }
    }
    
    func removeLoading(for url: URL) {
        queue.async { [weak self] in
            self?.loadingTasks.removeValue(forKey: url.absoluteString)
        }
    }
}

// MARK: - 增强的图片加载器
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var loadingState: LoadingState = .empty
    
    enum LoadingState {
        case empty
        case loading(progress: Double = 0.5)
        case success(UIImage)
        case failure(Error)
    }
    
    private var cancellable: AnyCancellable?
    private let url: URL?
    private let urlSession: URLSession
    
    init(url: URL?) {
        self.url = url
        
        // 配置 URLSession 磁盘缓存
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,      // 50MB 内存缓存
            diskCapacity: 500 * 1024 * 1024,       // 500MB 磁盘缓存
            diskPath: nil
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15      // 15秒超时
        config.waitsForConnectivity = true         // 等待连接可用
        
        self.urlSession = URLSession(configuration: config)
    }
    
    func load() {
        guard let url = url else {
            loadingState = .failure(NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"]))
            return
        }
        
        // 1. 检查内存/磁盘缓存
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            self.loadingState = .success(cachedImage)
            print("✅ [ImageLoader] 缓存命中: \(url.absoluteString.prefix(50))...")
            return
        }
        
        // 2. 检查是否已在加载中（请求去重）
        if ImageLoaderCache.shared.isLoading(url: url) {
            self.isLoading = true
            self.loadingState = .loading()
            print("🔄 [ImageLoader] 请求去重：已在加载中 \(url.absoluteString.prefix(50))...")
            return
        }
        
        // 3. 开始加载
        self.isLoading = true
        self.loadingState = .loading()
        print("📥 [ImageLoader] 开始加载: \(url.absoluteString.prefix(50))...")
        
        let cancellable = urlSession.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .map { UIImage(data: $0) }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    ImageLoaderCache.shared.removeLoading(for: url)
                    self?.isLoading = false
                    
                    switch completion {
                    case .failure(let error):
                        self?.error = error
                        self?.loadingState = .failure(error)
                        print("❌ [ImageLoader] 加载失败: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] image in
                    if let image = image {
                        self?.image = image
                        self?.loadingState = .success(image)
                        ImageCache.shared.set(image, forKey: url.absoluteString)
                        print("✅ [ImageLoader] 加载成功: \(url.absoluteString.prefix(50))...")
                    } else {
                        let error = NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解码图片"])
                        self?.error = error
                        self?.loadingState = .failure(error)
                        print("❌ [ImageLoader] 解码失败")
                    }
                }
            )
        
        self.cancellable = cancellable
        ImageLoaderCache.shared.setLoading(cancellable, for: url)
    }
    
    func cancel() {
        guard let url = url else { return }
        cancellable?.cancel()
        ImageLoaderCache.shared.removeLoading(for: url)
        self.isLoading = false
    }
    
    deinit {
        cancel()
    }
}
