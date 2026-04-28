//
//  RecommendView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct RecommendView: View {
    @StateObject private var viewModel = RecommendViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("推荐榜单")
                        .font(FontTokens.pageTitle)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("来自 TMDB 和豆瓣的精选内容")
                        .font(FontTokens.caption)
                        .foregroundColor(ColorTokens.textMuted)
                }
                .padding(.vertical, 25)
                .padding(.horizontal, 55)
                
                Divider()
                    .background(ColorTokens.divider)
                    .padding(.horizontal, 55)

                // Content
                if viewModel.isLoading {
                    LoadingView("正在加载推荐内容...")
                        .frame(height: 400)
                } else if viewModel.sections.isEmpty {
                    EmptyStateView(icon: "star.slash", title: "暂无推荐内容")
                } else {
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(viewModel.sections) { section in
                            RecommendSectionView(section: section)
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
        .navigationDestination(for: MediaItem.self) { media in
            MediaDetailView(media: media)
        }
        .navigationDestination(for: CategoryMoreDestination.self) { destination in
            CategoryMoreView(source: destination.source, categoryTitle: destination.title)
        }
        .onAppear {
            if viewModel.sections.isEmpty {
                viewModel.loadAllRecommendations()
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

struct RecommendSectionView: View {
    let section: RecommendSection
    
    // 从 section title 推断 source
    private var sourceKey: String {
        switch section.title {
        case "TMDB 流行趋势": return "tmdb_trending"
        case "TMDB 电影": return "tmdb_movies"
        case "TMDB 剧集": return "tmdb_tvs"
        case "豆瓣热门电影": return "douban_movie_hot"
        case "豆瓣热门剧集": return "douban_tv_hot"
        case "豆瓣电影 TOP250": return "douban_movie_top250"
        case "豆瓣最新电影": return "douban_movies"
        case "豆瓣最新剧集": return "douban_tvs"
        default: return "tmdb_trending"
        }
    }
    
    // 限制显示前10条
    private var displayItems: [MediaItem] {
        return Array(section.items.prefix(10))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(section.title)
                .font(FontTokens.sectionTitle)
                .foregroundColor(ColorTokens.textPrimary)
                .padding(.leading, 30)
            
            // 使用 LazyHStack 而不是 ScrollView 来改善焦点行为
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(displayItems) { item in
                        NavigationLink(value: item) {
                            MediaCard(media: item)
                                .frame(width: 250)
                        }
                        .buttonStyle(.cardButton)
                    }
                    
                    // 更多卡片
                    NavigationLink(value: CategoryMoreDestination(source: sourceKey, title: section.title)) {
                        MoreCard()
                            .frame(width: 250)
                    }
                    .buttonStyle(.cardButton)
                }
                .padding(.vertical, 20) // 放大时留出更多上下空间，避免裁切
                .padding(.horizontal, 30)
            }
            .focusSection()
        }
    }
}

// MARK: - More Card Component

private struct MoreCard: View {
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // 主卡片区域 - 保持与 MediaCard 相同的宽高比
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.4),
                                Color.purple.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(2/3, contentMode: .fill)
                
                VStack(spacing: 16) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("查看更多")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // 占位文字 - 保持与 MediaCard 相同的间距
            Text("")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.clear)
                .lineLimit(2)
            
            Text("")
                .font(.system(size: 15))
                .foregroundColor(.clear)
        }
    }
}

// MARK: - Navigation Destination Type

struct CategoryMoreDestination: Hashable {
    let source: String
    let title: String
}

struct RecommendView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendView()
    }
}
