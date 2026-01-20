import UIKit

class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCachePath: String
    private let fileManager = FileManager.default
    
    private init() {
        // 内存缓存配置（500MB）
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 1024 * 1024 * 500
        
        // 磁盘缓存路径配置
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCachePath = cacheDir.appendingPathComponent("ImageCache").path
        
        // 创建磁盘缓存目录
        if !fileManager.fileExists(atPath: diskCachePath) {
            try? fileManager.createDirectory(atPath: diskCachePath, withIntermediateDirectories: true)
        }
        
        // print("🖼️ [ImageCache] 已初始化 - 内存: 500MB, 磁盘路径: \(diskCachePath)")
    }
    
    // 获取缓存（先查内存，再查磁盘）
    func get(forKey key: String) -> UIImage? {
        let cacheKey = key as NSString
        
        // 1. 优先查询内存缓存
        if let image = memoryCache.object(forKey: cacheKey) {
            // print("✅ [ImageCache] 内存命中: \(key.prefix(50))...")
            return image
        }
        
        // 2. 查询磁盘缓存
        if let diskImage = getDiskImage(forKey: key) {
            // print("✅ [ImageCache] 磁盘命中: \(key.prefix(50))...")
            // 恢复到内存缓存
            memoryCache.setObject(diskImage, forKey: cacheKey)
            return diskImage
        }
        
        return nil
    }
    
    // 设置缓存（同时写入内存和磁盘）
    func set(_ image: UIImage, forKey key: String) {
        let cacheKey = key as NSString
        
        // 写入内存缓存
        memoryCache.setObject(image, forKey: cacheKey)
        
        // 异步写入磁盘缓存
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.saveDiskImage(image, forKey: key)
        }
    }
    
    // 私有方法：从磁盘读取图片
    private func getDiskImage(forKey key: String) -> UIImage? {
        let fileName = simpleHash(key)
        let filePath = (diskCachePath as NSString).appendingPathComponent(fileName)
        
        if let imageData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    // 私有方法：保存图片到磁盘
    private func saveDiskImage(_ image: UIImage, forKey key: String) {
        let fileName = simpleHash(key)
        let filePath = (diskCachePath as NSString).appendingPathComponent(fileName)
        
        // 使用 JPEG 格式，质量 85%
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: URL(fileURLWithPath: filePath))
            // print("💾 [ImageCache] 已保存至磁盘: \(key.prefix(30))")
        }
    }
    
    // 简单哈希函数（无需 CommonCrypto）
    private func simpleHash(_ key: String) -> String {
        let hash = abs(key.hashValue)
        return "img_\(hash).jpg"
    }
    
    // 清空所有缓存
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(atPath: diskCachePath)
        try? fileManager.createDirectory(atPath: diskCachePath, withIntermediateDirectories: true)
        // print("🗑️ [ImageCache] 已清空所有缓存")
    }
    
    // 获取缓存大小
    func getCacheSize() -> UInt64 {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: diskCachePath), includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: UInt64 = 0
        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? NSNumber {
                totalSize += size.uint64Value
            }
        }
        return totalSize
    }
}
