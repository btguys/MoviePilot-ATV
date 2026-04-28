//
//  DownloadsView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedDownloadTask: DownloadTask?
    @State private var showTaskActionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                Text("下载管理")
                    .font(FontTokens.pageTitle)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("共 \(totalTaskCount) 个任务")
                    .font(FontTokens.caption)
                    .foregroundColor(ColorTokens.textMuted)
                
                Spacer()
            }
            .padding(.horizontal, 55)
            .padding(.vertical, 30)
            
            Divider()
                .background(ColorTokens.divider)
            
            // Content
            if viewModel.isLoading {
                LoadingView("正在加载下载器...")
            } else if viewModel.downloaderSections.isEmpty {
                EmptyStateView(icon: "arrow.down.circle", title: "暂无下载器")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(viewModel.downloaderSections) { section in
                            DownloaderSectionView(
                                section: section,
                                onTaskTapped: { task in
                                    selectedDownloadTask = task
                                    showTaskActionSheet = true
                                }
                            )
                        }
                        
                        // Bottom spacing
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 55)
                    .padding(.top, 30)
                }
            }
        }
        .background(ColorTokens.appBackground)
        .onAppear {
            viewModel.loadDownloaders()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("提示", isPresented: $viewModel.showSuccessMessage) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage)
        }
        .confirmationDialog(
            "下载任务操作",
            isPresented: $showTaskActionSheet,
            titleVisibility: .visible,
            presenting: selectedDownloadTask
        ) { task in
            Button(task.isPaused ? "继续下载" : "暂停下载") {
                viewModel.toggleTaskPause(task: task)
            }
            Button("删除", role: .destructive) {
                viewModel.deleteTask(task: task)
            }
            Button("取消", role: .cancel) { }
        } message: { task in
            Text("\(task.displayTitle)\n进度: \(String(format: "%.1f", task.displayProgress))%")
        }
    }
    
    private var totalTaskCount: Int {
        viewModel.downloaderSections.reduce(0) { $0 + $1.tasks.count }
    }
}

// MARK: - Downloader Section View

struct DownloaderSectionView: View {
    let section: DownloaderSection
    let onTaskTapped: (DownloadTask) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ColorTokens.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.client.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    Text("\(section.tasks.count) 个任务 • \(section.client.type)")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.textMuted)
                }
                
                Spacer()
            }
            .padding(.leading, 12)
            
            if section.tasks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(ColorTokens.textMuted)
                    Text("暂无任务")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTokens.textMuted)
                        .padding(.top, 10)
                    Spacer()
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(ColorTokens.surfaceCard.opacity(0.6))
                .cornerRadius(12)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(section.tasks) { task in
                        DownloadTaskCard(
                            task: task,
                            onTap: { onTaskTapped(task) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Download Task Card

struct DownloadTaskCard: View {
    let task: DownloadTask
    let onTap: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // Title & State
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: 12) {
                            StateIndicator(state: task.state)
                            
                            Text(task.displayState)
                                .font(.system(size: 12))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                    
                    Spacer()
                    
                    // Progress Percentage
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.1f%%", task.displayProgress))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ColorTokens.accent)
                        
                        Text(task.displaySize)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.progressTrack)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .cyan]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(min(task.displayProgress / 100, 1.0)))
                    }
                }
                .frame(height: 6)
                
                // Speed Info
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11))
                        Text(task.dlspeed ?? "0.0B")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ColorTokens.textMuted)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11))
                        Text(task.upspeed ?? "0.0B")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ColorTokens.textMuted)
                    
                    if !task.left_time.isNilOrEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(task.left_time ?? "-")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ColorTokens.textMuted)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(ColorTokens.surfaceCard)
            .cornerRadius(12)
            .contentShape(Rectangle())
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? Color.blue.opacity(0.6) : Color.clear, radius: 12, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 3)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
    }
}

// MARK: - State Indicator

struct StateIndicator: View {
    let state: String?
    
    var color: Color {
        switch state?.lowercased() {
        case "paused":
            return ColorTokens.warning
        case "downloading":
            return ColorTokens.accent
        case "completed":
            return ColorTokens.success
        case "error":
            return ColorTokens.danger
        case "seeding":
            return ColorTokens.info
        default:
            return ColorTokens.textMuted
        }
    }
    
    var icon: String {
        switch state?.lowercased() {
        case "paused":
            return "pause.circle.fill"
        case "downloading":
            return "arrow.down.circle.fill"
        case "completed":
            return "checkmark.circle.fill"
        case "error":
            return "exclamationmark.circle.fill"
        case "seeding":
            return "arrow.up.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundColor(color)
    }
}

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView()
    }
}
