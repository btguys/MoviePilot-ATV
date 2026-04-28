//
//  MediaDetailView.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import SwiftUI
import UIKit

// 详情页焦点区域枚举
enum DetailViewFocusArea {
    case backButton
    case searchButton
    case subscribeButton
    case infuseButton
}

// FocusedValueKey for DetailViewFocusArea
struct DetailViewFocusAreaKey: FocusedValueKey {
    typealias Value = DetailViewFocusArea
}

extension FocusedValues {
    var detailViewFocusArea: DetailViewFocusArea? {
        get { self[DetailViewFocusAreaKey.self] }
        set { self[DetailViewFocusAreaKey.self] = newValue }
    }
}

// 柔和聚焦样式 - 用于简介、演员、导演等内容区域
struct SoftFocusButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFocused ? ColorTokens.surfaceHover : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 放大效果按钮样式 - 用于搜索资源和订阅按钮
struct ScaleFocusButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isFocused ? Color.white.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 20, x: 0, y: 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 搜索结果卡片按钮样式 - 用于搜索结果列表
struct SearchResultCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFocused ? Color.blue.opacity(0.3) : Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 4)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: isFocused ? Color.blue.opacity(0.6) : Color.clear, radius: 15, x: 0, y: 8)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 返回按钮样式 - 柔和的聚焦效果
struct BackButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : 1.0)  // 微微放大
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isFocused ? 1.0 : 0.85)  // 聚焦时完全不透明，否则稍微透明
            .shadow(color: isFocused ? Color.white.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)  // 柔和白色阴影
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MediaDetailView: View {
    let media: MediaItem
    var shouldAutoSearch: Bool = false
    
    @StateObject private var viewModel = MediaDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedResultId: String?
    @FocusState private var focusedButtonArea: DetailViewFocusArea?
    @State private var pendingDownload: Torrent?
    @State private var showDownloadConfirm = false
    @State private var isOverviewExpanded = false
    @State private var showSeasonPanel = false
    @State private var selectedSeason: SeasonCard?
    @FocusState private var focusedEpisodeButton: Bool?
    @State private var showSubscribeConfirm = false
    @FocusState private var focusedEpisodeId: Int?
    @State private var cachedSeasonCards: [SeasonCard] = []  // 缓存构建好的季卡片
    @State private var tmdbLookupInProgress = false
    @State private var resolvedTmdbId: Int?
    @State private var showTmdbKeyAlert = false
    @State private var isAnimating = false

    // 季下载状态
    private enum DownloadStatus {
        case complete      // 已入库（全部集数）
        case partial       // 部分缺失
        case missing       // 缺失（无任何集数）
        
        var text: String {
            switch self {
            case .complete: return "已入库"
            case .partial: return "部分缺失"
            case .missing: return "缺失"
            }
        }
        
        var color: Color {
            switch self {
            case .complete: return .green
            case .partial: return .yellow
            case .missing: return .red
            }
        }
    }
    
    private enum TagKind { case meta, label }
    private struct TagDisplay: Identifiable {
        let id = UUID()
        let text: String
        let kind: TagKind
    }

    // MARK: - Person Card Data (actor & crew unified)
    private struct PersonCardData: Identifiable {
        let id: String  // stable identity for focus: "name|subtitle"
        let name: String
        let subtitle: String?  // character name or role label
        let profileURL: URL?

        init(name: String, subtitle: String?, profileURL: URL?) {
            self.id = "\(name)|\(subtitle ?? "")"
            self.name = name
            self.subtitle = subtitle
            self.profileURL = profileURL
        }
    }

    private struct CrewItem: Identifiable {
        let id = UUID()
        let role: String  // Chinese job label
        let name: String
        let profileURL: URL?
    }

    private struct SeasonCard: Identifiable {
        let id: String
        let seasonNumber: Int
        let name: String
        let episodeCount: Int
        let airDate: String?
        var downloadStatus: DownloadStatus = .missing
        var isSubscribed: Bool = false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoadingDetail {
                loadingAnimationView()
            } else if let detail = viewModel.mediaDetail {
                ScrollViewReader { proxy in
                    detailScrollView(detail: detail, proxy: proxy)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 62))
                        .foregroundColor(ColorTokens.textMuted)
                    Text("加载详情失败")
                        .font(FontTokens.detailBody)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .onAppear {
            viewModel.loadDetail(from: media)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedButtonArea = .searchButton
            }
            if shouldAutoSearch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.searchResources()
                }
            }
        }
        .onExitCommand {
            dismiss()
        }
        .overlay {
            ZStack {
                if viewModel.showSearchProgress {
                    searchProgressOverlay()
                }
                if viewModel.isDownloading {
                    downloadProgressOverlay()
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("成功", isPresented: $viewModel.showSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("确认下载", isPresented: $showDownloadConfirm, presenting: pendingDownload) { torrent in
            Button("下载") {
                viewModel.downloadResource(torrent: torrent)
                pendingDownload = nil
            }
            Button("取消", role: .cancel) {
                pendingDownload = nil
            }
        } message: { torrent in
            Text(torrent.title ?? "确认下载该资源？")
        }
        .overlay {
            if showSeasonPanel, let season = selectedSeason {
                seasonDetailPanel(season: season)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func detailScrollView(detail: MediaDetail, proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                detailHeroSection(detail: detail)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height)
                    .padding(.top, -80)
                    .ignoresSafeArea()
                    .id("heroTop")
                detailContentSection(detail: detail)
            }
        }
        .scrollDisabled(showSeasonPanel)  // 面板打开时禁用背景滚动
        .ignoresSafeArea(edges: .top)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                proxy.scrollTo("heroTop", anchor: .top)
            }
        }
        .onChange(of: viewModel.searchResults.count) { oldValue, newValue in
            if newValue > 0 && oldValue != newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("searchResults", anchor: .top) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let firstResult = viewModel.searchResults.first {
                            focusedResultId = firstResult.id
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.scrollToResultsNonce) { _, _ in
            DispatchQueue.main.async {
                withAnimation { proxy.scrollTo("searchResults", anchor: .top) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let firstResult = viewModel.searchResults.first {
                        focusedResultId = firstResult.id
                    }
                }
            }
        }
        .onChange(of: focusedButtonArea) { newValue in
            if let area = newValue, area == .searchButton || area == .subscribeButton || area == .infuseButton {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("heroTop", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func detailHeroSection(detail: MediaDetail) -> some View {
        GeometryReader { geo in
            ZStack {
                // Backdrop fills and clips
                if let backdropURL = detail.backdropURL {
                    CachedAsyncImage(url: backdropURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        default:
                            Color.gray.opacity(0.3)
                        }
                    }
                } else {
                    Color.gray.opacity(0.3)
                }

                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.8), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay: absolute positioning via VStack (top bar + bottom info)
                VStack {
                    // Top-left back button
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 22, weight: .medium))
                                Text("返回")
                                    .font(.system(size: 20, weight: .regular))
                            }
                            .foregroundColor(ColorTokens.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        }
                        .buttonStyle(BackButtonStyle())
                        .focusedValue(\.detailViewFocusArea, .backButton)
                        .focusSection()
                        .padding(.top, 20)
                        .padding(.leading, 40)
                        Spacer()
                    }

                    Spacer()

                    // Main content anchored at bottom
                    HStack(alignment: .bottom, spacing: 48) {
                        // Left: poster + (title over buttons)
                        HStack(alignment: .bottom, spacing: 20) {
                            if let posterURL = detail.posterURL {
                                CachedAsyncImage(url: posterURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 280, height: 420)
                                .cornerRadius(12)
                                .shadow(radius: 20)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text(detail.title)
                                    .font(FontTokens.heroTitle)
                                    .foregroundColor(ColorTokens.textPrimary)
                                    .lineLimit(2)
                                    .frame(maxWidth: 380, alignment: .leading)

                                if let originalTitle = detail.originalTitle, originalTitle != detail.title {
                                    Text(originalTitle)
                                        .font(.system(size: 24))
                                        .foregroundColor(ColorTokens.textSecondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 380, alignment: .leading)
                                }

                                // 订阅按钮显示条件：只有TMDB来源的电视剧才隐藏
                                // TMDB来源的电视剧在季卡片上处理订阅，电影和豆瓣来源的内容在此处显示订阅按钮
                                let shouldShowSubscribeButton = !(detail.source?.lowercased() == "themoviedb" && detail.type == "电视剧")
                                
                                // 调试信息
                                let _ = {
                                    print("DEBUG: source = '\(detail.source ?? "nil")', type = '\(detail.type ?? "nil")', shouldShowSubscribeButton = \(shouldShowSubscribeButton)")
                                }()

                                HStack(spacing: 25) {
                                    Button(action: { viewModel.searchResources() }) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 22))
                                            Text("搜索资源")
                                                .font(FontTokens.buttonText)
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 14)
                                        .background(ColorTokens.divider)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(ScaleFocusButtonStyle())
                                    .focusedValue(\.detailViewFocusArea, .searchButton)
                                    .focused($focusedButtonArea, equals: .searchButton)
                                    .disabled(viewModel.isSearching)

                                    if shouldShowSubscribeButton {
                                        Button(action: { viewModel.subscribe() }) {
                                            HStack(spacing: 2) {
                                                if viewModel.isSubscribing {
                                                    ProgressView()
                                                } else {
                                                    Image(systemName: viewModel.isSubscribed ? "heart.fill" : "heart")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(viewModel.isSubscribed ? .red : .yellow)
                                                }
                                                Text(viewModel.isSubscribed ? "已订阅" : "订阅")
                                                    .font(FontTokens.buttonText)
                                                    .foregroundColor(viewModel.isSubscribed ? .red : .yellow)
                                            }
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 14)
                                            .background(viewModel.isSubscribed ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(ScaleFocusButtonStyle())
                                        .focusedValue(\.detailViewFocusArea, .subscribeButton)
                                        .focused($focusedButtonArea, equals: .subscribeButton)
                                        .disabled(viewModel.isSubscribing)
                                    }

                                    let authManager = AuthenticationManager.shared
                                    let currentTmdbId = media.tmdbId ?? resolvedTmdbId
                                    let hasTmdbKey = !authManager.tmdbApiKey.isEmpty
                                    let needsTmdbKey = currentTmdbId == nil && !hasTmdbKey

                                    Button(action: {
                                        if let id = currentTmdbId {
                                            openInInfuse(tmdbOverride: id)
                                            return
                                        }
                                        if needsTmdbKey {
                                            showTmdbKeyAlert = true
                                            return
                                        }
                                        Task {
                                            await lookupTmdbIdIfNeeded()
                                            if let id = resolvedTmdbId ?? media.tmdbId {
                                                openInInfuse(tmdbOverride: id)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 2) {
                                            if tmdbLookupInProgress {
                                                ProgressView()
                                                    .scaleEffect(0.9)
                                            } else {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 22))
                                            }
                                            Text("Infuse播放")
                                                .font(FontTokens.buttonText)
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 14)
                                        .background(needsTmdbKey ? Color.gray.opacity(0.5) : Color.orange.opacity(0.9))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(ScaleFocusButtonStyle())
                                    .focusedValue(\.detailViewFocusArea, .infuseButton)
                                    .focused($focusedButtonArea, equals: .infuseButton)
                                    .disabled(tmdbLookupInProgress)
                                    .alert("提示", isPresented: $showTmdbKeyAlert) {
                                        Button("知道了", role: .cancel) { }
                                    } message: {
        Text("豆瓣来源的影片需要在设置中配置 TMDB API KEY 后才能获取正确的 TMDB ID 并跳转到 Infuse 播放。")
                                    }
                                }
                                .focusSection()
                            }
                        }

                        // Right: meta/tags + overview stacked with same width
                        VStack(alignment: .trailing, spacing: 12) {
                            // Meta + overview stacked with same width
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    if let rating = detail.voteAverage {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.yellow)
                                            Text(String(format: "%.1f", rating))
                                                .font(FontTokens.buttonText)
                                        }
                                    }

                                    if let year = detail.year {
                                        Text(year)
                                            .font(.system(size: 22))
                                            .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                                    }

                                    if let type = detail.type {
                                        Text(type)
                                            .font(.system(size: 18))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(6)
                                    }

                                    if let lang = detail.originalLanguage {
                                        Text(lang.uppercased())
                                            .font(.system(size: 18))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.6))
                                            .cornerRadius(6)
                                    }

                                    if let genres = detail.genres {
                                        ForEach(genres.prefix(4), id: \.self) { genre in
                                            Text(genre)
                                                .font(.system(size: 18))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.3))
                                                .cornerRadius(5)
                                                .foregroundColor(ColorTokens.textPrimary)
                                        }
                                    }
                                }
                                .foregroundColor(ColorTokens.textPrimary)

                                if let overview = detail.overview {
                                    Button(action: { isOverviewExpanded.toggle() }) {
                                        Text(overview)
                                            .font(FontTokens.detailBody)
                                            .foregroundColor(ColorTokens.textPrimary.opacity(0.9))
                                            .lineSpacing(6)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineLimit(isOverviewExpanded ? nil : 4)
                                            .frame(height: isOverviewExpanded ? nil : 140, alignment: .topLeading)
                                    }
                                    .buttonStyle(SoftFocusButtonStyle())
                                    .focusable()
                                }
                            }
                            .frame(maxWidth: 800, alignment: .trailing)
                        }
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.leading, 90)
                    .padding(.trailing, 90)
                    .padding(.bottom, 30)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea() // 让背景铺满左右，消除黑边
    }

    @ViewBuilder
    private func detailContentSection(detail: MediaDetail) -> some View {
        VStack(alignment: .leading, spacing: 40) {
            // 按照页面布局从上到下的自然顺序排列焦点区域：
            // 1. 季卡片（如有，紧接按钮下方）
            // 2. 主创团队
            // 3. 演员阵容
            
            seasonsSection(detail: detail)
            crewGridSection(detail: detail)

            // Actor section — unified design: rounded-rect cards with profile images
            // Priority: TMDB credits API > Douban PersonInfo from detail
            if let cast = viewModel.credits?.cast, !cast.isEmpty {
                let items = cast.prefix(15).map { member in
                    PersonCardData(
                        name: member.name,
                        subtitle: member.character.map { "饰 \($0)" },
                        profileURL: member.profileURL
                    )
                }
                personScrollSection(title: "演员阵容", count: items.count, items: items)
                    .focusSection()
            } else if let actorsData = detail.actorsData, !actorsData.isEmpty {
                let items = actorsData.prefix(15).map { person in
                    PersonCardData(
                        name: person.name ?? "",
                        subtitle: person.character.flatMap { ch in
                            // Douban character can be "演员" (just label) or "饰 林展翘" (specific role)
                            ch == "演员" || ch == "配音" ? nil : ch
                        },
                        profileURL: person.profileURL
                    )
                }
                personScrollSection(title: "演员阵容", count: items.count, items: items)
                    .focusSection()
            }
            
            // Search Results
            if !viewModel.visibleSearchResults.isEmpty {
                searchResultsSection()
                    .id("searchResults")  // 添加 ID 用于滚动定位
                    .onAppear {
                        print("✅ [MediaDetailView] 搜索结果区域已显示，共 \(viewModel.visibleSearchResults.count)/\(viewModel.searchResults.count) 个结果")
                    }
            } else {
                EmptyView()
                    .onAppear {
                        print("⚠️ [MediaDetailView] 搜索结果为空，未显示结果区域")
                    }
            }
        }
        .padding(60)
        .background(ColorTokens.appBackground)
        // 移除整体的 focusSection，让每个子区域独立管理焦点
    }

    @ViewBuilder
    private func seasonsSection(detail: MediaDetail) -> some View {
        // 在首次渲染时立即同步构建，确保焦点系统能够正确识别
        let seasonCards = cachedSeasonCards.isEmpty ? buildSeasonCards(detail: detail) : cachedSeasonCards
        
        if !seasonCards.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("季")
                    .font(FontTokens.sectionTitle)
                    .foregroundColor(ColorTokens.textPrimary)
                
                // 使用普通Grid而非LazyVGrid，确保立即渲染，让焦点系统能正确识别
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                    ForEach(0..<((seasonCards.count + 4) / 5), id: \..self) { rowIndex in
                        GridRow {
                            ForEach(0..<5, id: \.self) { colIndex in
                                let index = rowIndex * 5 + colIndex
                                if index < seasonCards.count {
                                    seasonCardButton(card: seasonCards[index], detail: detail)
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .focusSection()  // 设置季卡片为独立焦点区域
                .padding(.vertical, 10)
            }
            .onAppear {
                // 缓存构建结果
                if cachedSeasonCards.isEmpty {
                    cachedSeasonCards = seasonCards
                }
                print("✅ [MediaDetailView] seasonsSection - 显示季列表，共 \(seasonCards.count) 季")
            }
            .onChange(of: viewModel.seasonsExistData) { _, _ in
                // 当季存在数据更新时，重新构建卡片
                print("🔄 [MediaDetailView] 季存在数据已更新，重新构建季卡片")
                cachedSeasonCards = buildSeasonCards(detail: detail)
            }
            .onChange(of: viewModel.seasonSubscriptionStatus) { _, _ in
                // 当订阅状态更新时，重新构建卡片
                print("🔄 [MediaDetailView] 季订阅状态已更新，重新构建季卡片")
                cachedSeasonCards = buildSeasonCards(detail: detail)
            }
        }
    }

    @ViewBuilder
    private func crewGridSection(detail: MediaDetail) -> some View {
        let items = crewItems(detail: detail)
        if !items.isEmpty {
            let cards = items.map { item in
                PersonCardData(name: item.name, subtitle: item.role, profileURL: item.profileURL)
            }
            personScrollSection(title: "主创团队", count: cards.count, items: cards)
                .focusSection()
        }
    }
    
    // MARK: - Chinese job label mapping
    private func chineseJobLabel(_ english: String) -> String {
        let lower = english.lowercased()
        if lower.contains("director") { return "导演" }
        if lower.contains("writer") || lower.contains("screenplay") || lower.contains("story") { return "编剧" }
        if lower.contains("producer") { return "制片人" }
        if lower.contains("editor") { return "剪辑" }
        if lower.contains("cinematograph") || lower.contains("photograph") { return "摄影" }
        if lower.contains("music") || lower.contains("composer") { return "音乐" }
        return english
    }

    // MARK: - Person Card Component
    private struct PersonCard: View {
        let person: PersonCardData
        private let cardWidth: CGFloat = 140
        private let imageHeight: CGFloat = 187

        var body: some View {
            Button(action: {}) {
                VStack(spacing: 10) {
                    // Profile Image
                    if let profileURL = person.profileURL {
                        CachedAsyncImage(url: profileURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cardWidth, height: imageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure, .empty:
                                personPlaceholder
                            @unknown default:
                                personPlaceholder
                            }
                        }
                    } else {
                        personPlaceholder
                    }

                    // Name
                    Text(person.name)
                        .font(FontTokens.castName)
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(1)
                        .frame(width: cardWidth)

                    // Subtitle
                    if let subtitle = person.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(FontTokens.castCharacter)
                            .foregroundColor(ColorTokens.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: cardWidth)
                    }
                }
            }
            .buttonStyle(SoftFocusButtonStyle())
        }

        @ViewBuilder
        private var personPlaceholder: some View {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cardWidth, height: imageHeight)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ColorTokens.textDim)
                )
        }
    }

    // MARK: - Person Scroll Section Builder
    private func personScrollSection(title: String, count: Int, items: [PersonCardData]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(FontTokens.sectionTitle)
                    .foregroundColor(ColorTokens.textPrimary)
                Text("共 \(count) 位")
                    .font(FontTokens.caption)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(items) { item in
                        PersonCard(person: item)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - 加载动画视图
    @ViewBuilder
    private func loadingAnimationView() -> some View {
        ZStack {
            ColorTokens.appBackground.ignoresSafeArea()

            VStack(spacing: 60) {
                Spacer()

                // 海報 + 載入指示器
                ZStack {
                    if let url = media.posterURL {
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                posterPlaceholder
                            }
                        }
                        .frame(width: 360, height: 540)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    } else {
                        posterPlaceholder
                    }

                    // 旋轉載入環
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .cyan]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                        .onAppear { isAnimating = true }
                        .shadow(color: .black.opacity(0.8), radius: 8)
                }

                // 媒體資訊
                VStack(spacing: 12) {
                    Text(media.title)
                        .font(FontTokens.heroTitle)
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        if let year = media.year {
                            Text(year)
                                .font(FontTokens.detailBody)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        if let type = media.type {
                            Text(type)
                                .font(FontTokens.detailBody)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }

                    Text("正在加载...")
                        .font(FontTokens.caption)
                        .foregroundColor(ColorTokens.textMuted)
                        .padding(.top, 12)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(ColorTokens.surfaceCard)
            .frame(width: 360, height: 540)
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 60))
                    .foregroundColor(ColorTokens.textMuted)
            )
    }
    
    // MARK: - 搜索进度对话框
    @ViewBuilder
    private func searchProgressOverlay() -> some View {
        ZStack {
            // 半透明背景
            ColorTokens.appBackground.opacity(0.7)
                .ignoresSafeArea()
            
            // 进度卡片
            VStack(spacing: 30) {
                // 标题
                Text("正在搜索资源")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                
                // 进度环
                ZStack {
                    Circle()
                        .stroke(ColorTokens.divider, lineWidth: 12)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.searchProgress / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: viewModel.searchProgress)
                    
                    Text("\(Int(viewModel.searchProgress))%")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                }
                
                // 进度文本
                Text(viewModel.searchProgressText)
                    .font(.system(size: 22))
                    .foregroundColor(ColorTokens.textPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
                    .lineLimit(3)
            }
            .padding(60)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
        }
    }
    
    @ViewBuilder
    private func downloadProgressOverlay() -> some View {
        ZStack {
            ColorTokens.appBackground.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)
                Text("正在提交下载请求…")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .padding(50)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
                    .shadow(color: .black.opacity(0.5), radius: 18)
            )
        }
    }
    
    // MARK: - 搜索结果展示
    @ViewBuilder
    private func searchResultsSection() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题栏
            HStack {
                Text("搜索结果")
                    .font(FontTokens.sectionTitle)
                    .foregroundColor(ColorTokens.textPrimary)
                
                Spacer()
                Text("显示 \(viewModel.visibleSearchResults.count)/\(viewModel.searchResults.count) 个资源")
                    .font(.system(size: 20))
                    .foregroundColor(ColorTokens.textSecondary)
            }
            
            // 结果列表
            ScrollView {
                VStack(spacing: 25) {  // 增加间距从 15 到 25，避免焦点阴影重叠
                    ForEach(Array(viewModel.visibleSearchResults.enumerated()), id: \.element.id) { index, torrent in
                        searchResultCard(torrent: torrent, index: index)
                            .onAppear {
                                viewModel.loadMoreResultsIfNeeded(currentIndex: index)
                            }
                    }
                }
                .padding(.vertical, 10)  // 添加顶部和底部内边距
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 30)
    }
    
    // 单个搜索结果卡片
    @ViewBuilder
    private func searchResultCard(torrent: Torrent, index: Int) -> some View {
        Button(action: {
            print("🔵 [MediaDetailView] 点击下载资源: \(torrent.title ?? "未知")")
            pendingDownload = torrent
            showDownloadConfirm = true
        }) {
            VStack(alignment: .leading, spacing: 14) {
                // 标题和站点
                HStack(spacing: 12) {
                    // 序号
                    Text("#\(index + 1)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: 50)
                    
                    // 标题
                    if let title = torrent.title {
                        Text(title)
                            .font(FontTokens.buttonText)
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 站点名称
                    if let siteName = torrent.torrentInfo?.siteName {
                        Text(siteName)
                            .font(.system(size: 18))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(6)
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                }
                
                // 详细信息
                HStack(spacing: 20) {
                    // 文件大小
                    Label {
                        Text(torrent.sizeText)
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.green)
                }
                
                // 做种人数
                if let seeders = torrent.torrentInfo?.seeders {
                    Label {
                        Text("\(seeders) 做种")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                    } icon: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                // 发布时间
                Label {
                    Text(formatDate(torrent.pubdate))
                        .font(.system(size: 18))
                        .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
            }
            
            // 标签（含 meta 标签 + torrent_info.label）
            let tags = buildTags(for: torrent)
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags) { tag in
                            Text(tag.text)
                                .font(.system(size: 14))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tagBackground(for: tag.kind))
                                .cornerRadius(5)
                                .foregroundColor(ColorTokens.textPrimary)
                        }
                    }
                }
            }
            }
            .padding(20)
            .cornerRadius(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SearchResultCardButtonStyle())
        .focused($focusedResultId, equals: torrent.id)  // 绑定焦点状态
    }
    
    // 标签聚合与去重
    private func buildTags(for torrent: Torrent) -> [TagDisplay] {
        var ordered: [TagDisplay] = []
        var seen = Set<String>()
        func append(_ text: String, kind: TagKind) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            ordered.append(TagDisplay(text: trimmed, kind: kind))
        }
        if let meta = torrent.metaInfo {
            for tag in getMetaTags(from: meta) { append(tag, kind: .meta) }
        }
        if let labels = torrent.torrentInfo?.label {
            for label in labels { append(label, kind: .label) }
        }
        return ordered
    }

    // 构建季卡片数据
    private func buildSeasonCards(detail: MediaDetail) -> [SeasonCard] {
        print("🔍 [MediaDetailView] buildSeasonCards - 开始构建季卡片")
        print("   标题: \(detail.title)")
        print("   类型: \(detail.type ?? "未知")")
        print("   seasons 是否存在: \(detail.seasons != nil)")
        print("   seasonInfo 是否存在: \(detail.seasonInfo != nil)")
        
        guard let seasons = detail.seasons else {
            print("❌ [MediaDetailView] buildSeasonCards - seasons 为 nil")
            return []
        }
        
        guard let seasonInfos = detail.seasonInfo else {
            print("❌ [MediaDetailView] buildSeasonCards - seasonInfo 为 nil")
            return []
        }
        
        if seasons.isEmpty {
            print("⚠️ [MediaDetailView] buildSeasonCards - seasons 字典为空")
            return []
        }
        
        if seasonInfos.isEmpty {
            print("⚠️ [MediaDetailView] buildSeasonCards - seasonInfo 数组为空")
            return []
        }
        
        print("✅ [MediaDetailView] buildSeasonCards - seasons 包含 \(seasons.count) 个季度")
        print("   seasons keys: \(seasons.keys.sorted())")
        print("✅ [MediaDetailView] buildSeasonCards - seasonInfo 包含 \(seasonInfos.count) 条记录")
        for (index, info) in seasonInfos.enumerated() {
            print("   [\(index)] season_number: \(info.seasonNumber ?? -1), name: \(info.name ?? "无"), episode_count: \(info.episodeCount ?? 0)")
        }
        
        var cards: [SeasonCard] = []
        
        // 遍历 seasons 字典的 key（季号）
        let sortedKeys = seasons.keys.compactMap { Int($0) }.sorted()
        print("🔍 [MediaDetailView] buildSeasonCards - 排序后的季号: \(sortedKeys)")
        
        for key in sortedKeys {
            // 在 season_info 中查找对应的 season_number
            if let info = seasonInfos.first(where: { $0.seasonNumber == key }) {
                // 计算下载状态
                let downloadStatus = calculateDownloadStatus(
                    seasonNumber: key,
                    totalEpisodes: info.episodeCount ?? 0,
                    existingEpisodes: viewModel.seasonsExistData[String(key)] ?? []
                )
                
                // 获取订阅状态
                let isSubscribed = viewModel.seasonSubscriptionStatus[key] ?? false
                
                let card = SeasonCard(
                    id: String(key),
                    seasonNumber: key,
                    name: key == 0 ? "特别篇" : "第 \(key) 季",
                    episodeCount: info.episodeCount ?? 0,
                    airDate: info.airDate,
                    downloadStatus: downloadStatus,
                    isSubscribed: isSubscribed
                )
                cards.append(card)
                print("   ✅ 添加季卡片: \(card.name), \(card.episodeCount)集, 状态: \(downloadStatus.text), 订阅: \(isSubscribed ? "是" : "否")")
            } else {
                print("   ⚠️ 未找到季号 \(key) 对应的 season_info")
            }
        }
        
        print("🎬 [MediaDetailView] buildSeasonCards - 完成，共构建 \(cards.count) 个季卡片")
        return cards
    }
    
    // 计算季的下载状态
    private func calculateDownloadStatus(seasonNumber: Int, totalEpisodes: Int, existingEpisodes: [Int]) -> DownloadStatus {
        if existingEpisodes.isEmpty {
            return .missing
        } else if existingEpisodes.count >= totalEpisodes {
            return .complete
        } else {
            return .partial
        }
    }

    // 主创表格数据聚合：一行一个角色
    private func crewItems(detail: MediaDetail) -> [CrewItem] {
        let crew = viewModel.credits?.crew ?? []

        // Build name → profileURL lookup from TMDB crew members
        var crewProfileMap: [String: URL] = [:]
        for member in crew {
            if let url = member.profileURL {
                crewProfileMap[member.name.lowercased()] = url
            }
        }

        var items: [CrewItem] = []
        var seen = Set<String>()  // dedup key: "role|name"

        func append(role: String, name: String, profileURL: URL? = nil) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = role.lowercased() + "|" + trimmed.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            let url = profileURL ?? crewProfileMap[trimmed.lowercased()]
            items.append(CrewItem(role: chineseJobLabel(role), name: trimmed, profileURL: url))
        }

        // Directors: from directorsData first (has profile images for both TMDB & Douban)
        if let directors = detail.directorsData {
            for person in directors {
                guard let name = person.name else { continue }
                append(role: "Director", name: name, profileURL: person.profileURL)
            }
        }
        // Directors from TMDB crew
        for member in crew {
            guard let job = member.job?.lowercased(), job.contains("director") else { continue }
            append(role: "Director", name: member.name, profileURL: member.profileURL)
        }

        // Other crew roles
        let roleMatchers: [(String, (String) -> Bool)] = [
            ("Writer", { j in j.contains("writer") || j.contains("screenplay") || j.contains("story") }),
            ("Producer", { j in j.contains("producer") }),
            ("Editor", { j in j.contains("editor") }),
            ("Cinematography", { j in j.contains("cinematograph") || j.contains("photograph") }),
            ("Music", { j in j.contains("music") || j.contains("composer") }),
        ]
        for (role, predicate) in roleMatchers {
            for member in crew {
                guard let job = member.job?.lowercased(), predicate(job) else { continue }
                append(role: role, name: member.name, profileURL: member.profileURL)
            }
        }

        return Array(items.prefix(18))
    }

    private func getMetaTags(from metaInfo: MetaInfo) -> [String] {
        var tags: [String] = []
        if let resolution = metaInfo.resourcePix { tags.append(resolution) }
        if let videoCodec = metaInfo.videoEncode { tags.append(videoCodec) }
        if let audioCodec = metaInfo.audioEncode { tags.append(audioCodec) }
        if let effect = metaInfo.resourceEffect { tags.append(effect) }
        if let resourceType = metaInfo.resourceType { tags.append(resourceType) }
        if let edition = metaInfo.edition { tags.append(edition) }
        return tags
    }

    private func tagBackground(for kind: TagKind) -> Color {
        switch kind {
        case .meta:
            return Color.blue.opacity(0.3)
        case .label:
            return Color.green.opacity(0.35)
        }
    }
    
    // 使用 Infuse 播放
    // 注意：根据 Infuse 官方文档，仅支持 TMDB ID
    // 参考：https://support.firecore.com/hc/zh-cn/articles/215090997
    private func openInInfuse(tmdbOverride: Int? = nil) {
        // Infuse 官方支持的 URL scheme:
        // 电影: infuse://movie/{tmdb_id}
        // 电视剧: infuse://series/{tmdb_id}
        // 优先级: TMDB ID > Title Search
        
        let infuseURLString: String
        var usedIDType = ""
        var usedIDValue = ""
        
        // 优先级 1：TMDB ID（Infuse 官方唯一支持的直链方式）
        if let tmdbId = tmdbOverride ?? media.tmdbId {
            let idValue = String(tmdbId)
            if media.type == "电影" {
                infuseURLString = "infuse://movie/\(idValue)"
            } else if media.type == "电视剧" {
                infuseURLString = "infuse://series/\(idValue)"
            } else {
                infuseURLString = "infuse://movie/\(idValue)"
            }
            usedIDType = "TMDB ID"
            usedIDValue = idValue
            print("🔵 [MediaDetailView] Infuse 优先级 1 - 使用 TMDB ID: \(idValue)")
        }
        // 优先级 2：标题搜索（备选方案）
        else {
            // 注意：只使用标题，不带年份，避免 Infuse 搜索解析问题
            let searchQuery = media.title
            
            guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("❌ [MediaDetailView] 无法编码搜索关键词: \(searchQuery)")
                return
            }
            
            infuseURLString = "infuse://search?query=\(encodedQuery)"
            usedIDType = "Title Search"
            usedIDValue = searchQuery
            print("🟡 [MediaDetailView] Infuse 优先级 2 - 使用标题搜索: \(searchQuery)")
        }
        
        guard let infuseURL = URL(string: infuseURLString) else {
            print("❌ [MediaDetailView] 无法创建 Infuse URL: \(infuseURLString)")
            return
        }
        
        // 在 tvOS 上使用 UIApplication 打开 URL
        #if os(tvOS)
        UIApplication.shared.open(infuseURL, options: [:]) { success in
            if success {
                print("✅ [MediaDetailView] 成功打开 Infuse - 方法: \(usedIDType), 值: \(usedIDValue)")
            } else {
                print("❌ [MediaDetailView] 打开 Infuse 失败，请确保已安装 Infuse 应用 - 方法: \(usedIDType), 值: \(usedIDValue)")
            }
        }
        #endif
    }
    
    // 通过 TMDB 搜索接口获取 TMDB ID（用于豆瓣来源缺失 TMDB ID 的场景）
    private func lookupTmdbIdIfNeeded() async {
        if tmdbLookupInProgress { return }
        if media.tmdbId != nil || resolvedTmdbId != nil { return }
        let lookupKey = tmdbLookupCacheKey()
        if let cached = LocalCacheManager.shared.getCachedTmdbId(for: lookupKey) {
            await MainActor.run { resolvedTmdbId = cached }
            print("♻️ [MediaDetailView] 使用已缓存的 TMDB ID: \(cached) key=\(lookupKey)")
            return
        }
        let apiKey = AuthenticationManager.shared.tmdbApiKey
        guard !apiKey.isEmpty else {
            await MainActor.run { showTmdbKeyAlert = true }
            return
        }
        await MainActor.run { tmdbLookupInProgress = true }
        defer { Task { @MainActor in tmdbLookupInProgress = false } }

        print("🔵 [MediaDetailView] 触发 TMDB ID 查询 key=\(lookupKey) title=\(media.title) year=\(media.year ?? "-") type=\(media.type ?? "未知")")
        
        let isTV = media.type == "电视剧"
        let endpoint = isTV ? "tv" : "movie"
        var components = URLComponents(string: "https://api.themoviedb.org/3/search/\(endpoint)")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: media.title),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: "zh-CN")
        ]
        if let yearString = media.year, let year = Int(yearString) {
            items.append(URLQueryItem(name: isTV ? "first_air_date_year" : "year", value: "\(year)"))
        }
        components.queryItems = items
        guard let url = components.url else {
            print("❌ [MediaDetailView] 无法构建 TMDB 查询 URL key=\(lookupKey)")
            return
        }
        print("🌐 [MediaDetailView] TMDB 查询 URL: \(url.absoluteString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TmdbSearchResponse.self, from: data)
            if let id = response.results.first?.id {
                await MainActor.run { resolvedTmdbId = id }
                LocalCacheManager.shared.cacheTmdbId(id, for: lookupKey)
                print("✅ [MediaDetailView] TMDB ID 自动解析成功: \(id) 已缓存 key=\(lookupKey)")
            } else {
                print("⚠️ [MediaDetailView] TMDB 搜索无结果，标题: \(media.title)")
            }
        } catch {
            print("❌ [MediaDetailView] TMDB ID 解析失败: \(error)")
        }
    }

    private func tmdbLookupCacheKey() -> String {
        if let doubanId = media.doubanId, !doubanId.isEmpty {
            return "douban_\(doubanId)"
        }
        var parts: [String] = [media.title.lowercased()]
        if let year = media.year { parts.append(year) }
        if let type = media.type { parts.append(type) }
        return parts.joined(separator: "_")
    }
    
    private struct TmdbSearchResponse: Decodable {
        let results: [TmdbSearchResult]
    }
    
    private struct TmdbSearchResult: Decodable {
        let id: Int
    }
    
    // 格式化日期
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    // MARK: - 剧集详情面板
    
    @ViewBuilder
    private func seasonDetailPanel(season: SeasonCard) -> some View {
        // 使用实时的订阅状态，而不是传入的快照值
        let currentIsSubscribed = viewModel.seasonSubscriptionStatus[season.seasonNumber] ?? false
        
        ZStack {
            // 半透明背景
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    showSeasonPanel = false
                }
                .allowsHitTesting(true)  // 确保背景可以拦截交互
                .focusable(false)  // 背景不可聚焦
            
            // 面板内容
            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    Text(season.name)
                        .font(FontTokens.sectionTitle)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    // 订阅按钮
                    Button(action: {
                        showSubscribeConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isSubscribing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: currentIsSubscribed ? "heart.fill" : "heart")
                                    .font(.system(size: 18))
                            }
                            Text(currentIsSubscribed ? "取消订阅" : "订阅")
                                .font(FontTokens.castName)
                        }
                        .frame(width: 160, height: 50)
                        .background(currentIsSubscribed ? Color.pink.opacity(0.9) : Color.purple.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .buttonStyle(ScaleFocusButtonStyle())
                    .focused($focusedEpisodeButton, equals: true)
                    .disabled(viewModel.isSubscribing)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                Divider()
                    .background(ColorTokens.divider)
                
                // 剧集列表
                if viewModel.isLoadingEpisodes {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("加载中...")
                            .font(.system(size: 20))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if viewModel.episodes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "film")
                            .font(.system(size: 62))
                            .foregroundColor(ColorTokens.textMuted)
                        Text("暂无剧集信息")
                            .font(FontTokens.detailBody)
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.episodes) { episode in
                                episodeCard(episode: episode)
                            }
                        }
                        .padding(40)
                    }
                    .clipped()  // 确保超出部分不可见
                }
            }
            .frame(width: 1400, height: 900)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
            )
            .clipped()  // 确保内容不会溢出面板
            .focusSection()  // 将面板设置为独立焦点区域
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedEpisodeButton = true
            }
        }
        .onExitCommand {
            showSeasonPanel = false
        }
        .alert(currentIsSubscribed ? "取消订阅" : "订阅", isPresented: $showSubscribeConfirm) {
            Button(currentIsSubscribed ? "取消订阅" : "确认订阅", role: currentIsSubscribed ? .destructive : nil) {
                let targetSeason = season.seasonNumber
                let wasSubscribed = currentIsSubscribed
                Task {
                    await viewModel.toggleSeasonSubscription(
                        seasonNumber: targetSeason,
                        isCurrentlySubscribed: wasSubscribed
                    )
                    
                    // 立即更新本地订阅状态（参照hero按钮组逻辑）
                    await MainActor.run {
                        viewModel.seasonSubscriptionStatus[targetSeason] = !wasSubscribed
                        
                        // 更新selectedSeason以触发面板刷新
                        if var updatedSeason = selectedSeason {
                            updatedSeason.isSubscribed = !wasSubscribed
                            selectedSeason = updatedSeason
                        }
                        
                        // 显示成功提示
                        viewModel.successMessage = wasSubscribed ? "已取消订阅 \(season.name)" : "已订阅 \(season.name)"
                        viewModel.showSuccessAlert = true
                        
                        // 1秒后自动关闭提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            viewModel.showSuccessAlert = false
                        }
                    }
                    
                    // 注释掉这个调用，因为它会使用缓存的旧数据覆盖我们的更新
                    // if let detail = viewModel.mediaDetail, let source = media.source?.lowercased(), let id = media.tmdbId {
                    //     await viewModel.checkSeasonSubscriptions(source: source.contains("tmdb") ? "tmdb" : "douban", id: String(id), title: media.title)
                    // }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            if currentIsSubscribed {
                Text("确定要取消订阅 \(season.name) 吗？")
            } else {
                Text("确定要订阅 \(season.name) 吗？系统将自动追踪并下载新更新的剧集。")
            }
        }
    }
    
    @ViewBuilder
    private func episodeCard(episode: Episode) -> some View {
        Button(action: {
            // 可以在这里添加剧集点击后的操作，比如播放
            print("🔵 [MediaDetailView] 点击剧集: 第\(episode.episodeNumber)集 - \(episode.name)")
        }) {
            HStack(alignment: .top, spacing: 20) {
                // 剧集截图
                if let stillURL = episode.stillURL {
                    CachedAsyncImage(url: stillURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 160)
                                .cornerRadius(10)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 280, height: 160)
                                .cornerRadius(10)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(ColorTokens.textDim)
                                )
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 280, height: 160)
                        .cornerRadius(10)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(ColorTokens.textDim)
                        )
                }
                
                // 剧集信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("第 \(episode.episodeNumber) 集")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text(episode.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(1)
                    }
                    
                    if let airDate = episode.airDate {
                        Text("首播：\(airDate)")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.system(size: 20))
                            .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                            .lineLimit(nil)  // 改为不限制行数，聚焦时可以完整查看
                            .lineSpacing(4)
                    } else {
                        Text("暂无简介")
                            .font(.system(size: 20))
                            .foregroundColor(ColorTokens.textDim)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surfaceCard)
            )
        }
        .buttonStyle(SoftFocusButtonStyle())  // 添加聚焦效果
        .focused($focusedEpisodeId, equals: episode.episodeNumber)  // 绑定焦点
    }
    
    // MARK: - 季卡片按钮
    
    @ViewBuilder
    private func seasonCardButton(card: SeasonCard, detail: MediaDetail) -> some View {
        Button(action: {
            print("🔵 [MediaDetailView] ===== 按钮 Action 触发 =====")
            print("   季名称: \(card.name)")
            print("   季号: \(card.seasonNumber)")
            print("   集数: \(card.episodeCount)")
            print("   detail.tmdbId: \(detail.tmdbId ?? 0)")
            print("   showSeasonPanel 当前值: \(showSeasonPanel)")
            
            selectedSeason = card
            print("   已设置 selectedSeason")
            
            showSeasonPanel = true
            print("   已设置 showSeasonPanel = true")
            
            // 获取剧集列表
            if let tmdbId = detail.tmdbId {
                print("   开始调用 loadEpisodes(tmdbId: \(tmdbId), seasonNumber: \(card.seasonNumber))")
                Task {
                    print("   Task 开始执行")
                    await viewModel.loadEpisodes(tmdbId: tmdbId, seasonNumber: card.seasonNumber)
                    print("   Task 执行完成")
                }
            } else {
                print("❌ [MediaDetailView] detail.tmdbId 为 nil，无法加载剧集")
            }
            print("🔵 [MediaDetailView] ===== 按钮 Action 完成 =====")
        }) {
            VStack(alignment: .center, spacing: 20) {
                // 第一行：第x季 和 总集数，居中加大间距
                HStack(spacing: 32) {  // 进一步加大间距
                    Text(card.name)
                        .font(.system(size: 21, weight: .semibold))  // 加大一号
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(card.episodeCount)集")
                        .font(FontTokens.castCharacter)
                        .foregroundColor(ColorTokens.textPrimary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .center)  // 居中
                
                // 第二行：状态标签，加大间隔
                HStack(spacing: 24) {  // 进一步加大间隔
                    // 下载状态标签
                    HStack(spacing: 4) {  // 稍微加大内部间距
                        Circle()
                            .fill(card.downloadStatus.color)
                            .frame(width: 7, height: 7)  // 稍微加大
                        Text(card.downloadStatus.text)
                            .font(.system(size: 15, weight: .medium))  // 加大一号
                            .foregroundColor(card.downloadStatus.color)
                    }
                    .padding(.horizontal, 10)  // 加大padding
                    .padding(.vertical, 5)
                    .background(card.downloadStatus.color.opacity(0.15))
                    .cornerRadius(4)
                    
                    // 订阅状态标签
                    HStack(spacing: 4) {
                        Image(systemName: card.isSubscribed ? "heart.fill" : "heart")
                            .font(.system(size: 11))  // 加大一号
                            .foregroundColor(card.isSubscribed ? .pink : .gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((card.isSubscribed ? Color.pink : Color.gray).opacity(0.15))
                    .cornerRadius(4)
                }
                .frame(maxWidth: .infinity, alignment: .center)  // 居中对齐
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surfaceCard)
            )
        }
        .buttonStyle(SoftFocusButtonStyle())  // 改回使用 SoftFocusButtonStyle，它已经包含了焦点效果
        .onAppear {
            print("🟢 [MediaDetailView] 季卡片出现: \(card.name)")
        }
    }
}

struct MediaDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MediaDetailView(media: MediaItem(
            tmdbId: 83533,
            imdbId: nil,
            doubanId: nil,
            title: "阿凡达：火与烬",
            originalTitle: "Avatar: Fire and Ash",
            overview: "电影简介...",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8.5,
            releaseDate: "2025-12-17",
            type: "电影",
            year: "2025",
            originalLanguage: "en",
            source: "themoviedb"
        ))
    }
}
