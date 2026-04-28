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

        // 使用 TaskGroup 独立加载每个推荐源，防止单个失败影响其他
        await withTaskGroup(of: Void.self) { group in
            // TMDB 流行趋势
            group.addTask {
                do {
                    print("📡 [HomeViewModel] 请求 tmdb_trending...")
                    let tmdbStartTime = Date()
                    let tmdb = try await self.apiService.getRecommendations(source: "tmdb_trending")
                    let duration = Date().timeIntervalSince(tmdbStartTime) * 1000

                    let tmdbArray = Array(tmdb.prefix(10))
                    print("✅ [HomeViewModel] TMDB 流行趋势: \(tmdbArray.count) 项 (\(String(format: "%.0f", duration))ms)")

                    await MainActor.run {
                        self.tmdbTrending = tmdbArray
                        self.cacheManager.saveTmdbTrending(tmdbArray)

                        // 精选内容使用 TMDB 第一个
                        if !tmdbArray.isEmpty {
                            self.featuredMedia = Array(tmdbArray.prefix(1))
                            self.cacheManager.saveFeaturedMedia(self.featuredMedia)
                        }

                        // 更新 Top Shelf
                        TopShelfHelper.shared.updateTopShelfRecommendations(tmdbArray)
                    }
                } catch {
                    print("❌ [HomeViewModel] TMDB 流行趋势 失败: \(error)")
                }
            }

            // 豆瓣热门电影
            group.addTask {
                do {
                    print("📡 [HomeViewModel] 请求 douban_movie_hot...")
                    let doubanMovieStartTime = Date()
                    let movies = try await self.apiService.getRecommendations(source: "douban_movie_hot")
                    let duration = Date().timeIntervalSince(doubanMovieStartTime) * 1000

                    let moviesArray = Array(movies.prefix(10))
                    print("✅ [HomeViewModel] 豆瓣热门电影: \(moviesArray.count) 项 (\(String(format: "%.0f", duration))ms)")

                    let movieMissingPoster = moviesArray.filter { ($0.posterPath ?? "").isEmpty }.count
                    print("🟣 [HomeViewModel] 豆瓣热门电影: 海报缺失=\(movieMissingPoster)")
                    let moviePosterSamples = moviesArray.prefix(3).map { $0.posterPath ?? "<nil>" }.joined(separator: " | ")
                    print("🔎 [HomeViewModel] 豆瓣电影 posterPath 样本: \(moviePosterSamples)")

                    await MainActor.run {
                        self.doubanHotMovies = moviesArray
                        self.cacheManager.saveDoubanHotMovies(moviesArray)
                    }
                } catch {
                    print("❌ [HomeViewModel] 豆瓣热门电影 失败: \(error)")
                }
            }

            // 豆瓣国产剧集
            group.addTask {
                do {
                    print("📡 [HomeViewModel] 请求 douban_tv_weekly_chinese...")
                    let doubanTVStartTime = Date()
                    let tvs = try await self.apiService.getRecommendations(source: "douban_tv_weekly_chinese")
                    let tvsArray = Array(tvs.prefix(10))

                    let duration = Date().timeIntervalSince(doubanTVStartTime) * 1000
                    print("✅ [HomeViewModel] 豆瓣国产剧集: \(tvsArray.count) 项 (\(String(format: "%.0f", duration))ms)")

                    let tvMissingPoster = tvsArray.filter { ($0.posterPath ?? "").isEmpty }.count
                    print("🟣 [HomeViewModel] 豆瓣国产剧集: 海报缺失=\(tvMissingPoster)")
                    let tvPosterSamples = tvsArray.prefix(3).map { $0.posterPath ?? "<nil>" }.joined(separator: " | ")
                    print("🔎 [HomeViewModel] 豆瓣剧集 posterPath 样本: \(tvPosterSamples)")

                    await MainActor.run {
                        self.doubanHotTVs = tvsArray
                        self.cacheManager.saveDoubanHotTVs(tvsArray)
                    }
                } catch {
                    print("❌ [HomeViewModel] 豆瓣国产剧集 失败: \(error)")
                }
            }
        }

        let totalDuration = Date().timeIntervalSince(startTime) * 1000
        print("✅ [HomeViewModel] 首页推荐刷新完成 (总耗时: \(String(format: "%.0f", totalDuration))ms)")
        print("   TMDB=\(tmdbTrending.count), 豆瓣电影=\(doubanHotMovies.count), 豆瓣国产剧集=\(doubanHotTVs.count)")

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
