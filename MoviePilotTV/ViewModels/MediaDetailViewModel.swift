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
    @Published var seasonSubscriptionStatus: [Int: Bool] = [:]
    @Published var seasonsExistData: [String: [Int]] = [:]
    @Published var episodes: [Episode] = []
    @Published var isLoadingEpisodes = false
    
    private let apiService = APIService.shared
    private let sseService = SSEService()
    private var searchCompleteTimer: Timer?
    private let searchPageSize = 20
    
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
    
    // 搜索资源
    func searchResources() {
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
                sites: sites
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
    
    private func searchResourcesFromAPI(source: String, id: String, mtype: String, title: String, year: String?, season: String?, sites: String) async {
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
        
        isSubscribing = true
        defer { isSubscribing = false }
        
        do {
            if isCurrentlySubscribed {
                // 取消订阅逻辑（如果API支持）
                print("🔵 [MediaDetailVM] 取消订阅季: \(detail.title) - 第\(seasonNumber)季")
                // TODO: 调用取消订阅API（如果有）
                seasonSubscriptionStatus[seasonNumber] = false
            } else {
                // 订阅此季
                print("🔵 [MediaDetailVM] 订阅季: \(detail.title) - 第\(seasonNumber)季")
                
                try await apiService.subscribe(
                    name: detail.title,
                    type: detail.type ?? "电视剧",
                    year: detail.year,
                    tmdbId: detail.tmdbId,
                    doubanId: detail.doubanId,
                    season: seasonNumber
                )
                
                print("✅ [MediaDetailVM] 订阅季成功")
                seasonSubscriptionStatus[seasonNumber] = true
            }
        } catch {
            print("❌ [MediaDetailVM] 订阅季失败: \(error)")
            errorMessage = "订阅失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // 订阅
    func subscribe() {
        guard let detail = mediaDetail else { return }
        
        Task {
            await performSubscribe(detail: detail)
        }
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
        do {
            let response = try await apiService.downloadTorrent(request: request)
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
            print("❌ [MediaDetailVM] 下载失败: \(error)")
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
    
    deinit {
        searchCompleteTimer?.invalidate()
    }
}
