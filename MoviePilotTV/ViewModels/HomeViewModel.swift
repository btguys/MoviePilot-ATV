//
//  HomeViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var featuredMedia: [MediaItem] = []
    @Published var tmdbTrending: [MediaItem] = []
    @Published var doubanHotMovies: [MediaItem] = []
    @Published var doubanHotTVs: [MediaItem] = []
    @Published var recentSubscriptions: [Subscription] = []
    @Published var isLoadingTrending = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isRefreshing = false  // 标记是否在后台刷新
    
    private let apiService = APIService.shared
    private let cacheManager = LocalCacheManager.shared
    
    func loadData() {
        // 第一步：先加载缓存数据（快速显示）
        loadCachedData()
        
        // 第二步：后台刷新网络数据
        Task {
            await refreshData()
        }
    }
    
    /// 从缓存加载数据（快速加载）
    private func loadCachedData() {
        print("🎬 [HomeViewModel] 从缓存加载首页数据...")
        
        // 并行加载所有缓存
        if let cached = cacheManager.getFeaturedMedia() {
            featuredMedia = cached
            print("✅ [HomeViewModel] 缓存命中: featuredMedia - \(cached.count) 项")
        }
        
        if let cached = cacheManager.getTmdbTrending() {
            tmdbTrending = cached
            print("✅ [HomeViewModel] 缓存命中: tmdbTrending - \(cached.count) 项")
        }
        
        if let cached = cacheManager.getDoubanHotMovies() {
            doubanHotMovies = cached
            print("✅ [HomeViewModel] 缓存命中: doubanHotMovies - \(cached.count) 项")
        }
        
        if let cached = cacheManager.getDoubanHotTVs() {
            doubanHotTVs = cached
            print("✅ [HomeViewModel] 缓存命中: doubanHotTVs - \(cached.count) 项")
        }
        
        if let cached = cacheManager.getRecentSubscriptions() {
            recentSubscriptions = cached
            print("✅ [HomeViewModel] 缓存命中: recentSubscriptions - \(cached.count) 项")
        }
    }
    
    /// 刷新网络数据（后台操作）
    private func refreshData() async {
        isRefreshing = true
        await loadRecommendations()
        await loadRecentSubscriptions()
        isRefreshing = false
    }
    
    private func loadRecommendations() async {
        isLoadingTrending = true
        
        print("🔵 [HomeViewModel] 开始刷新推荐内容...")
        let startTime = Date()
        
        do {
            // 并发加载多个推荐源
            print("📡 [HomeViewModel] 请求 tmdb_trending...")
            let tmdbStartTime = Date()
            async let tmdbTrendingTask = apiService.getRecommendations(source: "tmdb_trending")
            
            print("📡 [HomeViewModel] 请求 douban_movie_hot...")
            let doubanMovieStartTime = Date()
            async let doubanMoviesTask = apiService.getRecommendations(source: "douban_movie_hot")
            
            print("📡 [HomeViewModel] 请求 douban_tv_hot...")
            let doubanTVStartTime = Date()
            async let doubanTVsTask = apiService.getRecommendations(source: "douban_tv_hot")
            
            let (tmdb, doubanMovies, doubanTVs) = try await (tmdbTrendingTask, doubanMoviesTask, doubanTVsTask)
            
            let tmdbDuration = Date().timeIntervalSince(tmdbStartTime) * 1000
            let doubanMovieDuration = Date().timeIntervalSince(doubanMovieStartTime) * 1000
            let doubanTVDuration = Date().timeIntervalSince(doubanTVStartTime) * 1000
            let totalDuration = Date().timeIntervalSince(startTime) * 1000
            
            print("✅ [HomeViewModel] 成功获取: TMDB=\(tmdb.count), 豆瓣电影=\(doubanMovies.count), 豆瓣剧集=\(doubanTVs.count)")
            print("⏱️  [HomeViewModel] 响应速度:")
            print("   TMDB: \(String(format: "%.0f", tmdbDuration))ms")
            print("   豆瓣电影: \(String(format: "%.0f", doubanMovieDuration))ms")
            print("   豆瓣剧集: \(String(format: "%.0f", doubanTVDuration))ms")
            print("   总耗时: \(String(format: "%.0f", totalDuration))ms")
            
            // 更新数据
            let tmdbArray = Array(tmdb.prefix(10))
            let moviesArray = Array(doubanMovies.prefix(10))
            let tvsArray = Array(doubanTVs.prefix(10))
            
            tmdbTrending = tmdbArray
            doubanHotMovies = moviesArray
            doubanHotTVs = tvsArray

            // 记录豆瓣海报可用性，排查图片无法显示问题
            let movieMissingPoster = moviesArray.filter { ($0.posterPath ?? "").isEmpty }.count
            let tvMissingPoster = tvsArray.filter { ($0.posterPath ?? "").isEmpty }.count
            print("🟣 [HomeViewModel] 豆瓣热门电影: 总数=\(moviesArray.count), 海报缺失=\(movieMissingPoster)")
            print("🟣 [HomeViewModel] 豆瓣热门剧集: 总数=\(tvsArray.count), 海报缺失=\(tvMissingPoster)")
            let moviePosterSamples = moviesArray.prefix(3).map { $0.posterPath ?? "<nil>" }.joined(separator: " | ")
            let tvPosterSamples = tvsArray.prefix(3).map { $0.posterPath ?? "<nil>" }.joined(separator: " | ")
            print("🔎 [HomeViewModel] 豆瓣电影 posterPath 样本: \(moviePosterSamples)")
            print("🔎 [HomeViewModel] 豆瓣剧集 posterPath 样本: \(tvPosterSamples)")
            
            // 设置精选内容
            if !tmdb.isEmpty {
                featuredMedia = Array(tmdb.prefix(1))
            }
            
            // 保存到缓存
            cacheManager.saveTmdbTrending(tmdbArray)
            cacheManager.saveDoubanHotMovies(moviesArray)
            cacheManager.saveDoubanHotTVs(tvsArray)
            cacheManager.saveFeaturedMedia(featuredMedia)
            
            // 更新 Top Shelf 内容
            print("🔝 [HomeViewModel] 准备更新 Top Shelf，TMDB 项目数: \(tmdbArray.count)")
            if tmdbArray.isEmpty {
                print("⚠️ [HomeViewModel] TMDB 数组为空，Top Shelf 将无内容!")
            } else {
                print("   前3项: \(tmdbArray.prefix(3).map { $0.title })")
            }
            TopShelfHelper.shared.updateTopShelfRecommendations(tmdbArray)
            
            print("✅ [HomeViewModel] 推荐内容已保存到缓存")
            
        } catch {
            print("❌ [HomeViewModel] 刷新失败: \(error)")
            if let apiError = error as? APIError {
                print("   API Error: \(apiError.localizedDescription)")
            }
            errorMessage = "刷新推荐内容失败: \(error.localizedDescription)"
            showError = true
        }
        
        isLoadingTrending = false
    }
    
    private func loadRecentSubscriptions() async {
        do {
            let subscriptions = try await apiService.getSubscriptions()
            let recentArray = Array(subscriptions.prefix(10))
            
            recentSubscriptions = recentArray
            
            // 保存到缓存
            cacheManager.saveRecentSubscriptions(recentArray)
            print("✅ [HomeViewModel] 最近订阅已保存到缓存 - \(recentArray.count) 项")
            
        } catch {
            print("⚠️ [HomeViewModel] 加载订阅失败: \(error)")
        }
    }
}
