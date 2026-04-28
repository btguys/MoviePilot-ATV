//
//  HomeView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var systemStatusViewModel: SystemStatusViewModel
    @StateObject private var authManager = AuthenticationManager.shared
    @FocusState private var focusedCardId: Int?
    @State private var lastFocusedCardId: Int?
    @State private var heroMedia: MediaItem? // 当前Hero显示的媒体
    @FocusState private var isHeroFocused: Bool

    init(systemStatusViewModel: SystemStatusViewModel = SystemStatusViewModel()) {
        _systemStatusViewModel = ObservedObject(wrappedValue: systemStatusViewModel)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        // Hero Section
                        if let featured = heroMedia ?? viewModel.featuredMedia.first {
                            FeaturedMediaCard(media: featured)
                                .padding(.horizontal, 55)
                                .padding(.top, -20)  // 负数 padding 让 Hero 向上移动，贴近导航栏
                                .id("heroSection")
                                .id("heroSection")
                        }
                        
                        // TMDB 流行趋势 - 第一行
                        MediaSection(
                            title: "TMDB 流行趋势",
                            items: viewModel.tmdbTrending,
                            isLoading: viewModel.isLoadingTrending,
                            focusedCardId: $focusedCardId,
                            lastFocusedCardId: $lastFocusedCardId,
                            isFirstSection: false
                        )
                        .padding(.horizontal, 55)
                        .padding(.vertical, 24)
                        .id("firstSection")
                        .zIndex(1)
                    
                    // 豆瓣热门电影
                MediaSection(
                    title: "豆瓣热门电影",
                    items: viewModel.doubanHotMovies,
                    isLoading: viewModel.isLoadingTrending,
                    focusedCardId: $focusedCardId,
                    lastFocusedCardId: $lastFocusedCardId,
                    isFirstSection: false
                )
                .padding(.horizontal, 55)
                .padding(.vertical, 24)
                .id("doubanMoviesSection")
                
                // 豆瓣国产剧集
                MediaSection(
                    title: "豆瓣国产剧集",
                    items: viewModel.doubanHotTVs,
                    isLoading: viewModel.isLoadingTrending,
                    focusedCardId: $focusedCardId,
                    lastFocusedCardId: $lastFocusedCardId,
                    isFirstSection: false
                )
                .padding(.horizontal, 55)
                .padding(.vertical, 24)
                .id("doubanTVsSection")
                
                // Recent Subscriptions
                if !viewModel.recentSubscriptions.isEmpty {
                    SubscriptionSection(
                        title: "最近订阅",
                        items: viewModel.recentSubscriptions
                    )
                    .padding(.horizontal, 55)
                    .padding(.vertical, 24)
                    .id("subscriptionSection")
                }
                
                // Bottom spacing
                Color.clear.frame(height: 60)
            }
            }
            .background(ColorTokens.appBackground)
            .zIndex(2)
            .navigationDestination(for: CategoryMoreDestination.self) { destination in
                CategoryMoreView(source: destination.source, categoryTitle: destination.title)
            }
            .onChange(of: isHeroFocused) { isFocused in
                if isFocused {
                    // 当Hero被聚焦时，滚动使其贴近屏幕上边界
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo("heroSection", anchor: .top)
                    }
                }
            }
            .onChange(of: focusedCardId) { newValue in
                if newValue != nil {
                    // 判断焦点卡片属于哪个section，然后滚动到对应section
                    var targetId = "heroSection"
                    var scrollAnchor: UnitPoint = .center
                    
                    if let focusedMedia = viewModel.tmdbTrending.first(where: { $0.id == newValue }) {
                        // 焦点在TMDB推荐（第一行），滚动到heroSection，使用向上偏移的anchor
                        // 让导航栏滚出屏幕，同时Hero完全可见
                        targetId = "heroSection"
                        scrollAnchor = UnitPoint(x: 0.5, y: -0.45)
                        heroMedia = focusedMedia
                    } else if let focusedMedia = viewModel.doubanHotMovies.first(where: { $0.id == newValue }) {
                        // 焦点在豆瓣电影，滚动到该section
                        targetId = "doubanMoviesSection"
                        scrollAnchor = .center
                        heroMedia = focusedMedia
                    } else if let focusedMedia = viewModel.doubanHotTVs.first(where: { $0.id == newValue }) {
                        // 焦点在豆瓣国产剧集，滚动到该section
                        targetId = "doubanTVsSection"
                        scrollAnchor = .center
                        heroMedia = focusedMedia
                    }
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(targetId, anchor: scrollAnchor)
                    }
                }
            }
            }
            
            // 浮动系统状态卡片（右下角）- 根据设置显示
            if authManager.showHomeSystemStatus {
                switch authManager.homeSystemStatusMode {
                case .full:
                    VStack {
                        Spacer()
                        SystemStatusCard(viewModel: systemStatusViewModel)
                            .frame(width: 300)
                            .padding(.trailing, 0)
                            .padding(.bottom, -20)
                    }
                    .zIndex(3)
                case .compact:
                    VStack {
                        CompactSystemStatusCard(viewModel: systemStatusViewModel)
                            .frame(width: 260)
                            .padding(.trailing, 0)
                            .padding(.top, -120)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(3)
                case .off:
                    EmptyView()
                }
            }
        }
        .onAppear {
            viewModel.loadData()
            
            // 仅在设置开启时启动系统状态更新
            if authManager.showHomeSystemStatus {
                systemStatusViewModel.startUpdating()
            }
            
            // 恢复之前聚焦的卡片
            if let last = lastFocusedCardId {
                // 延迟更长时间以确保视图完全渲染
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedCardId = last
                    print("✅ [HomeView] 已恢复焦点到卡片: \(last)")
                }
            } else {
                // 如果没有保存的焦点，尝试聚焦第一个卡片
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let firstItem = viewModel.tmdbTrending.first {
                        focusedCardId = firstItem.id
                        print("✅ [HomeView] 已设置焦点到首个卡片: \(firstItem.id)")
                    }
                }
            }
        }
        .onDisappear {
            systemStatusViewModel.stopUpdating()
            print("🛑 [HomeView] 已停止系统状态更新")
        }
        .onChange(of: authManager.showHomeSystemStatus) { _, newValue in
            if newValue {
                print("✅ [HomeView] 设置已开启，启动系统状态更新")
                systemStatusViewModel.startUpdating()
            } else {
                print("⭕ [HomeView] 设置已关闭，停止系统状态更新")
                systemStatusViewModel.stopUpdating()
            }
        }
        .onChange(of: focusedCardId) { newValue in
            if let newValue {
                lastFocusedCardId = newValue
                // 如果焦点在TMDB推荐卡片上，则Hero显示对应的媒体
                if let focusedMedia = viewModel.tmdbTrending.first(where: { $0.id == newValue }) {
                    heroMedia = focusedMedia
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

struct FeaturedMediaCard: View {
    let media: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image - Top aligned to show more detail
            if let backdropURL = media.backdropURL {
                CachedAsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 600)
                    case .failure:
                        Color.gray.opacity(0.3)
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(height: 600)
                .id(media.id)  // 强制在媒体变化时重新加载图像
            } else {
                Color.gray.opacity(0.3)
            }
            
            // Media Info
            VStack(alignment: .leading, spacing: 12) {
                Text(media.title)
                    .font(FontTokens.heroTitle)
                    .foregroundColor(ColorTokens.textPrimary)
                
                HStack(spacing: 15) {
                    if let rating = media.voteAverage {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    
                    if let year = media.year {
                        Text(String(year))
                            .font(.system(size: 16))
                    }
                    
                    if let type = media.mediaType {
                        Text(type == "movie" ? "电影" : "电视剧")
                            .font(.system(size: 14))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ColorTokens.accent.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.white)
                
                if let overview = media.overview {
                    Text(overview)
                        .font(FontTokens.detailBody)
                        .foregroundColor(ColorTokens.textPrimary.opacity(0.9))
                        .lineLimit(3)
                        .frame(maxWidth: 700, alignment: .leading)
                }
            }
            .padding(50)
        }
        .frame(height: 600)
        .cornerRadius(20)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
    }
}

struct MediaSection: View {
    let title: String
    let items: [MediaItem]
    let isLoading: Bool
    var focusedCardId: FocusState<Int?>.Binding
    @Binding var lastFocusedCardId: Int?
    var isFirstSection: Bool = false
    
    // 从 title 推断 source
    private var sourceKey: String {
        switch title {
        case "TMDB 流行趋势": return "tmdb_trending"
        case "豆瓣热门电影": return "douban_movie_hot"
        case "豆瓣国产剧集": return "douban_tv_weekly_chinese"
        default: return "tmdb_trending"
        }
    }
    
    // 判断是否显示更多卡片（只有这三个栏目显示）
    private var showMoreCard: Bool {
        return title == "TMDB 流行趋势" || title == "豆瓣热门电影" || title == "豆瓣国产剧集"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(FontTokens.sectionTitle)
                .foregroundColor(ColorTokens.textPrimary)

            if isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 32) {
                        ForEach(items) { item in
                            NavigationLink(
                                destination: MediaDetailView(media: item)
                                    .toolbar(.hidden, for: .navigationBar)
                                    .navigationBarHidden(true)
                            ) {
                                MediaCard(media: item)
                                    .frame(width: 250)
                            }
                            .buttonStyle(.card)
                            .focused(focusedCardId, equals: item.id)
                        }
                        
                        // 更多卡片（仅指定栏目显示）
                        if showMoreCard {
                            NavigationLink(value: CategoryMoreDestination(source: sourceKey, title: title)) {
                                HomeMoreCard()
                                    .frame(width: 250)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                }
                .focusSection()
            }
        }
    }
}

struct MediaCard: View {
    let media: MediaItem
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // Poster
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surfaceCard)
                if let posterURL = media.posterURL {
                    CachedAsyncImage(url: posterURL) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.3)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        case .failure:
                            Color.gray.opacity(0.3)
                                .onAppear {
                                    print("⚠️ [MediaCard] 图片加载失败 source=\(media.source ?? "<nil>") title=\(media.title) posterPath=\(media.posterPath ?? "<nil>") url=\(posterURL)")
                                }
                        @unknown default:
                            Color.gray.opacity(0.3)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                        .onAppear {
                            print("⚠️ [MediaCard] 缺少 posterURL source=\(media.source ?? "<nil>") title=\(media.title) posterPath=\(media.posterPath ?? "<nil>")")
                        }
                }
                
                // Rating Badge
                if let rating = media.voteAverage {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Title
            Text(media.title)
                .font(FontTokens.cardTitle)
                .foregroundColor(ColorTokens.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Year
            if let year = media.year {
                Text(String(year))
                    .font(FontTokens.cardSubtitle)
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct SubscriptionSection: View {
    let title: String
    let items: [Subscription]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(FontTokens.sectionTitle)
                .foregroundColor(ColorTokens.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(items) { item in
                        NavigationLink(
                            destination: MediaDetailView(media: MediaItem.from(item))
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarHidden(true)
                        ) {
                            SubscriptionCardContent(subscription: item)
                                .frame(width: 250)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .focusSection()
        }
    }
}

// MARK: - Home More Card Component

private struct HomeMoreCard: View {
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
