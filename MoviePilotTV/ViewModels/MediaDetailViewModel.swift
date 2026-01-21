//
//  MediaDetailViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import Foundation

struct Episode: Identifiable {
    let id = UUID()
    let episodeNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let stillPath: String?
    
    var stillURL: URL? {
        guard let path = stillPath, !path.isEmpty else { return nil }
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

@MainActor
class MediaDetailViewModel: ObservableObject {
    @Published var mediaDetail: MediaDetail?
    @Published var credits: CreditsResponse?
    @Published var searchResults: [Torrent] = []
    @Published var isLoadingDetail = false
    @Published var isLoadingCredits = false
    @Published var isSearching = false
    @Published var isSubscribing = false
    @Published var isDownloading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccessAlert = false
    @Published var successMessage = ""
    
    // 搜索进度相关
    @Published var searchProgress: Double = 0
    @Published var searchProgressText: String = ""
    @Published var showSearchProgress = false
    @Published var visibleSearchResults: [Torrent] = []
    @Published var scrollToResultsNonce = UUID()
    @Published var isSubscribed = false
    @Published var currentSubscriptionId: Int? = nil
    @Published var seasonSubscriptionStatus: [Int: Bool] = [:]
    @Published var seasonSubscriptionIds: [Int: Int] = [:] // 存储每个季的订阅ID
    @Published var seasonsExistData: [String: [Int]] = [:]
    @Published var episodes: [Episode] = []
    @Published var isLoadingEpisodes = false
    
    private let apiService = APIService.shared
    private let sseService = SSEService()
    private var searchCompleteTimer: Timer?
    private let searchPageSize = 20

    // MARK: - 搜索缓存（10 分钟）
    private struct CachedSearchEntry: Codable {
        let timestamp: Date
        let torrents: [Torrent]
    }

    private static var searchCache: [String: CachedSearchEntry] = loadSearchCacheFromDefaults()
    private static let searchCacheTTL: TimeInterval = 10 * 60 // 10 分钟
    private static let searchCacheUserDefaultsKey = "MediaDetailSearchCache_v1"

    private var lastSearchCacheKey: String? = nil

    private static func getCachedSearchResults(forKey key: String) -> [Torrent]? {
        if let entry = searchCache[key] {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age < searchCacheTTL {
                return entry.torrents
            } else {
                // 过期，移除
                searchCache.removeValue(forKey: key)
                saveSearchCacheToDefaults()
                return nil
            }
        }
        return nil
    }

    private static func setCachedSearchResults(_ torrents: [Torrent], forKey key: String) {
        searchCache[key] = CachedSearchEntry(timestamp: Date(), torrents: torrents)
        pruneExpiredCacheEntries()
        saveSearchCacheToDefaults()
    }

    private static func pruneExpiredCacheEntries() {
        let now = Date()
        var removed = 0
        for (k, entry) in searchCache {
            if now.timeIntervalSince(entry.timestamp) >= searchCacheTTL {
                searchCache.removeValue(forKey: k)
                removed += 1
            }
        }
        if removed > 0 {
            print("🧹 [MediaDetailVM] 清理过期缓存条目: \(removed)")
        }
    }

    private static func loadSearchCacheFromDefaults() -> [String: CachedSearchEntry] {
        guard let data = UserDefaults.standard.data(forKey: searchCacheUserDefaultsKey) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode([String: CachedSearchEntry].self, from: data)
            return decoded
        } catch {
            print("⚠️ [MediaDetailVM] 读取搜索缓存失败: \(error)")
            return [:]
        }
    }

    private static func saveSearchCacheToDefaults() {
        do {
            let data = try JSONEncoder().encode(searchCache)
            UserDefaults.standard.set(data, forKey: searchCacheUserDefaultsKey)
        } catch {
            print("⚠️ [MediaDetailVM] 保存搜索缓存失败: \(error)")
        }
    }
    
    // 从 MediaItem 加载详情
    func loadDetail(from media: MediaItem) {
        // 首先尝试从 source 字段确定来源
        var sourceType: String?
        var mediaId: String?
        
        if let source = media.source {
            let sourceLower = source.lowercased()
            if sourceLower.contains("tmdb") || sourceLower.contains("themoviedb") {
                sourceType = "tmdb"
                if let tmdbId = media.tmdbId {
                    mediaId = String(tmdbId)
                }
            } else if sourceLower.contains("douban") {
                sourceType = "douban"
                mediaId = media.doubanId
            }
        }
        
        // 如果 source 字段无法确定，则根据可用的 ID 来推断
        if sourceType == nil || mediaId == nil {
            if let tmdbId = media.tmdbId {
                sourceType = "tmdb"
                mediaId = String(tmdbId)
            } else if let doubanId = media.doubanId {
                sourceType = "douban"
                mediaId = doubanId
            }
        }
        
        // 验证是否获取到了必要的信息
        guard let finalSource = sourceType, let finalId = mediaId else {
            errorMessage = "无法确定媒体来源或ID\n来源: \(media.source ?? "未知")\nTMDB ID: \(media.tmdbId.map(String.init) ?? "无")\n豆瓣 ID: \(media.doubanId ?? "无")"
            showError = true
            return
        }
        
        // 确定类型名称
        let typeName = media.type ?? "电影"
        
        print("🔵 [MediaDetailVM] 识别媒体来源: \(finalSource), ID: \(finalId), 标题: \(media.title)")
        
        Task {
            await loadDetailFromAPI(source: finalSource, id: finalId, title: media.title, year: media.year, typeName: typeName)
        }
    }
    
    private func loadDetailFromAPI(source: String, id: String, title: String, year: String?, typeName: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        
        do {
            print("🔵 [MediaDetailVM] 加载详情 - 来源: \(source), ID: \(id), 标题: \(title), 年份: \(year ?? "未知"), 类型: \(typeName)")
            
            // source 参数已经在 loadDetail 中标准化为 "tmdb" 或 "douban"
            // 直接使用即可，无需再次转换
            
            mediaDetail = try await apiService.getMediaDetail(
                source: source,
                id: id,
                title: title,
                year: year,
                typeName: typeName
            )
            print("✅ [MediaDetailVM] 详情加载成功 - \(mediaDetail?.title ?? "未知标题")")
            seasonsExistData = mediaDetail?.seasons ?? [:]
            
            // 如果是电影，检查订阅状态
            if typeName == "电影", let detail = mediaDetail {
                await checkMovieSubscriptionStatus(source: source, id: id, title: detail.title)
            }
            
            // 如果是 TMDB 来源的电视剧，获取不存在的剧集信息
            if source == "tmdb" && typeName == "电视剧", let detail = mediaDetail {
                await loadNotExistsData(for: detail)
                await checkSeasonSubscriptionStatus(source: source, id: id, title: detail.title)
            }
            
            // 如果是 TMDB 来源，加载演职人员信息
            if source == "tmdb", let tmdbId = Int(id) {
                await loadCredits(tmdbId: tmdbId, mediaType: typeName)
            }
        } catch {
            print("❌ [MediaDetailVM] 详情加载失败: \(error)")
            errorMessage = "加载详情失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // 加载演职人员信息
    private func loadCredits(tmdbId: Int, mediaType: String) async {
        isLoadingCredits = true
        defer { isLoadingCredits = false }
        
        do {
            print("🔵 [MediaDetailVM] 加载演职人员 - TMDB ID: \(tmdbId), 类型: \(mediaType)")
            credits = try await apiService.getCredits(tmdbId: tmdbId, mediaType: mediaType)
            print("✅ [MediaDetailVM] 演职人员加载成功 - 演员: \(credits?.cast?.count ?? 0) 人")
        } catch {
            print("❌ [MediaDetailVM] 演职人员加载失败: \(error)")
            // 不显示错误，因为演职人员不是必需的
        }
    }
    
    // 检查季订阅状态
    private func checkSeasonSubscriptionStatus(source: String, id: String, title: String) async {
        guard let seasons = mediaDetail?.seasons, !seasons.isEmpty else {
            print("🔵 [MediaDetailVM] 无季信息，跳过季订阅状态检查")
            return
        }
        
        print("🔵 [MediaDetailVM] 检查季订阅状态 - 共 \(seasons.count) 季")
        
        // 并发检查所有季的订阅状态
        await withTaskGroup(of: (Int, Bool, Int?).self) { group in
            for (seasonKey, _) in seasons {
                if let seasonNumber = Int(seasonKey.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "季", with: "")) {
                    group.addTask {
                        do {
                            let (isSubscribed, subscriptionId) = try await self.apiService.checkSubscriptionStatus(
                                source: source,
                                id: id,
                                title: title,
                                season: seasonNumber
                            )
                            return (seasonNumber, isSubscribed, subscriptionId)
                        } catch {
                            print("❌ [MediaDetailVM] 检查第\(seasonNumber)季订阅状态失败: \(error)")
                            return (seasonNumber, false, nil)
                        }
                    }
                }
            }
            
            // 收集结果
            for await (seasonNumber, isSubscribed, subscriptionId) in group {
                await MainActor.run {
                    self.seasonSubscriptionStatus[seasonNumber] = isSubscribed
                    if let id = subscriptionId {
                        self.seasonSubscriptionIds[seasonNumber] = id
                    }
                    print("✅ [MediaDetailVM] 第\(seasonNumber)季订阅状态: \(isSubscribed ? "已订阅 (ID: \(subscriptionId ?? 0))" : "未订阅")")
                }
            }
        }
        
        print("✅ [MediaDetailVM] 所有季订阅状态检查完成")
    }
    
    // 检查电影订阅状态
    private func checkMovieSubscriptionStatus(source: String, id: String, title: String) async {
        do {
            print("🔵 [MediaDetailVM] 检查电影订阅状态 - 来源: \(source), ID: \(id), 标题: \(title)")
            let (isSubscribed, subscriptionId) = try await apiService.checkSubscriptionStatus(source: source, id: id, title: title, season: 0)
            await MainActor.run {
                self.isSubscribed = isSubscribed
                self.currentSubscriptionId = subscriptionId
                print("✅ [MediaDetailVM] 电影订阅状态: \(isSubscribed ? "已订阅 (ID: \(subscriptionId ?? 0))" : "未订阅")")
            }
        } catch {
            print("❌ [MediaDetailVM] 检查电影订阅状态失败: \(error)")
            // 失败时默认为未订阅
            await MainActor.run {
                self.isSubscribed = false
                self.currentSubscriptionId = nil
            }
        }
    }
    
    // 搜索资源
    func searchResources(forceRefresh: Bool = false) {
        guard let detail = mediaDetail else { return }
        
        // 确定来源和ID
        let source: String
        let id: String
        
        if let tmdbId = detail.tmdbId {
            source = "tmdb"
            id = String(tmdbId)
        } else if let doubanId = detail.doubanId {
            source = "douban"
            id = doubanId
        } else {
            errorMessage = "无法确定媒体ID"
            showError = true
            return
        }
        
        let mtype = detail.type ?? "电影"
        let sites = "1,2,5,6,8,9,10,11"
        
        // 生成缓存键（基于来源/ID/类型/标题/年份/季/站点）
        let cacheKey = [source, id, mtype, detail.title, detail.year ?? "", "", sites].joined(separator: "|")
        // 先尝试使用缓存
        if let cached = Self.getCachedSearchResults(forKey: cacheKey) {
            print("📦 [MediaDetailVM] 使用缓存搜索结果（key=\(cacheKey)），共 \(cached.count) 项，年龄小于10分钟")
            // 直接赋值并展示
            searchResults = cached
            resetVisibleResults()
            searchProgress = 100
            searchProgressText = "显示缓存结果"
            showSearchProgress = false
            return
        }

        // 没有缓存，继续执行真实搜索
        lastSearchCacheKey = cacheKey
        Task {
            // 显示进度对话框
            await MainActor.run {
                showSearchProgress = true
                searchProgress = 0
                searchProgressText = "正在准备搜索..."
            }
            
            // 连接 SSE 获取进度
            await connectToSearchProgress()
            
            // 执行搜索
            await searchResourcesFromAPI(
                source: source,
                id: id,
                mtype: mtype,
                title: detail.title,
                year: detail.year,
                season: nil,
                sites: sites,
                cacheKey: cacheKey
            )
            
            // 断开 SSE
            sseService.disconnect()
            
            print("🔵 [MediaDetailVM] 搜索完成，即将关闭进度对话框")
            print("🔵 [MediaDetailVM] 当前 searchResults.count = \(searchResults.count)")

            await MainActor.run {
                searchProgress = 100
                searchProgressText = "搜索完成"
                // 如果结果已经更新且非空，立即启动延迟关闭
                if !searchResults.isEmpty && showSearchProgress {
                    scheduleSearchProgressClose()
                }
                print("✅ [MediaDetailVM] 搜索进度已设置为100%")
                print("🔵 [MediaDetailVM] 最终 searchResults.count = \(searchResults.count)")
            }
        }
    }
    
    // 连接到搜索进度 SSE
    private func connectToSearchProgress() async {
        let base = AuthenticationManager.shared.apiEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty else {
            errorMessage = "未配置 API 服务器地址"
            showError = true
            return
        }
        let sseURL = "\(base)/api/v1/system/progress/search"
        sseService.connect(to: sseURL)
        
        // 监听进度更新
        Task {
            for await _ in Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().values {
                if let progress = sseService.latestProgress {
                    searchProgress = progress.value
                    searchProgressText = progress.text
                    
                    // 如果完成了，停止监听
                    if progress.value >= 100 {
                        break
                    }
                }
                
                // 如果不再显示进度，停止监听
                if !showSearchProgress {
                    break
                }
            }
        }
    }
    
    private func searchResourcesFromAPI(source: String, id: String, mtype: String, title: String, year: String?, season: String?, sites: String, cacheKey: String?) async {
        isSearching = true
        defer { isSearching = false }
        
        do {
            print("🔵 [MediaDetailVM] 搜索资源: \(source):\(id)")
            let result = try await apiService.searchMediaResources(
                source: source,
                id: id,
                mtype: mtype,
                title: title,
                year: year,
                season: season,
                sites: sites
            )
            
            // 确保在主线程更新 UI
            await MainActor.run {
                searchResults = result.torrents ?? []
                resetVisibleResults()
                print("✅ [MediaDetailVM] 找到 \(searchResults.count) 个资源")
                print("🔵 [MediaDetailVM] searchResults 已更新，count = \(searchResults.count)")
                
                // 将结果写入缓存（如果提供了缓存键）
                if let key = cacheKey {
                    print("📦 [MediaDetailVM] 将搜索结果写入缓存（key=\(key)，共 \(searchResults.count) 项）")
                    Self.setCachedSearchResults(searchResults, forKey: key)
                }
                
                // 如果搜索已完成（进度100%）且有结果，启动延迟关闭
                if searchProgress >= 100 && !searchResults.isEmpty && showSearchProgress {
                    scheduleSearchProgressClose()
                }
                
                if searchResults.isEmpty {
                    errorMessage = "未找到可用资源"
                    showError = true
                    showSearchProgress = false  // 关闭进度条
                }
            }
        } catch {
            print("❌ [MediaDetailVM] 资源搜索失败: \(error)")
            await MainActor.run {
                errorMessage = "搜索资源失败: \(error.localizedDescription)"
                showError = true
                showSearchProgress = false
            }
        }
    }

    private func resetVisibleResults() {
        if searchResults.isEmpty {
            visibleSearchResults = []
            return
        }
        let end = min(searchPageSize, searchResults.count)
        visibleSearchResults = Array(searchResults.prefix(end))
        scrollToResultsNonce = UUID()
    }

    func loadMoreResultsIfNeeded(currentIndex: Int) {
        guard currentIndex >= visibleSearchResults.count - 5 else { return }
        guard visibleSearchResults.count < searchResults.count else { return }
        let nextEnd = min(visibleSearchResults.count + searchPageSize, searchResults.count)
        let slice = searchResults[visibleSearchResults.count..<nextEnd]
        visibleSearchResults.append(contentsOf: slice)
    }

    func loadEpisodes(tmdbId: Int, seasonNumber: Int) async {
        print("🔵 [MediaDetailVM] ========== 加载剧集列表 ==========")
        print("🔵 [MediaDetailVM] tmdbId: \(tmdbId), season: \(seasonNumber)")
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        
        do {
            // 调用新的 API 获取完整的剧集详情
            print("📡 [MediaDetailVM] 开始调用 API 获取剧集详情...")
            let episodeDetails = try await apiService.getEpisodeDetails(tmdbId: tmdbId, seasonNumber: seasonNumber)
            print("✅ [MediaDetailVM] API 返回了 \(episodeDetails.count) 个剧集")
            
            // 转换为 Episode 模型
            episodes = episodeDetails.map { detail in
                Episode(
                    episodeNumber: detail.episodeNumber,
                    name: detail.name,
                    overview: detail.overview,
                    airDate: detail.airDate,
                    stillPath: detail.stillPath
                )
            }
            
            print("✅ [MediaDetailVM] 成功加载 \(episodes.count) 个剧集")
            if !episodes.isEmpty {
                let first = episodes[0]
                print("   示例 - 第\(first.episodeNumber)集: \(first.name)")
                print("     海报: \(first.stillPath ?? "无")")
                print("     简介: \(first.overview?.prefix(50) ?? "无")...")
            }
            
        } catch {
            print("❌ [MediaDetailVM] 获取剧集详情失败: \(error)")
            
            // 失败时生成占位数据
            print("⚠️ [MediaDetailVM] 使用占位数据作为后备方案")
            let existing = mediaDetail?.seasons?[String(seasonNumber)] ?? []
            let countFromInfo = mediaDetail?.seasonInfo?.first(where: { $0.seasonNumber == seasonNumber })?.episodeCount ?? 0
            let maxNumber = max(existing.max() ?? 0, countFromInfo)
            let total = max(maxNumber, existing.count)
            
            let numbers: [Int]
            if total > 0 {
                numbers = Array(1...total)
            } else {
                numbers = []
                print("⚠️ [MediaDetailVM] total 为 0，无法生成剧集列表")
            }
            
            episodes = numbers.map { number in
                Episode(
                    episodeNumber: number,
                    name: "第 \(number) 集",
                    overview: nil,
                    airDate: nil,
                    stillPath: nil
                )
            }
            print("⚠️ [MediaDetailVM] 生成了 \(episodes.count) 个占位剧集")
        }
        
        print("🔵 [MediaDetailVM] ========== 剧集列表加载完成 ==========")
    }

    func toggleSeasonSubscription(seasonNumber: Int, isCurrentlySubscribed: Bool) async {
        guard let detail = mediaDetail else { return }
        
        print("🔵 [MediaDetailVM] ===== 开始季订阅切换 =====")
        print("🔵 [MediaDetailVM] 季号: \(seasonNumber), 当前状态: \(isCurrentlySubscribed ? "已订阅" : "未订阅")")
        print("🔵 [MediaDetailVM] 媒体标题: \(detail.title)")
        
        isSubscribing = true
        defer { 
            isSubscribing = false
            print("🔵 [MediaDetailVM] ===== 季订阅切换完成 =====")
        }
        
        do {
            if isCurrentlySubscribed {
                // 取消订阅此季
                print("🔵 [MediaDetailVM] 执行取消订阅季操作")
                await performSeasonUnsubscribe(seasonNumber: seasonNumber, title: detail.title)
            } else {
                // 订阅此季
                print("🔵 [MediaDetailVM] 执行订阅季操作")
                await performSeasonSubscribe(seasonNumber: seasonNumber, detail: detail)
            }
        } catch {
            print("❌ [MediaDetailVM] 季订阅切换失败: \(error)")
            errorMessage = "订阅操作失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // 订阅/取消订阅切换
    func toggleSubscription() {
        guard let detail = mediaDetail else { return }
        
        Task {
            if isSubscribed, let subscriptionId = currentSubscriptionId {
                // 已订阅，执行取消订阅
                await performUnsubscribe(subscriptionId: subscriptionId, title: detail.title)
            } else {
                // 未订阅，执行订阅
                await performSubscribe(detail: detail)
            }
        }
    }
    
    // 订阅（兼容旧方法名）
    func subscribe() {
        toggleSubscription()
    }
    
    private func performSubscribe(detail: MediaDetail) async {
        isSubscribing = true
        defer { isSubscribing = false }
        
        do {
            print("🔵 [MediaDetailVM] 订阅: \(detail.title)")
            
            try await apiService.subscribe(
                name: detail.title,
                type: detail.type ?? "电影",
                year: detail.year,
                tmdbId: detail.tmdbId,
                doubanId: detail.doubanId,
                season: 0
            )
            
            print("✅ [MediaDetailVM] 订阅成功")
            successMessage = "已成功订阅《\(detail.title)》"
            showSuccessAlert = true
            isSubscribed = true
        } catch {
            print("❌ [MediaDetailVM] 订阅失败: \(error)")
            errorMessage = "订阅失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func performSeasonSubscribe(seasonNumber: Int, detail: MediaDetail) async {
        do {
            print("🔵 [MediaDetailVM] 调用API订阅季 - 标题: \(detail.title), 季: \(seasonNumber)")
            
            try await apiService.subscribe(
                name: detail.title,
                type: detail.type ?? "电视剧",
                year: detail.year,
                tmdbId: detail.tmdbId,
                doubanId: detail.doubanId,
                season: seasonNumber
            )
            
            print("✅ [MediaDetailVM] 季订阅API调用成功")
            successMessage = "已成功订阅《\(detail.title)》第\(seasonNumber)季"
            showSuccessAlert = true
            seasonSubscriptionStatus[seasonNumber] = true
            
            // 重新检查订阅状态以获取订阅ID
            if let source = detail.tmdbId != nil ? "tmdb" : "douban",
               let id = detail.tmdbId.map(String.init) ?? detail.doubanId {
                print("🔵 [MediaDetailVM] 重新检查订阅状态以获取订阅ID")
                let (isSubscribed, subscriptionId) = try await apiService.checkSubscriptionStatus(
                    source: source,
                    id: id,
                    title: detail.title,
                    season: seasonNumber
                )
                if let id = subscriptionId {
                    seasonSubscriptionIds[seasonNumber] = id
                    print("✅ [MediaDetailVM] 获取到季订阅ID: \(id)")
                }
            }
        } catch {
            print("❌ [MediaDetailVM] 季订阅失败: \(error)")
            errorMessage = "订阅失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func performSeasonUnsubscribe(seasonNumber: Int, title: String) async {
        guard let subscriptionId = seasonSubscriptionIds[seasonNumber] else {
            print("❌ [MediaDetailVM] 无法取消订阅季 - 没有找到订阅ID，季: \(seasonNumber)")
            errorMessage = "无法取消订阅：未找到订阅记录"
            showError = true
            return
        }
        
        do {
            print("🔵 [MediaDetailVM] 调用API取消订阅季 - 标题: \(title), 季: \(seasonNumber), 订阅ID: \(subscriptionId)")
            
            try await apiService.deleteSubscription(id: subscriptionId)
            
            print("✅ [MediaDetailVM] 季取消订阅API调用成功")
            successMessage = "已成功取消订阅《\(title)》第\(seasonNumber)季"
            showSuccessAlert = true
            seasonSubscriptionStatus[seasonNumber] = false
            seasonSubscriptionIds[seasonNumber] = nil // 清除订阅ID
            print("✅ [MediaDetailVM] 已清除季订阅ID记录")
        } catch {
            print("❌ [MediaDetailVM] 季取消订阅失败: \(error)")
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func performUnsubscribe(subscriptionId: Int, title: String) async {
        isSubscribing = true
        defer { isSubscribing = false }
        
        do {
            print("🔵 [MediaDetailVM] 取消订阅: \(title) (ID: \(subscriptionId))")
            
            try await apiService.deleteSubscription(id: subscriptionId)
            
            print("✅ [MediaDetailVM] 取消订阅成功")
            successMessage = "已成功取消订阅《\(title)》"
            showSuccessAlert = true
            isSubscribed = false
            currentSubscriptionId = nil
        } catch {
            print("❌ [MediaDetailVM] 取消订阅失败: \(error)")
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // 下载资源
    func downloadResource(torrent: Torrent) {
        Task {
            await performDownload(torrent: torrent)
        }
    }

    private func performDownload(torrent: Torrent) async {
        guard let detail = mediaDetail else {
            errorMessage = "无法获取媒体详情，无法创建下载任务"
            showError = true
            return
        }
        
        isDownloading = true
        defer { isDownloading = false }
        
        let request = buildDownloadRequest(torrent: torrent, detail: detail)
        // 日志: 打印提交信息和请求 payload（若可序列化）
        print("🔵 [MediaDetailVM] 提交下载请求 - 标题: \(torrent.title ?? "未知标题") 站点: \(torrent.siteName ?? "未知站点") 大小: \(torrent.size.map({ String($0) }) ?? "未知")")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            if let reqData = try? encoder.encode(request), let reqString = String(data: reqData, encoding: .utf8) {
                print("🔵 [MediaDetailVM] 下载请求 payload:\n\(reqString)")
            }

            // 明确提示将要调用的端点（便于快速定位）
            print("🔵 [MediaDetailVM] 调用 API: POST /api/v1/download/")

            let response = try await apiService.downloadTorrent(request: request)

            // 记录返回的响应摘要
            print("📗 [MediaDetailVM] 下载接口返回: success=\(response.success), message=\(response.message ?? "nil"), download_id=\(response.data?.download_id ?? "nil")")

            if response.success {
                var message = response.message ?? "已添加到下载队列"
                if let downloadId = response.data?.download_id, !downloadId.isEmpty {
                    message += " (ID: \(downloadId))"
                }
                successMessage = message
                showSuccessAlert = true
            } else {
                errorMessage = response.message ?? "下载失败"
                showError = true
            }
        } catch {
            print("❌ [MediaDetailVM] 下载失败: \(error) \n描述: \(error.localizedDescription)")
            errorMessage = "下载失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func buildDownloadRequest(torrent: Torrent, detail: MediaDetail) -> DownloadRequest {
        let info = torrent.torrentInfo
        let metaLabels = buildMetaLabels(metaInfo: torrent.metaInfo)
        let imdbString = detail.imdbId ?? detail.tmdbId.map(String.init) ?? detail.doubanId
        
        let torrentIn = TorrentIn(
            site: nil,
            site_name: info?.siteName ?? torrent.siteName,
            site_cookie: nil,
            site_ua: nil,
            site_proxy: nil,
            site_order: nil,
            site_downloader: nil,
            title: info?.title ?? torrent.title,
            description: info?.description ?? torrent.description,
            imdbid: imdbString,
            enclosure: info?.enclosure ?? torrent.enclosure,
            page_url: torrent.downloadUrl ?? torrent.enclosure,
            size: info?.size ?? torrent.size,
            seeders: info?.seeders ?? torrent.seeders,
            peers: info?.peers,
            grabs: nil,
            pubdate: info?.pubdate ?? torrent.pubdate,
            date_elapsed: nil,
            freedate: nil,
            uploadvolumefactor: nil,
            downloadvolumefactor: nil,
            hit_and_run: nil,
            labels: metaLabels.isEmpty ? nil : metaLabels,
            pri_order: nil,
            category: detail.category,
            volume_factor: nil,
            freedate_diff: nil
        )
        
        return DownloadRequest(
            torrent_in: torrentIn,
            downloader: nil,
            save_path: nil,
            media_in: detail
        )
    }
    
    private func buildMetaLabels(metaInfo: MetaInfo?) -> [String] {
        guard let meta = metaInfo else { return [] }
        var labels: [String] = []
        if let pix = meta.resourcePix { labels.append(pix) }
        if let video = meta.videoEncode { labels.append(video) }
        if let audio = meta.audioEncode { labels.append(audio) }
        if let effect = meta.resourceEffect { labels.append(effect) }
        if let type = meta.resourceType { labels.append(type) }
        if let edition = meta.edition { labels.append(edition) }
        return labels
    }
    
    // 启动搜索进度对话框的延迟关闭
    private func scheduleSearchProgressClose() {
        searchCompleteTimer?.invalidate()
        searchCompleteTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.showSearchProgress = false
            print("✅ [MediaDetailVM] 搜索进度框延迟500ms后已关闭")
        }
    }
    
    // 加载不存在的剧集数据（仅用于 TMDB 电视剧）
    private func loadNotExistsData(for detail: MediaDetail) async {
        do {
            print("🔵 [MediaDetailVM] 加载不存在剧集数据 - 标题: \(detail.title)")
            let notExistsData = try await apiService.getNotExistsEpisodes(mediaDetail: detail)
            
            // 输出完整的 API 响应数据用于排查
            print("📊 [MediaDetailVM] /api/v1/mediaserver/notexists 响应数据:")
            if notExistsData.isEmpty {
                print("   响应: [] (空数组)")
            } else {
                for (index, item) in notExistsData.enumerated() {
                    print("   [\(index)] 季: \(item.season), 总剧集数: \(item.totalEpisode), 开始缺失剧集: \(item.startEpisode), 缺失剧集列表: \(item.episodes)")
                }
            }
            
            if notExistsData.isEmpty {
                print("✅ [MediaDetailVM] 所有季都已入库")
                // 清空 seasonsExistData，表示所有季都存在
                seasonsExistData = [:]
            } else {
                print("⚠️ [MediaDetailVM] 发现缺失剧集: \(notExistsData.count) 个季有缺失")
                
                // 输出原始 seasons 数据用于对比
                if let seasons = detail.seasons {
                    print("📋 [MediaDetailVM] 原始 seasons 数据:")
                    for (seasonKey, episodes) in seasons.sorted(by: { $0.key < $1.key }) {
                        print("   季 \(seasonKey): \(episodes.count) 集 - \(episodes)")
                    }
                }
                
                // 将缺失数据转换为 seasonsExistData 格式
                var existData: [String: [Int]] = [:]
                
                // 首先填充所有季的完整剧集列表
                if let seasons = detail.seasons {
                    for (seasonKey, episodes) in seasons {
                        existData[seasonKey] = episodes
                    }
                }
                
                // 然后从每个季中移除缺失的剧集
                for notExist in notExistsData {
                    let seasonKey = String(notExist.season)
                    if var existingEpisodes = existData[seasonKey] {
                        print("🔄 [MediaDetailVM] 处理季 \(notExist.season) - 原始剧集数: \(existingEpisodes.count), start_episode: \(notExist.startEpisode), 缺失剧集列表: \(notExist.episodes)")
                        
                        // 根据 start_episode 判断缺失逻辑
                        if notExist.startEpisode == 1 {
                            // start_episode 为 1，表示整个季都缺失
                            print("   整个季都缺失，清空剧集列表")
                            existData[seasonKey] = []
                        } else if notExist.startEpisode > 1 {
                            // start_episode > 1，表示从该集开始缺失
                            let missingStart = notExist.startEpisode
                            print("   从第\(missingStart)集开始缺失")
                            existingEpisodes.removeAll { $0 >= missingStart }
                            existData[seasonKey] = existingEpisodes
                        } else if !notExist.episodes.isEmpty {
                            // 使用具体的缺失剧集列表
                            print("   使用具体的缺失剧集列表")
                            existingEpisodes.removeAll { notExist.episodes.contains($0) }
                            existData[seasonKey] = existingEpisodes
                        } else {
                            print("   ⚠️ 未知的缺失模式: start_episode=\(notExist.startEpisode), episodes=\(notExist.episodes)")
                        }
                        
                        print("   处理后剧集数: \(existData[seasonKey]?.count ?? 0), 剩余剧集: \(existData[seasonKey] ?? [])")
                    } else {
                        print("⚠️ [MediaDetailVM] 季 \(notExist.season) 在原始数据中不存在")
                    }
                }
                
                // 输出最终的 seasonsExistData
                print("📋 [MediaDetailVM] 处理后的 seasonsExistData:")
                for (seasonKey, episodes) in existData.sorted(by: { $0.key < $1.key }) {
                    print("   季 \(seasonKey): \(episodes.count) 集 - \(episodes)")
                }
                
                seasonsExistData = existData
            }
        } catch {
            print("❌ [MediaDetailVM] 加载不存在剧集数据失败: \(error)")
            // 失败时使用原始数据
            seasonsExistData = detail.seasons ?? [:]
        }
    }
    
    deinit {
        searchCompleteTimer?.invalidate()
    }
}
