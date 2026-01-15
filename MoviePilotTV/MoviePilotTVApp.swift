//
//  MoviePilotTVApp.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

@main
struct MoviePilotTVApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var deepLinkMedia: MediaItem?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainView(deepLinkMedia: $deepLinkMedia)
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 [DeepLink] ========== 收到深链接 ==========")
        print("🔗 [DeepLink] 完整 URL: \(url.absoluteString)")
        print("🔗 [DeepLink] Scheme: \(url.scheme ?? "<none>")")
        print("🔗 [DeepLink] Host: \(url.host ?? "<none>")")
        print("🔗 [DeepLink] Path: \(url.path)")
        
        guard url.scheme == "moviepilot",
              url.host == "media" else {
            print("⚠️ [DeepLink] 无效的 scheme 或 host")
            print("⚠️ [DeepLink] 期望: moviepilot://media, 实际: \(url.scheme ?? "nil")://\(url.host ?? "nil")")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("⚠️ [DeepLink] 无法解析 query items")
            return
        }
        
        var mediaId: String?
        var source: String?
        var tmdbId: Int?
        var doubanId: String?
        
        for item in queryItems {
            switch item.name {
            case "id":
                mediaId = item.value
            case "source":
                source = item.value
            case "tmdbId":
                if let value = item.value, let id = Int(value) {
                    tmdbId = id
                }
            case "doubanId":
                doubanId = item.value
            default:
                break
            }
        }
        
        guard let mediaId = mediaId, let source = source else {
            print("⚠️ [DeepLink] 缺少必要参数: id=\(mediaId ?? "nil"), source=\(source ?? "nil")")
            return
        }
        
        print("✅ [DeepLink] 解析成功: id=\(mediaId), source=\(source)")
        
        // 从缓存或 API 获取媒体信息
        Task {
            print("🔍 [DeepLink] 开始查找媒体数据...")
            
            // 尝试从 Top Shelf 缓存中查找
            if let cachedItem = findCachedMediaItem(id: mediaId) {
                print("✅ [DeepLink] 从缓存找到媒体: \(cachedItem.title)")
                await MainActor.run {
                    print("🎯 [DeepLink] 设置 deepLinkMedia，触发导航")
                    deepLinkMedia = cachedItem
                }
                print("✅ [DeepLink] deepLinkMedia 已设置")
            } else {
                // 创建占位媒体项
                let placeholder = MediaItem(
                    tmdbId: tmdbId,
                    imdbId: nil,
                    doubanId: doubanId,
                    title: "加载中...",
                    originalTitle: nil,
                    overview: nil,
                    posterPath: nil,
                    backdropPath: nil,
                    voteAverage: nil,
                    releaseDate: nil,
                    type: nil,
                    year: nil,
                    originalLanguage: nil,
                    source: source
                )
                await MainActor.run {
                    deepLinkMedia = placeholder
                }
                print("✅ [DeepLink] 创建占位媒体项")
            }
        }
    }
    
    private func findCachedMediaItem(id: String) -> MediaItem? {
        print("🔍 [DeepLink] 查找缓存媒体，ID: \(id)")
        
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.hvg.moviepilot-atv") else {
            print("❌ [DeepLink] 无法访问 App Group")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: "topShelfRecommendations") else {
            print("❌ [DeepLink] topShelfRecommendations 数据不存在")
            return nil
        }
        
        guard let items = try? JSONDecoder().decode([TopShelfMediaItem].self, from: data) else {
            print("❌ [DeepLink] 解码失败")
            return nil
        }
        
        print("📋 [DeepLink] 缓存中有 \(items.count) 个项目")
        print("📋 [DeepLink] 缓存 IDs: \(items.map { $0.id })")
        
        guard let topShelfItem = items.first(where: { $0.id == id }) else {
            print("❌ [DeepLink] 未找到匹配的媒体项")
            return nil
        }
        
        print("✅ [DeepLink] 找到媒体: \(topShelfItem.title)")
        
        return MediaItem(
            tmdbId: topShelfItem.tmdbId,
            imdbId: nil,
            doubanId: topShelfItem.doubanId,
            title: topShelfItem.title,
            originalTitle: nil,
            overview: nil,
            posterPath: topShelfItem.posterURL,
            backdropPath: nil,
            voteAverage: nil,
            releaseDate: nil,
            type: topShelfItem.type,
            year: nil,
            originalLanguage: nil,
            source: topShelfItem.source
        )
    }
}
