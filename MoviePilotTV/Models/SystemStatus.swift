//
//  SystemStatus.swift
//  MoviePilotTV
//
//  Created on 2026-01-02.
//

import Foundation

// 存储空间信息
struct StorageInfo: Codable {
    let totalStorage: Double      // 总存储空间（字节）
    let usedStorage: Double       // 已用存储空间（字节）
    
    enum CodingKeys: String, CodingKey {
        case totalStorage = "total_storage"
        case usedStorage = "used_storage"
    }
    
    // 计算已用百分比
    var usagePercentage: Double {
        guard totalStorage > 0 else { return 0 }
        return (usedStorage / totalStorage) * 100
    }
    
    // 格式化显示的已用空间
    var usedStorageText: String {
        return formatBytes(usedStorage)
    }
    
    // 格式化显示的总空间
    var totalStorageText: String {
        return formatBytes(totalStorage)
    }
    
    // 剩余空间
    var freeStorage: Double {
        return totalStorage - usedStorage
    }
    
    var freeStorageText: String {
        return formatBytes(freeStorage)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = bytes
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

// 下载器速度和统计信息
struct DownloaderInfo: Codable {
    let downloadSpeed: Double      // 实时下载速度（字节/秒）
    let uploadSpeed: Double        // 实时上传速度（字节/秒）
    let downloadSize: Double       // 总下载大小（字节）
    let uploadSize: Double         // 总上传大小（字节）
    let freeSpace: Double          // 磁盘剩余空间（字节）
    
    enum CodingKeys: String, CodingKey {
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case downloadSize = "download_size"
        case uploadSize = "upload_size"
        case freeSpace = "free_space"
    }
    
    // 格式化下载速度
    var downloadSpeedText: String {
        return formatSpeed(downloadSpeed)
    }
    
    // 格式化上传速度
    var uploadSpeedText: String {
        return formatSpeed(uploadSpeed)
    }
    
    // 格式化总下载大小
    var downloadSizeText: String {
        return formatBytes(downloadSize)
    }
    
    // 格式化总上传大小
    var uploadSizeText: String {
        return formatBytes(uploadSize)
    }
    
    // 格式化剩余空间
    var freeSpaceText: String {
        return formatBytes(freeSpace)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = bytes
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = bytesPerSecond
        var unitIndex = 0
        
        while speed >= 1024 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", speed, units[unitIndex])
    }
}

// 系统状态（存储 + 下载信息）
struct SystemStatus: Codable {
    let storageInfo: StorageInfo?
    let downloaderInfo: DownloaderInfo?
    let lastUpdated: Date
}
