//
//  Downloader.swift
//  MoviePilotTV
//
//  Created on 2026-01-02.
//

import Foundation

// MARK: - Downloader Client

struct DownloaderClient: Codable, Identifiable {
    let name: String
    let type: String
    
    var id: String { name }
}

// MARK: - Download Task

struct DownloadTask: Codable, Identifiable, Equatable {
    let downloader: String
    let hash: String
    let title: String
    let name: String
    let year: String?
    let season_episode: String?
    let size: Double?
    let progress: Double?
    let state: String?
    let upspeed: String?
    let dlspeed: String?
    let media: TaskMediaInfo?
    let userid: Int?
    let username: String?
    let left_time: String?
    
    enum CodingKeys: String, CodingKey {
        case downloader, hash, title, name, year
        case season_episode
        case size, progress, state, upspeed, dlspeed
        case media, userid, username
        case left_time
    }
    
    var id: String { hash }
    
    var displayTitle: String {
        if !season_episode.isNilOrEmpty {
            return "\(name) \(season_episode ?? "")"
        }
        return name
    }
    
    var displaySize: String {
        guard let size = size else { return "未知" }
        return formatBytes(size)
    }
    
    var displayProgress: Double {
        return progress ?? 0
    }
    
    var displayState: String {
        switch state?.lowercased() {
        case "paused":
            return "已暂停"
        case "downloading":
            return "下载中"
        case "completed":
            return "已完成"
        case "error":
            return "错误"
        case "seeding":
            return "做种中"
        default:
            return state ?? "未知"
        }
    }
    
    var isPaused: Bool {
        state?.lowercased() == "paused"
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Task Media Info

struct TaskMediaInfo: Codable, Equatable {
    let tmdbid: Int?
    let type: String?
    let title: String?
    let season: String?
    let episode: String?
    let image: String?
}

// MARK: - Downloader Section

struct DownloaderSection: Identifiable {
    let client: DownloaderClient
    let tasks: [DownloadTask]
    
    var id: String { client.id }
}

// Extension for nil or empty check
extension String? {
    var isNilOrEmpty: Bool {
        self == nil || (self?.isEmpty ?? true)
    }
}
