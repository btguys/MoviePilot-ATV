//
//  SystemStatusCard.swift
//  MoviePilotTV
//
//  Created on 2026-01-02.
//

import SwiftUI

struct SystemStatusCard: View {
    @ObservedObject var viewModel: SystemStatusViewModel
    
    var body: some View {
        if let status = viewModel.systemStatus {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 18, weight: .semibold))
                    Text("系统状态")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    // 更新时间指示器
                    Image(systemName: viewModel.isLoading ? "arrow.2.circlepath" : "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.success)
                        .scaleEffect(viewModel.isLoading ? 1.1 : 1.0)
                        .opacity(viewModel.isLoading ? 1.0 : 0.9)
                        .animation(viewModel.isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
                .foregroundColor(ColorTokens.textPrimary)
                
                Divider()
                    .background(ColorTokens.divider)
                
                // 存储空间
                if let storageInfo = status.storageInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ColorTokens.accent)
                            Text("存储空间")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.1f", storageInfo.usagePercentage))%")
                                .font(FontTokens.systemValue)
                                .foregroundColor(ColorTokens.warning)
                        }
                        
                        // 进度条
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ColorTokens.progressTrack)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .cyan]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (storageInfo.usagePercentage / 100))
                            }
                        }
                        .frame(height: 4)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("已用")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                Text(storageInfo.usedStorageText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("总计")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                Text(storageInfo.totalStorageText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.textPrimary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("磁盘剩余")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(storageInfo.freeStorageText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.success)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                        }
                    }
                }
                
                Divider()
                    .background(ColorTokens.divider)
                
                // 下载速度
                if let downloaderInfo = status.downloaderInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        // 上传/下载速度 - 左右居中布局
                        HStack(spacing: 16) {
                            // 下载 - 居中
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(ColorTokens.accent)
                                Text(downloaderInfo.downloadSpeedText)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(ColorTokens.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            // 上传 - 居中
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(ColorTokens.warning)
                                Text(downloaderInfo.uploadSpeedText)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(ColorTokens.warning)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // 总传输和剩余空间
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("总下载")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.downloadSizeText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.info)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("总上传")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.uploadSizeText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.warning)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("磁盘剩余")
                                    .font(FontTokens.systemLabel)
                                    .foregroundColor(ColorTokens.textDim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.freeSpaceText)
                                    .font(FontTokens.systemValue)
                                    .foregroundColor(ColorTokens.success)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .foregroundColor(ColorTokens.textPrimary)
            .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ColorTokens.progressTrack, lineWidth: 1)
                        )
                )
        }
    }
}

// 简洁版系统状态卡片（仅两行）
struct CompactSystemStatusCard: View {
    @ObservedObject var viewModel: SystemStatusViewModel

    var body: some View {
        if let status = viewModel.systemStatus {
            VStack(spacing: 12) {
                // 第一行：存储图标 + 进度条 + 总存储
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ColorTokens.accent)
                        .frame(width: 28)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))

                            if let storage = status.storageInfo {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, geo.size.width * (storage.usagePercentage / 100)))
                            }
                        }
                    }
                    .frame(height: 8)

                    if let storage = status.storageInfo {
                        Text(storage.totalStorageText)
                            .font(FontTokens.systemValue)
                            .foregroundColor(ColorTokens.textPrimary.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(height: 28)

                // 第二行：下载 / 上传 速度 - 左右两块完整显示
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.accent)
                        Text(status.downloaderInfo?.downloadSpeedText ?? "0.0 B/s")
                            .foregroundColor(ColorTokens.accent)
                            .font(FontTokens.systemValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text(status.downloaderInfo?.uploadSpeedText ?? "0.0 B/s")
                            .foregroundColor(ColorTokens.warning)
                            .font(FontTokens.systemValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 24)
            }
            .padding(12)
            .background(
                // 使用半透明的 material 背景并添加阴影，模拟 tab 导航栏的浮层感
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 6)
            )
            .accessibilityElement(children: .contain) // 保持无障碍行为一致
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SystemStatusCard(viewModel: SystemStatusViewModel())
            .padding()
            .background(Color.black)

        CompactSystemStatusCard(viewModel: SystemStatusViewModel())
            .padding()
            .background(Color.black)
    }
}
