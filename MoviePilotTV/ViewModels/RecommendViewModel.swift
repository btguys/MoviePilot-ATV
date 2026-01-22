//
//  RecommendViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

@MainActor
class RecommendViewModel: ObservableObject {
    @Published var sections: [RecommendSection] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let apiService = APIService.shared
    
    func loadAllRecommendations() {
        isLoading = true
        sections = []
        
        print("🔵 [RecommendViewModel] 开始加载所有推荐分类...")
        
        Task {
            // 定义所有推荐分类
            let categories: [(String, String)] = [
                ("tmdb_trending", "TMDB 流行趋势"),
                ("tmdb_movies", "TMDB 电影"),
                ("tmdb_tvs", "TMDB 剧集"),
                ("douban_movie_hot", "豆瓣热门电影"),
                ("douban_tv_hot", "豆瓣热门剧集"),
                ("douban_movie_top250", "豆瓣电影 TOP250"),
                ("douban_movies", "豆瓣最新电影"),
                ("douban_tvs", "豆瓣最新剧集")
            ]
            
            print("📊 [RecommendViewModel] 准备加载 \(categories.count) 个分类")
            
            // 并发加载所有分类
            await withTaskGroup(of: (String, [MediaItem]?).self) { group in
                for (source, title) in categories {
                    group.addTask {
                        print("📡 [RecommendViewModel] 加载: \(title) (\(source))")
                        do {
                            let items = try await self.apiService.getRecommendations(source: source)
                            print("✅ [RecommendViewModel] \(title): \(items.count) 项")
                            return (title, items)
                        } catch {
                            print("❌ [RecommendViewModel] \(title) 失败: \(error)")
                            return (title, nil)
                        }
                    }
                }
                
                for await (title, items) in group {
                    if let items = items, !items.isEmpty {
                        sections.append(RecommendSection(title: title, items: items))
                    }
                }
            }
            
            print("✅ [RecommendViewModel] 成功加载 \(sections.count) 个分类")
            
            // 按原始顺序排序
            sections.sort { section1, section2 in
                let order = categories.map { $0.1 }
                let index1 = order.firstIndex(of: section1.title) ?? Int.max
                let index2 = order.firstIndex(of: section2.title) ?? Int.max
                return index1 < index2
            }
            
            isLoading = false
        }
    }
}

struct RecommendSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [MediaItem]
}
