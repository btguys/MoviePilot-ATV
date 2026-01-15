//
//  MediaItem.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

struct MediaItem: Codable, Identifiable, Equatable, Hashable {
    let tmdbId: Int?
    let imdbId: String?
    let doubanId: String?
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let type: String? // "电影" or "电视剧"
    let year: String?
    let originalLanguage: String?
    let source: String?
    
    // 生成唯一ID: 优先使用tmdbId, 其次imdbId, 再次doubanId, 最后用title的hash
    var id: Int {
        if let tmdbId = tmdbId {
            return tmdbId
        } else if let imdbId = imdbId {
            return imdbId.hashValue
        } else if let doubanId = doubanId {
            return doubanId.hashValue
        } else {
            return title.hashValue
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case imdbId = "imdb_id"
        case doubanId = "douban_id"
        case title
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case type
        case year
        case originalLanguage = "original_language"
        case source
    }
    
    var posterURL: URL? {
        guard let posterPath = posterPath, !posterPath.isEmpty else { return nil }
        // API 已经返回完整的 URL
        let rawURL: String
        if posterPath.hasPrefix("http") {
            rawURL = posterPath
        } else {
            rawURL = "https://image.tmdb.org/t/p/w500\(posterPath)"
        }
        return URL(string: applyImageProxyIfNeeded(rawURL))
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath, !backdropPath.isEmpty else { return nil }
        // API 已经返回完整的 URL
        let rawURL: String
        if backdropPath.hasPrefix("http") {
            rawURL = backdropPath
        } else {
            rawURL = "https://image.tmdb.org/t/p/original\(backdropPath)"
        }
        return URL(string: applyImageProxyIfNeeded(rawURL))
    }
    
    var displayTitle: String {
        if let year = year {
            return "\(title) (\(year))"
        }
        return title
    }
    
    var ratingText: String {
        guard let rating = voteAverage else { return "N/A" }
        return String(format: "%.1f", rating)
    }
    
    var mediaType: String? {
        guard let type = type else { return nil }
        if type == "电影" {
            return "movie"
        } else if type == "电视剧" {
            return "tv"
        }
        return type
    }
    
    // Convert from Subscription
    static func from(_ subscription: Subscription) -> MediaItem {
        return MediaItem(
            tmdbId: subscription.tmdbid,
            imdbId: nil,
            doubanId: subscription.doubanid,
            title: subscription.name,
            originalTitle: nil,
            overview: subscription.description,
            posterPath: subscription.poster,
            backdropPath: subscription.backdrop,
            voteAverage: subscription.vote,
            releaseDate: nil,
            type: subscription.type,
            year: subscription.year,
            originalLanguage: nil,
            source: nil
        )
    }

    private func applyImageProxyIfNeeded(_ urlString: String) -> String {
        let lower = urlString.lowercased()
        let isDouban = (source?.lowercased().contains("douban") ?? false) || lower.contains("doubanio.com")
        guard isDouban else { return urlString }
        let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        let base = UserDefaults.standard.string(forKey: "apiEndpoint")?.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) ?? ""
        guard !base.isEmpty else { return urlString }
        return "\(base)/api/v1/system/img/0?imgurl=\(encoded)"
    }
}
