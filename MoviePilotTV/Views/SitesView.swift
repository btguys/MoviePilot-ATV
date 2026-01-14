//
//  SitesView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct SitesView: View {
    @StateObject private var viewModel = SitesViewModel()
    @Namespace private var namespace
    @FocusState private var focusedSiteId: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                Text("站点")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                if !viewModel.isLoading {
                    Text("共 \(viewModel.sites.count) 个站点")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.horizontal, 90)
            .padding(.vertical, 30)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Content
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("加载中...")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    Spacer()
                }
            } else if viewModel.sites.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "server.rack")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    Text("暂无站点")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 30)
                        ],
                        spacing: 30
                    ) {
                        ForEach(viewModel.sites) { site in
                            SiteCardView(
                                site: site,
                                userData: viewModel.siteUserData[site.domain],
                                isFocused: focusedSiteId == site.id
                            )
                            .focusable()
                            .focused($focusedSiteId, equals: site.id)
                        }
                    }
                    .padding(40)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            viewModel.loadSites()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// 站点卡片视图
struct SiteCardView: View {
    let site: Site
    let userData: SiteUserData?
    let isFocused: Bool
    
    var body: some View {
        cardContent
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isFocused ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused ? Color.white : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            headerSection
            trafficSection
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            siteIcon
            siteInfo
            Spacer()
        }
        .padding(20)
        .padding(.bottom, 8)
    }
    
    private var siteIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 64, height: 64)
            
            Text(String(site.name.prefix(1)))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var siteInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(site.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(site.domain)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }
    
    private var trafficSection: some View {
        VStack(spacing: 12) {
            uploadTrafficRow
            downloadTrafficRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var uploadTrafficRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                Text(userData?.uploadText ?? "0.00 B")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .leading)
            }
            
            uploadProgressBar
        }
    }
    
    private var downloadTrafficRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                Text(userData?.downloadText ?? "0.00 B")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .leading)
            }
            
            downloadProgressBar
        }
    }
    
    private var uploadProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                if let userData = userData, userData.upload > 0 || userData.download > 0 {
                    let total = Double(userData.upload) + Double(userData.download)
                    let uploadRatio = total > 0 ? Double(userData.upload) / total : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.cyan)
                        .frame(width: geometry.size.width * uploadRatio, height: 6)
                }
            }
        }
        .frame(height: 6)
    }
    
    private var downloadProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                if let userData = userData, userData.upload > 0 || userData.download > 0 {
                    let total = Double(userData.upload) + Double(userData.download)
                    let downloadRatio = total > 0 ? Double(userData.download) / total : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * downloadRatio, height: 6)
                }
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    SitesView()
}
