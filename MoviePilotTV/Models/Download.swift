//
//  Download.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

struct Download: Codable, Identifiable {
    let id: Int
    let title: String
    let year: Int?
    let type: String
    let tmdbId: Int?
    let season: Int?
    let episode: Int?
    let image: String?
    let download: Double? // 下载进度 0-100
    let state: String? // "downloading", "completed", "error"
    let leftTime: String?
    let speed: String?
    let size: String?
    let path: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case year
        case type
        case tmdbId = "tmdb_id"
        case season
        case episode
        case image
        case download
        case state
        case leftTime = "left_time"
        case speed
        case size
        case path
    }
    
    var posterURL: URL? {
        guard let image = image else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(image)")
    }
    
    var displayTitle: String {
        var title = self.title
        if let year = year {
            title += " (\(year))"
        }
        if let season = season {
            title += " S\(String(format: "%02d", season))"
        }
        if let episode = episode {
            title += "E\(String(format: "%02d", episode))"
        }
        return title
    }
    
    var progressPercent: Double {
        download ?? 0
    }
    
    var stateText: String {
        switch state {
        case "downloading":
            return "下载中"
        case "completed":
            return "已完成"
        case "error":
            return "错误"
        default:
            return "未知"
        }
    }
}

struct DownloadHistory: Codable, Identifiable {
    let id: Int
    let title: String
    let type: String
    let year: Int?
    let tmdbId: Int?
    let season: Int?
    let episode: Int?
    let image: String?
    let downloadTime: String?
    let path: String?
    let size: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case year
        case tmdbId = "tmdb_id"
        case season
        case episode
        case image
        case downloadTime = "download_time"
        case path
        case size
    }
    
    var posterURL: URL? {
        guard let image = image else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(image)")
    }
    
    var displayTitle: String {
        var title = self.title
        if let year = year {
            title += " (\(year))"
        }
        if let season = season {
            title += " S\(String(format: "%02d", season))"
        }
        if let episode = episode {
            title += "E\(String(format: "%02d", episode))"
        }
        return title
    }
}
