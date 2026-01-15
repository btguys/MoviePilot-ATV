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
        print("🔗 [DeepLink] 收到 URL: \(url)")
        
        guard url.scheme == "moviepilot",
              url.host == "media" else {
            print("⚠️ [DeepLink] 无效的 scheme 或 host")
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
            print("⚠️ [DeepLink] 缺少必要参数")
            return
        }
        
        print("✅ [DeepLink] 解析成功: id=\(mediaId), source=\(source)")
        
        // 从缓存或 API 获取媒体信息
        Task {
            do {
                // 尝试从 Top Shelf 缓存中查找
                if let cachedItem = findCachedMediaItem(id: mediaId) {
                    await MainActor.run {
                        deepLinkMedia = cachedItem
                    }
                    print("✅ [DeepLink] 从缓存加载媒体")
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
    }
    
    private func findCachedMediaItem(id: String) -> MediaItem? {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.moviepilot.tv"),
              let data = sharedDefaults.data(forKey: "topShelfRecommendations"),
              let items = try? JSONDecoder().decode([TopShelfMediaItem].self, from: data) else {
            return nil
        }
        
        guard let topShelfItem = items.first(where: { $0.id == id }) else {
            return nil
        }
        
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
            type: nil,
            year: nil,
            originalLanguage: nil,
            source: topShelfItem.source
        )
    }
}
