import Foundation

/// 本地数据缓存管理器
class LocalCacheManager {
    static let shared = LocalCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // 缓存键
    private enum CacheKey: String {
        case featuredMedia = "home_featured_media"
        case tmdbTrending = "home_tmdb_trending"
        case doubanHotMovies = "home_douban_hot_movies"
        case doubanHotTVs = "home_douban_hot_tvs"
        case recentSubscriptions = "home_recent_subscriptions"
        case subscriptionsList = "subscriptions_list"
        case downloads = "downloads_list"
        case tmdbLookup = "tmdb_lookup_cache"
        
        var key: String {
            return self.rawValue
        }
    }

    private struct TmdbLookupEntry: Codable {
        let tmdbId: Int
        let expireAt: Date
    }
    
    private init() {
        // 初始化缓存目录
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("LocalCache")
        
        // 创建缓存目录
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // print("💾 [LocalCacheManager] 已初始化 - 缓存路径: \(cacheDirectory.path)")
    }
    
    // MARK: - 首页数据缓存
    
    /// 保存首页特色媒体
    func saveFeaturedMedia(_ media: [MediaItem]) {
        saveMediaList(media, forKey: .featuredMedia)
    }
    
    /// 获取首页特色媒体缓存
    func getFeaturedMedia() -> [MediaItem]? {
        return getMediaList(forKey: .featuredMedia)
    }
    
    /// 保存 TMDB 趋势
    func saveTmdbTrending(_ media: [MediaItem]) {
        saveMediaList(media, forKey: .tmdbTrending)
    }
    
    /// 获取 TMDB 趋势缓存
    func getTmdbTrending() -> [MediaItem]? {
        return getMediaList(forKey: .tmdbTrending)
    }
    
    /// 保存豆瓣热门电影
    func saveDoubanHotMovies(_ media: [MediaItem]) {
        saveMediaList(media, forKey: .doubanHotMovies)
    }
    
    /// 获取豆瓣热门电影缓存
    func getDoubanHotMovies() -> [MediaItem]? {
        return getMediaList(forKey: .doubanHotMovies)
    }
    
    /// 保存豆瓣热门剧集
    func saveDoubanHotTVs(_ media: [MediaItem]) {
        saveMediaList(media, forKey: .doubanHotTVs)
    }
    
    /// 获取豆瓣热门剧集缓存
    func getDoubanHotTVs() -> [MediaItem]? {
        return getMediaList(forKey: .doubanHotTVs)
    }
    
    /// 保存最近订阅
    func saveRecentSubscriptions(_ subscriptions: [Subscription]) {
        saveSubscriptionList(subscriptions, forKey: .recentSubscriptions)
    }
    
    /// 获取最近订阅缓存
    func getRecentSubscriptions() -> [Subscription]? {
        return getSubscriptionList(forKey: .recentSubscriptions)
    }
    
    // MARK: - 订阅列表缓存
    
    /// 保存订阅列表
    func saveSubscriptionsList(_ subscriptions: [Subscription]) {
        saveSubscriptionList(subscriptions, forKey: .subscriptionsList)
    }
    
    /// 获取订阅列表缓存
    func getSubscriptionsList() -> [Subscription]? {
        return getSubscriptionList(forKey: .subscriptionsList)
    }
    
    // MARK: - 下载列表缓存
    
    /// 保存下载列表
    func saveDownloadsList(_ downloads: [Download]) {
        saveDownloadList(downloads, forKey: .downloads)
    }
    
    /// 获取下载列表缓存
    func getDownloadsList() -> [Download]? {
        return getDownloadList(forKey: .downloads)
    }

    // MARK: - TMDB ID 解析缓存（7天过期）

    /// 缓存 TMDB ID 解析结果
    func cacheTmdbId(_ tmdbId: Int, for lookupKey: String, ttl: TimeInterval = 7 * 24 * 60 * 60) {
        let entry = TmdbLookupEntry(tmdbId: tmdbId, expireAt: Date().addingTimeInterval(ttl))
        do {
            let data = try JSONEncoder().encode(entry)
            let filePath = cacheDirectory.appendingPathComponent("\(CacheKey.tmdbLookup.key)_\(lookupKey)")
            try data.write(to: filePath)
            // print("💾 [LocalCacheManager] 已缓存 TMDB ID: \(tmdbId) key=\(lookupKey) 过期时间=\(entry.expireAt)")
        } catch {
            // print("❌ [LocalCacheManager] 缓存 TMDB ID 失败 key=\(lookupKey): \(error.localizedDescription)")
        }
    }

