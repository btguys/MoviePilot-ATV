//
//  DownloadsViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation
import Combine

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published var downloaderSections: [DownloaderSection] = []
    @Published var downloadHistory: [DownloadHistory] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccessMessage = false
    @Published var successMessage = ""
    
    private let apiService = APIService.shared
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 3.0 // 每3秒轮询一次
    
    func loadDownloaders() {
        isLoading = true
        
        Task { @MainActor in
            do {
                // 获取下载器列表
                let clients = try await apiService.getDownloaderClients()
                print("✅ [DownloadsViewModel] 获取到 \(clients.count) 个下载器")
                
                // 为每个下载器获取任务列表
                var sections: [DownloaderSection] = []
                
                for client in clients {
                    do {
                        let tasks = try await apiService.getDownloadTasks(downloaderName: client.name)
                        print("✅ [DownloadsViewModel] 下载器 \(client.name) 有 \(tasks.count) 个任务")
                        
                        // 调试：打印每个任务的详细信息
                        for task in tasks {
                            print("📦 [DownloadsViewModel] 任务: \(task.name)")
                            print("   - 状态: \(task.state ?? "nil") -> \(task.displayState)")
                            print("   - 进度: \(task.progress ?? 0)%")
                            print("   - 下载速度: \(task.dlspeed ?? "nil")")
                            print("   - 上传速度: \(task.upspeed ?? "nil")")
                            print("   - 剩余时间: \(task.left_time ?? "nil")")
                        }
                        
                        sections.append(DownloaderSection(client: client, tasks: tasks))
                    } catch {
                        print("❌ [DownloadsViewModel] 获取下载器 \(client.name) 任务失败: \(error)")
                        // 即使某个下载器失败，仍然继续
                        sections.append(DownloaderSection(client: client, tasks: []))
                    }
                }
                
                self.downloaderSections = sections
                
            } catch {
                errorMessage = "加载下载器信息失败: \(error.localizedDescription)"
                showError = true
            }
            
            isLoading = false
        }
    }
    
    /// 暂停/继续任务（具体功能待实现）
    func toggleTaskPause(task: DownloadTask) {
        print("📌 [DownloadsViewModel] 切换任务状态: \(task.displayTitle)")
        isLoading = true
        Task { @MainActor in
            do {
                try await apiService.stopDownloadTask(downloaderName: task.downloader, taskHash: task.hash)
                await refreshDownloadTasks()
                successMessage = "已提交暂停/停止请求"
                showSuccessMessage = true
            } catch {
                errorMessage = "暂停任务失败: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }
    
    /// 删除任务（具体功能待实现）
    func deleteTask(task: DownloadTask) {
        print("🗑️ [DownloadsViewModel] 删除任务: \(task.displayTitle)")
        isLoading = true
        Task { @MainActor in
            do {
                try await apiService.deleteDownloadTask(downloaderName: task.downloader, taskHash: task.hash)
                await refreshDownloadTasks()
                successMessage = "任务已删除"
                showSuccessMessage = true
            } catch {
                errorMessage = "删除任务失败: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }
    
    // MARK: - Polling
    
    /// 开始轮询下载任务
    func startPolling() {
        stopPolling() // 确保没有重复的定时器
        
        print("🔄 [DownloadsViewModel] 开始轮询下载任务，间隔 \(pollingInterval) 秒")
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshDownloadTasks()
            }
        }
    }
    
    /// 停止轮询
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("⏸️ [DownloadsViewModel] 停止轮询下载任务")
    }
    
    /// 刷新下载任务（不重新获取下载器列表）
    private func refreshDownloadTasks() async {
        guard !downloaderSections.isEmpty else { return }
        
        var updatedSections: [DownloaderSection] = []
        
        for section in downloaderSections {
            do {
                let tasks = try await apiService.getDownloadTasks(downloaderName: section.client.name)
                
                // 调试轮询数据
                for task in tasks {
                    print("🔄 [Poll] \(task.name) - 状态:\(task.state ?? "nil") 下载:\(task.dlspeed ?? "nil") 上传:\(task.upspeed ?? "nil")")
                }
                
                updatedSections.append(DownloaderSection(client: section.client, tasks: tasks))
                print("🔄 [DownloadsViewModel] 刷新下载器 \(section.client.name)：\(tasks.count) 个任务")
            } catch {
                print("❌ [DownloadsViewModel] 刷新下载器 \(section.client.name) 失败: \(error)")
                // 保留旧数据
                updatedSections.append(section)
            }
        }
        
        self.downloaderSections = updatedSections
    }
}

