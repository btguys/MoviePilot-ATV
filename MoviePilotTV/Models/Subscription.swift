//
//  Subscription.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

struct Subscription: Codable, Identifiable, Equatable {
    let id: Int?
    let name: String
    let year: String?
    let type: String // "电影" or "电视剧"
    let tmdbid: Int?
    let doubanid: String?
    let season: Int?
    let poster: String?
    let backdrop: String?
    let description: String?
    let vote: Double?
    let state: String? // "N", "R", "D" (未开始、订阅中、完成)
    let lastUpdate: String?
    let totalEpisode: Int?
    let lackEpisode: Int?
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case year
        case type
        case tmdbid
        case doubanid
        case season
        case poster
        case backdrop
        case description
        case vote
        case state
        case lastUpdate = "last_update"
        case totalEpisode = "total_episode"
        case lackEpisode = "lack_episode"
        case username
    }
    
    var posterURL: URL? {
        guard let poster = poster else { return nil }
        return URL(string: poster)
    }
    
    var backdropURL: URL? {
        guard let backdrop = backdrop else { return nil }
        return URL(string: backdrop)
    }
    
    var isMovie: Bool {
        type == "电影"
    }
    
    var isTV: Bool {
        type == "电视剧"
    }
    
    var displayTitle: String {
        var title = name
        if let year = year {
            title += " (\(year))"
        }
        if isTV, let season = season {
            title += " S\(String(format: "%02d", season))"
        }
        return title
    }
    
    // 已下载集数 = 总集数 - 缺少集数
    var downloadedEpisode: Int? {
        guard let total = totalEpisode, let lack = lackEpisode else {
            return nil
        }
        return total - lack
    }
    
    var progressText: String? {
        guard let total = totalEpisode, let downloaded = downloadedEpisode else {
            return nil
        }
        return "\(downloaded)/\(total)"
    }
    
    var stateText: String {
        switch state {
        case "N":
            return "未开始"
        case "R":
            return "订阅中"
        case "D":
            return "已完成"
        default:
            return "未知"
        }
    }
}
