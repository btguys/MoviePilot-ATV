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
                                .padding(.horizontal, 90)
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
                        .padding(.horizontal, 90)
                        .padding(.vertical, 20)
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
                .padding(.horizontal, 90)
                .padding(.vertical, 20)
                .id("doubanMoviesSection")
                
                // 豆瓣热门剧集
                MediaSection(
                    title: "豆瓣热门剧集",
                    items: viewModel.doubanHotTVs,
                    isLoading: viewModel.isLoadingTrending,
                    focusedCardId: $focusedCardId,
                    lastFocusedCardId: $lastFocusedCardId,
                    isFirstSection: false
                )
                .padding(.horizontal, 90)
                .padding(.vertical, 20)
                .id("doubanTVsSection")
                
                // Recent Subscriptions
                if !viewModel.recentSubscriptions.isEmpty {
                    SubscriptionSection(
                        title: "最近订阅",
                        items: viewModel.recentSubscriptions
                    )
                    .padding(.horizontal, 90)
                    .padding(.vertical, 20)
                    .id("subscriptionSection")
                }
                
                // Bottom spacing
                Color.clear.frame(height: 60)
            }
            }
            .background(Color.black)
            .zIndex(2)
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
                    
                    if let focusedMedia = viewModel.tmdbTrending.first(where: { $0.id == newValue }) {
                        // 焦点在TMDB推荐，滚动到Hero（使Hero贴近屏幕上边界）
                        targetId = "heroSection"
                        heroMedia = focusedMedia
                    } else if let focusedMedia = viewModel.doubanHotMovies.first(where: { $0.id == newValue }) {
                        // 焦点在豆瓣电影，滚动到该section
                        targetId = "doubanMoviesSection"
                        heroMedia = focusedMedia
                    } else if let focusedMedia = viewModel.doubanHotTVs.first(where: { $0.id == newValue }) {
                        // 焦点在豆瓣剧集，滚动到该section
                        targetId = "doubanTVsSection"
                        heroMedia = focusedMedia
                    }
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
            }
            
            // 浮动系统状态卡片（右下角）
            VStack {
                Spacer()
                SystemStatusCard(viewModel: systemStatusViewModel)
                    .frame(width: 300)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
            }
            .zIndex(3)
        }
        .onAppear {
            viewModel.loadData()
            systemStatusViewModel.startUpdating()
            
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
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                
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
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.white)
                
                if let overview = media.overview {
                    Text(overview)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 26) {
                        ForEach(items) { item in
                            NavigationLink(
                                destination: MediaDetailView(media: item)
                                    .toolbar(.hidden, for: .navigationBar)
                                    .navigationBarHidden(true)
                            ) {
                                MediaCard(media: item)
                                    .frame(width: 220)
                            }
                            .buttonStyle(.card)
                            .focused(focusedCardId, equals: item.id)
                        }
                    }
                    .padding(.vertical, 20)
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
        VStack(alignment: .center, spacing: 10) {
            // Poster
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
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
                        @unknown default:
                            Color.gray.opacity(0.3)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title
            Text(media.title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Year
            if let year = media.year {
                Text(String(year))
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
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
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(items) { item in
                        NavigationLink(
                            destination: MediaDetailView(media: MediaItem.from(item))
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarHidden(true)
                        ) {
                            SubscriptionCardContent(subscription: item)
                                .frame(width: 220)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
            }
            .focusSection()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
