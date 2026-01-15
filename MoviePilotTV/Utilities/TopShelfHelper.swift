//
//  TopShelfHelper.swift
//  MoviePilotTV
//
//  Created on 2026-01-15.
//

import Foundation

class TopShelfHelper {
    static let shared = TopShelfHelper()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.moviepilot.tv")
    
    private init() {}
    
    /// 更新 Top Shelf 推荐内容
    func updateTopShelfRecommendations(_ items: [MediaItem]) {
        print("🔝 [TopShelfHelper] 更新 Top Shelf 推荐，共 \(items.count) 项")
        
        let topShelfItems = items.prefix(10).map { item -> TopShelfMediaItem in
            // 确定来源
            let source: String
            if let itemSource = item.source?.lowercased() {
                if itemSource.contains("tmdb") {
                    source = "tmdb"
                } else if itemSource.contains("douban") {
                    source = "douban"
                } else {
                    source = itemSource
                }
            } else if item.tmdbId != nil {
                source = "tmdb"
            } else if item.doubanId != nil {
                source = "douban"
            } else {
                source = "unknown"
            }
            
            // 生成唯一 ID
            let id: String
            if let tmdbId = item.tmdbId {
                id = "tmdb_\(tmdbId)"
            } else if let doubanId = item.doubanId {
                id = "douban_\(doubanId)"
            } else {
                id = "title_\(item.title.hashValue)"
            }
            
            return TopShelfMediaItem(
                id: id,
                title: item.title,
                posterURL: item.posterURL?.absoluteString,
                source: source,
                tmdbId: item.tmdbId,
                doubanId: item.doubanId
            )
        }
        
        do {
            let data = try JSONEncoder().encode(topShelfItems)
            sharedDefaults?.set(data, forKey: "topShelfRecommendations")
            print("✅ [TopShelfHelper] Top Shelf 数据已保存")
            
            // 通知系统刷新 Top Shelf
            NotificationCenter.default.post(name: NSNotification.Name("TVTopShelfItemsDidChange"), object: nil)
        } catch {
            print("❌ [TopShelfHelper] 保存失败: \(error)")
        }
    }
    
    /// 更新登录状态到共享容器
    func updateAuthenticationState(token: String?, endpoint: String?) {
        if let token = token {
            sharedDefaults?.set(token, forKey: "accessToken")
            print("✅ [TopShelfHelper] Token 已保存到共享容器")
        } else {
            sharedDefaults?.removeObject(forKey: "accessToken")
            print("🗑️ [TopShelfHelper] Token 已从共享容器移除")
        }
        
        if let endpoint = endpoint {
            sharedDefaults?.set(endpoint, forKey: "apiEndpoint")
        }
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
