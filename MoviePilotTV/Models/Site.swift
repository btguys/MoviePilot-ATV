//
//  Site.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

// 站点流量数据
struct SiteUserData: Codable {
    let domain: String
    let username: String?
    let userid: Int?
    let userLevel: String?
    let joinAt: String?
    let bonus: Double
    let upload: Int64
    let download: Int64
    let ratio: Double
    let seeding: Int
    let leeching: Int
    let seedingSize: Int64?
    let leechingSize: Int64?
    
    enum CodingKeys: String, CodingKey {
        case domain
        case username
        case userid
        case userLevel = "user_level"
        case joinAt = "join_at"
        case bonus
        case upload
        case download
        case ratio
        case seeding
        case leeching
        case seedingSize = "seeding_size"
        case leechingSize = "leeching_size"
    }
    
    // 格式化流量显示
    func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.2f %@", size, units[unitIndex])
    }
    
    var uploadText: String {
        formatBytes(upload)
    }
    
    var downloadText: String {
        formatBytes(download)
    }
}

struct Site: Codable, Identifiable {
    let id: Int
    let name: String
    let domain: String
    let url: String
    let pri: Int
    let rss: String?
    let cookie: String?
    let ua: String?
    let apikey: String?
    let token: String?
    let proxy: Int?
    let filter: String?
    let render: Int?
    let isPublic: Int
    let note: String?
    let timeout: Int
    let limitInterval: Int
    let limitCount: Int
    let limitSeconds: Int
    let isActive: Bool
    let downloader: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domain
        case url
        case pri
        case rss
        case cookie
        case ua
        case apikey
        case token
        case proxy
        case filter
        case render
        case isPublic = "public"
        case note
        case timeout
        case limitInterval = "limit_interval"
        case limitCount = "limit_count"
        case limitSeconds = "limit_seconds"
        case isActive = "is_active"
        case downloader
    }
    
    var statusText: String {
        isActive ? "已启用" : "已禁用"
    }
    
    var typeText: String {
        isPublic == 1 ? "公开站点" : "私有站点"
    }
    
    var enabled: Bool {
        isActive
    }
}
