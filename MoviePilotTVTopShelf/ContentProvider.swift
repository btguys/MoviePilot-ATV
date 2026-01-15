//
//  ContentProvider.swift
//  MoviePilotTVTopShelf
//
//  Created on 2026-01-15.
//

import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {
    
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        print("🔝 [TopShelf] 开始加载 Top Shelf 内容")
        
        // 检查登录状态
        guard let _ = UserDefaults(suiteName: "group.com.moviepilot.tv")?.string(forKey: "accessToken"),
              !UserDefaults(suiteName: "group.com.moviepilot.tv")!.string(forKey: "accessToken")!.isEmpty else {
            print("⚠️ [TopShelf] 未登录，返回空内容")
            completionHandler(nil)
            return
        }
        
        // 从共享缓存获取推荐内容
        if let cachedItems = loadCachedRecommendations() {
            print("✅ [TopShelf] 成功加载 \(cachedItems.count) 个推荐项")
            let content = createTopShelfContent(from: cachedItems)
            completionHandler(content)
        } else {
            print("⚠️ [TopShelf] 缓存为空，返回空内容")
            completionHandler(nil)
        }
    }
    
    private func loadCachedRecommendations() -> [TopShelfMediaItem]? {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.moviepilot.tv") else {
            print("❌ [TopShelf] 无法访问共享 UserDefaults")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: "topShelfRecommendations") else {
            print("⚠️ [TopShelf] 缓存数据不存在")
            return nil
        }
        
        do {
            let items = try JSONDecoder().decode([TopShelfMediaItem].self, from: data)
            print("✅ [TopShelf] 解码成功: \(items.count) 个项目")
            return items
        } catch {
            print("❌ [TopShelf] 解码失败: \(error)")
            return nil
        }
    }
    
    private func createTopShelfContent(from items: [TopShelfMediaItem]) -> TVTopShelfContent {
        let contentItems = items.prefix(10).compactMap { item -> TVTopShelfSectionedItem? in
            guard let displayURL = URL(string: "moviepilot://media?id=\(item.id)&source=\(item.source)") else {
                print("❌ [TopShelf] 无效的 URL: \(item.id)")
                return nil
            }
            
            let contentItem = TVTopShelfSectionedItem(identifier: "media-\(item.id)")
            contentItem.title = item.title
            contentItem.displayAction = TVTopShelfAction(url: displayURL)
            
            // 设置海报图片
            if let posterURLString = item.posterURL,
               let posterURL = URL(string: posterURLString) {
                contentItem.setImageURL(posterURL, for: .screenScale1x)
                contentItem.setImageURL(posterURL, for: .screenScale2x)
                print("✅ [TopShelf] 设置图片: \(item.title) - \(posterURLString.prefix(50))...")
            }
            
            return contentItem
        }
        
        print("✅ [TopShelf] 创建了 \(contentItems.count) 个 Content Items")
        
        let section = TVTopShelfItemCollection(items: contentItems)
        section.title = "推荐影片"
        
        let content = TVTopShelfSectionedContent(sections: [section])
        return content
    }
}

// MARK: - 共享数据模型
struct TopShelfMediaItem: Codable {
    let id: String
    let title: String
    let posterURL: String?
    let source: String
    let tmdbId: Int?
    let doubanId: String?
}
