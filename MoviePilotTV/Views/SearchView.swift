//
//  SearchView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search Header
                VStack(spacing: 18) {
                    Text("搜索影片")
                        .font(FontTokens.pageTitle)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(ColorTokens.textMuted)
                        
                        TextField("输入电影或电视剧名称", text: $viewModel.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                viewModel.performSearch()
                            }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: {
                                viewModel.searchQuery = ""
                                viewModel.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ColorTokens.surfaceFocused)
                    .cornerRadius(10)
                    .frame(maxWidth: 700)
                }
                .padding(.horizontal, 55)
                .padding(.vertical, 25)
                
                Divider()
                    .background(ColorTokens.divider)
                    .padding(.horizontal, 55)
                
                // Search Results
                if viewModel.isSearching {
                    LoadingView("搜索中...")
                        .frame(height: 400)
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    EmptyStateView(icon: "film.stack", title: "未找到相关内容")
                } else if viewModel.searchResults.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "搜索电影或电视剧")
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 250), spacing: 32)
                        ],
                        spacing: 40
                    ) {
                        ForEach(viewModel.searchResults) { media in
                            NavigationLink(destination: MediaDetailView(media: media)) {
                                SearchResultCard(media: media)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.horizontal, 55)
                    .padding(.vertical, 44) // 为放大预留更多上下空间，避免裁切
                    .focusSection()  // 添加焦点区域
                    
                    // Bottom spacing
                    Color.clear.frame(height: 60)
                }
            }
        }
        .background(ColorTokens.appBackground)
        .onAppear {
            // 只有在没有搜索结果时才自动聚焦搜索框
            if viewModel.searchResults.isEmpty {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: viewModel.searchResults) { oldValue, newValue in
            // 当搜索结果从有变为无时，重新聚焦搜索框
            if oldValue.count > 0 && newValue.isEmpty {
                isSearchFieldFocused = true
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

struct SearchResultCard: View {
    let media: MediaItem
    
    var body: some View {
        MediaCard(media: media)
            .frame(width: 250)
    }
}

struct SubscribeSheet: View {
    let media: MediaItem
    let onSubscribe: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: Int = 1
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("订阅影片")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 30) {
                    // Poster
                    if let posterURL = media.posterURL {
                        CachedAsyncImage(url: posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(2/3, contentMode: .fit)
                                    .frame(width: 200)
                                    .cornerRadius(12)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 300)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 15) {
                        Text(media.displayTitle)
                            .font(.title)
                            .foregroundColor(.white)
                        
                        if let overview = media.overview {
                            Text(overview)
                                .font(.body)
                                .foregroundColor(ColorTokens.textMuted)
                                .lineLimit(5)
                        }
                        
                        // Season Picker for TV Shows
                        if media.mediaType == "tv" {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("选择季度")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Picker("Season", selection: $selectedSeason) {
                                    ForEach(1...10, id: \.self) { season in
                                        Text("第 \(season) 季").tag(season)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        HStack(spacing: 20) {
                            Button("取消") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("订阅") {
                                let season = media.mediaType == "tv" ? selectedSeason : nil
                                onSubscribe(season)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: 400)
                }
                .padding(40)
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
