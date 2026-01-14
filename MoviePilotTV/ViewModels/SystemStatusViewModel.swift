//
//  SystemStatusViewModel.swift
//  MoviePilotTV
//
//  Created on 2026-01-02.
//

import Foundation

class SystemStatusViewModel: NSObject, ObservableObject {
    @Published var systemStatus: SystemStatus?
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService = APIService.shared
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 5.0  // 每 5 秒更新一次
    private var hasInitializedStorage = false  // 标记存储空间是否已初始化
    
    override init() {
        super.init()
    }
    
    // 开始定时更新
    func startUpdating() {
        // 避免重复启动多个定时器
        guard updateTimer == nil else { return }
        
        // 立即获取一次（包括存储空间）
        Task {
            await fetchSystemStatus(includeStorage: true)
        }
        
        // 设置定时器每 5 秒更新一次（仅更新下载速度）
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchSystemStatus(includeStorage: false)
            }
        }
    }
    
    // 停止定时更新
    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // 获取系统状态
    @MainActor
    private func fetchSystemStatus(includeStorage: Bool) async {
        isLoading = true
        defer { isLoading = false }
        
        let requestTimestamp = Date()
        print("⏱️  [SystemStatusVM] 开始获取系统状态 (时间: \(ISO8601DateFormatter().string(from: requestTimestamp)))")
        
        do {
            var storageInfo: StorageInfo?
            var downloaderInfo: DownloaderInfo?
            
            // 只在第一次或需要时获取存储信息
            if includeStorage {
                storageInfo = try await apiService.fetchStorageInfo()
            } else {
                // 使用缓存的存储信息
                storageInfo = systemStatus?.storageInfo
            }
            
            // 总是获取下载器信息
            downloaderInfo = try await apiService.fetchDownloaderInfo()
            
            // 检查是否和上一次相同
            let isSameAsLast = systemStatus?.downloaderInfo?.uploadSpeed == downloaderInfo?.uploadSpeed
                && systemStatus?.downloaderInfo?.downloadSpeed == downloaderInfo?.downloadSpeed
            
            systemStatus = SystemStatus(
                storageInfo: storageInfo,
                downloaderInfo: downloaderInfo,
                lastUpdated: Date()
            )
            
            error = nil
            print("🔵 [SystemStatusVM] 系统状态更新成功\(includeStorage ? " (含存储信息)" : " (仅下载信息)")")
            if let downloader = downloaderInfo {
                print("   ⬇️ 下载速度: \(downloader.downloadSpeed) B/s → \(downloader.downloadSpeedText)")
                print("   ⬆️ 上传速度: \(downloader.uploadSpeed) B/s → \(downloader.uploadSpeedText)")
                print("   📊 与上次相同: \(isSameAsLast)")
            }
        } catch {
            print("❌ [SystemStatusVM] 获取系统状态失败: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    deinit {
        stopUpdating()
    }
}

