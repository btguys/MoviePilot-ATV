//
//  CategoryMoreViewModel.swift
//  MoviePilotTV
//
//  Created on 2026-01-22.
//

import Foundation

@MainActor
class CategoryMoreViewModel: ObservableObject {
    @Published var allMedia: [MediaItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let apiService = APIService.shared
    private let cacheManager = LocalCacheManager.shared
    private var currentPage = 1
    private let source: String
    private let categoryTitle: String
    
    init(source: String, categoryTitle: String) {
        self.source = source
        self.categoryTitle = categoryTitle
    }
    
    /// 加载初始数据（缓存优先）
    func loadInitialData() {
        print("🎬 [CategoryMoreVM] 加载初始数据: \(categoryTitle)")
        
        // 先尝试从缓存加载
        if let cached = loadFromCache() {
            allMedia = cached
            print("✅ [CategoryMoreVM] 从缓存加载 \(cached.count) 项")
            // 如果有缓存，不刷新第一页，保持已加载的数据
            return
        }
        
        // 没有缓存时才后台刷新第一页
        Task {
            await loadFirstPage()
        }
    }
    
    /// 加载第一页（刷新）
    private func loadFirstPage() async {
        guard !isLoading else { return }
        isLoading = true
        currentPage = 1
        hasMorePages = true
        
        do {
            let items = try await apiService.getRecommendations(source: source, page: 1)
            print("✅ [CategoryMoreVM] 加载第1页成功: \(items.count) 项")
            
            allMedia = items
            hasMorePages = !items.isEmpty
            
            // 保存到缓存
            saveToCache(items)
            
        } catch {
            print("❌ [CategoryMoreVM] 加载失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    /// 加载下一页
    func loadNextPage() async {
        guard !isLoadingMore, hasMorePages else {
            print("⏭️ [CategoryMoreVM] 跳过加载: isLoadingMore=\(isLoadingMore), hasMorePages=\(hasMorePages)")
            return
        }
        
        isLoadingMore = true
        currentPage += 1
        
        print("📄 [CategoryMoreVM] 加载第\(currentPage)页...")
        
        do {
            let items = try await apiService.getRecommendations(source: source, page: currentPage)
            print("✅ [CategoryMoreVM] 加载第\(currentPage)页成功: \(items.count) 项")
            
            if items.isEmpty {
                print("🏁 [CategoryMoreVM] 没有更多数据了")
                hasMorePages = false
            } else {
                allMedia.append(contentsOf: items)
                // 更新缓存
                saveToCache(allMedia)
            }
            
        } catch {
            print("❌ [CategoryMoreVM] 加载第\(currentPage)页失败: \(error)")
            currentPage -= 1  // 回退页码
        }
        
        isLoadingMore = false
    }
    
    // MARK: - 缓存管理
    
    private func cacheKey() -> String {
        return "category_more_\(source)"
    }
    
    private func loadFromCache() -> [MediaItem]? {
        let key = cacheKey()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalCache")
        let filePath = cacheDirectory.appendingPathComponent(key)
        
        do {
            let data = try Data(contentsOf: filePath)
            let items = try JSONDecoder().decode([MediaItem].self, from: data)
            return items
        } catch {
            return nil
        }
    }
    
    private func saveToCache(_ items: [MediaItem]) {
        let key = cacheKey()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalCache")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        let filePath = cacheDirectory.appendingPathComponent(key)
        
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: filePath)
            print("💾 [CategoryMoreVM] 已缓存 \(items.count) 项到 \(key)")
        } catch {
            print("❌ [CategoryMoreVM] 缓存失败: \(error)")
        }
    }
}
