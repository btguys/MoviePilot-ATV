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
                        .foregroundColor(.green)
                        .scaleEffect(viewModel.isLoading ? 1.1 : 1.0)
                        .opacity(viewModel.isLoading ? 1.0 : 0.9)
                        .animation(viewModel.isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
                .foregroundColor(.white)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // 存储空间
                if let storageInfo = status.storageInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("存储空间")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.1f", storageInfo.usagePercentage))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        
                        // 进度条
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                
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
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(storageInfo.usedStorageText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("总计")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(storageInfo.totalStorageText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("磁盘剩余")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(storageInfo.freeStorageText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // 下载速度
                if let downloaderInfo = status.downloaderInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        // 上传/下载速度
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.cyan)
                                    Text("下载")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text(downloaderInfo.downloadSpeedText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                    Text("上传")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Text(downloaderInfo.uploadSpeedText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // 总传输和剩余空间
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("总下载")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.downloadSizeText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("总上传")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.uploadSizeText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("磁盘剩余")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Text(downloaderInfo.freeSpaceText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .foregroundColor(.white)
            .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    SystemStatusCard(viewModel: SystemStatusViewModel())
        .padding()
        .background(Color.black)
}