    /// 获取 TMDB ID 解析缓存（自动清理过期记录）
    func getCachedTmdbId(for lookupKey: String) -> Int? {
        let filePath = cacheDirectory.appendingPathComponent("\(CacheKey.tmdbLookup.key)_\(lookupKey)")
        do {
            let data = try Data(contentsOf: filePath)
            let entry = try JSONDecoder().decode(TmdbLookupEntry.self, from: data)
            if entry.expireAt < Date() {
                try? fileManager.removeItem(at: filePath)
                // print("⚠️ [LocalCacheManager] TMDB ID 缓存已过期 key=\(lookupKey)，已清理")
                return nil
            }
            // print("✅ [LocalCacheManager] 命中 TMDB ID 缓存 key=\(lookupKey) -> \(entry.tmdbId)")
            return entry.tmdbId
        } catch {
            return nil
        }
    }
    
    // MARK: - 私有方法
    
    /// 保存媒体列表
    private func saveMediaList(_ media: [MediaItem], forKey key: CacheKey) {
        do {
            let data = try JSONEncoder().encode(media)
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            try data.write(to: filePath)
            // print("💾 [LocalCacheManager] 已保存 \(key.key) - 共 \(media.count) 项")
        } catch {
            // print("❌ [LocalCacheManager] 保存失败 \(key.key): \(error.localizedDescription)")
        }
    }
    
    /// 获取媒体列表
    private func getMediaList(forKey key: CacheKey) -> [MediaItem]? {
        do {
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            let data = try Data(contentsOf: filePath)
            let media = try JSONDecoder().decode([MediaItem].self, from: data)
            // print("✅ [LocalCacheManager] 读取缓存 \(key.key) - 共 \(media.count) 项")
            return media
        } catch {
            // print("⚠️ [LocalCacheManager] 读取缓存失败 \(key.key)")
            return nil
        }
    }
    
    /// 保存订阅列表
    private func saveSubscriptionList(_ subscriptions: [Subscription], forKey key: CacheKey) {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            try data.write(to: filePath)
            // print("💾 [LocalCacheManager] 已保存 \(key.key) - 共 \(subscriptions.count) 项")
        } catch {
            // print("❌ [LocalCacheManager] 保存失败 \(key.key): \(error.localizedDescription)")
        }
    }
    
    /// 获取订阅列表
    private func getSubscriptionList(forKey key: CacheKey) -> [Subscription]? {
        do {
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            let data = try Data(contentsOf: filePath)
            let subscriptions = try JSONDecoder().decode([Subscription].self, from: data)
            // print("✅ [LocalCacheManager] 读取缓存 \(key.key) - 共 \(subscriptions.count) 项")
            return subscriptions
        } catch {
            // print("⚠️ [LocalCacheManager] 读取缓存失败 \(key.key)")
            return nil
        }
    }
    
    /// 保存下载列表
    private func saveDownloadList(_ downloads: [Download], forKey key: CacheKey) {
        do {
            let data = try JSONEncoder().encode(downloads)
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            try data.write(to: filePath)
                // print("💾 [LocalCacheManager] 已保存 \(key.key) - 共 \(downloads.count) 项")
        } catch {
            // print("❌ [LocalCacheManager] 保存失败 \(key.key): \(error.localizedDescription)")
        }
    }
    
    /// 获取下载列表
    private func getDownloadList(forKey key: CacheKey) -> [Download]? {
        do {
            let filePath = cacheDirectory.appendingPathComponent(key.key)
            let data = try Data(contentsOf: filePath)
            let downloads = try JSONDecoder().decode([Download].self, from: data)
                // print("✅ [LocalCacheManager] 读取缓存 \(key.key) - 共 \(downloads.count) 项")
            return downloads
        } catch {
            // print("⚠️ [LocalCacheManager] 读取缓存失败 \(key.key)")
            return nil
        }
    }
    
    /// 清除所有缓存
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        // print("🧹 [LocalCacheManager] 已清除所有缓存")
    }
    
    /// 获取缓存大小
    func getCacheSize() -> UInt64 {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
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
