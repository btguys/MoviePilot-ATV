//
//  TopShelfHelper.swift
//  MoviePilotTV
//
//  Created on 2026-01-15.
//

import Foundation

class TopShelfHelper {
    static let shared = TopShelfHelper()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.hvg.moviepilot-atv")
    
    private init() {}
    
    /// 更新 Top Shelf 推荐内容
    func updateTopShelfRecommendations(_ items: [MediaItem]) {
        print("🔝 [TopShelfHelper] ========== 开始更新 Top Shelf ==========")
        print("🔝 [TopShelfHelper] 输入项目数: \(items.count)")
        
        // 验证 App Group 配置
        if sharedDefaults == nil {
            print("❌ [TopShelfHelper] CRITICAL: App Group UserDefaults 未配置!")
            print("❌ [TopShelfHelper] 请检查 Xcode 中的 App Groups 设置")
            return
        } else {
            print("✅ [TopShelfHelper] App Group 已配置")
        }
        
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
                type: item.type,
                tmdbId: item.tmdbId,
                doubanId: item.doubanId
            )
        }
        
        do {
            let data = try JSONEncoder().encode(topShelfItems)
            sharedDefaults?.set(data, forKey: "topShelfRecommendations")
            sharedDefaults?.synchronize()
            
            print("✅ [TopShelfHelper] Top Shelf 数据已保存")
            print("   数据大小: \(data.count) bytes")
            print("   保存项目数: \(topShelfItems.count)")
            
            // 立即验证数据
            if let savedData = sharedDefaults?.data(forKey: "topShelfRecommendations"),
               let decoded = try? JSONDecoder().decode([TopShelfMediaItem].self, from: savedData) {
                print("✅ [TopShelfHelper] 验证成功: 读取到 \(decoded.count) 项")
                print("   前3项标题: \(decoded.prefix(3).map { $0.title })")
            } else {
                print("❌ [TopShelfHelper] 验证失败: 无法读回数据!")
            }
            
            print("📝 [TopShelfHelper] 注意: tvOS 系统将在适当的时候自动刷新 Top Shelf")
            print("🔝 [TopShelfHelper] ========== 更新完成 ==========")
        } catch {
            print("❌ [TopShelfHelper] 保存失败: \(error)")
        }
    }
    
    /// 更新登录状态到共享容器
    func updateAuthenticationState(token: String?, endpoint: String?) {
        print("🔐 [TopShelfHelper] ========== 更新认证状态 ==========")
        if let token = token {
            sharedDefaults?.set(token, forKey: "accessToken")
            print("✅ [TopShelfHelper] Token 已保存到共享容器 (前20字符: \(token.prefix(20)))")
        } else {
            sharedDefaults?.removeObject(forKey: "accessToken")
            print("🗑️ [TopShelfHelper] Token 已从共享容器移除")
        }
        
        if let endpoint = endpoint {
            sharedDefaults?.set(endpoint, forKey: "apiEndpoint")
            print("✅ [TopShelfHelper] API Endpoint 已保存: \(endpoint)")
        }
        
        sharedDefaults?.synchronize()
        print("🔐 [TopShelfHelper] ========== 认证状态更新完成 ==========")
    }
    
    /// 调试方法：打印当前 App Group 中的所有数据
    func debugPrintSharedData() {
        print("🔍 [TopShelfHelper] ========== App Group 数据调试 ==========")
        
        guard let sharedDefaults = sharedDefaults else {
            print("❌ [TopShelfHelper] App Group 未配置")
            return
        }
        
        let allKeys = sharedDefaults.dictionaryRepresentation().keys.sorted()
        print("📋 [TopShelfHelper] 所有 keys: \(allKeys)")
        
        if let token = sharedDefaults.string(forKey: "accessToken") {
            print("🔑 accessToken: \(token.prefix(30))...")
        } else {
            print("⚠️ accessToken: <不存在>")
        }
        
        if let endpoint = sharedDefaults.string(forKey: "apiEndpoint") {
            print("🌐 apiEndpoint: \(endpoint)")
        } else {
            print("⚠️ apiEndpoint: <不存在>")
        }
        
        if let data = sharedDefaults.data(forKey: "topShelfRecommendations") {
            print("📦 topShelfRecommendations: \(data.count) bytes")
            if let items = try? JSONDecoder().decode([TopShelfMediaItem].self, from: data) {
                print("   包含 \(items.count) 个项目")
                items.prefix(3).forEach { item in
                    print("   - \(item.title) (id: \(item.id))")
                }
            }
        } else {
            print("⚠️ topShelfRecommendations: <不存在>")
        }
        
        print("🔍 [TopShelfHelper] ========== 调试结束 ==========")
    }
}

// MARK: - 共享数据模型
struct TopShelfMediaItem: Codable {
    let id: String
    let title: String
    let posterURL: String?
    let source: String
    let type: String?
    let tmdbId: Int?
    let doubanId: String?
}
