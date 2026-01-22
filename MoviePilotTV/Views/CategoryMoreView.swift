//
//  CategoryMoreView.swift
//  MoviePilotTV
//
//  Created on 2026-01-22.
//

import SwiftUI

struct CategoryMoreView: View {
    let source: String
    let categoryTitle: String
    
    @StateObject private var viewModel: CategoryMoreViewModel
    @FocusState private var focusedItemId: Int?
    @State private var lastFocusedItemId: Int?  // 保存上次聚焦的卡片
    @Environment(\.presentationMode) var presentationMode
    
    init(source: String, categoryTitle: String) {
        self.source = source
        self.categoryTitle = categoryTitle
        _viewModel = StateObject(wrappedValue: CategoryMoreViewModel(source: source, categoryTitle: categoryTitle))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.allMedia.isEmpty {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("加载中...")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            // 标题
                            Text(categoryTitle)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 80)
                                .padding(.top, 60)
                            
                            // Grid 布局
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 40)
                            ], spacing: 40) {
                                ForEach(viewModel.allMedia) { media in
                                    NavigationLink(value: media) {
                                        CategoryMediaCard(media: media)
                                            .focused($focusedItemId, equals: media.id)
                                            .id(media.id)  // 用于 ScrollViewReader
                                    }
                                    .buttonStyle(CardButtonStyle())
                                    .onAppear {
                                        // 当最后几项出现时，加载下一页
                                        if media.id == viewModel.allMedia.suffix(10).first?.id {
                                            Task {
                                                await viewModel.loadNextPage()
                                            }
                                        }
                                    }
                                }
                                
                                // 加载更多指示器
                                if viewModel.isLoadingMore {
                                    VStack {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                        Text("加载中...")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 10)
                                    }
                                    .frame(width: 200, height: 300)
                                } else if !viewModel.hasMorePages && !viewModel.allMedia.isEmpty {
                                    VStack {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                        Text("全部加载完成")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 10)
                                    }
                                    .frame(width: 200, height: 300)
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.bottom, 60)
                        }
                    }
                    .onChange(of: focusedItemId) { newValue in
                        // 保存当前聚焦的卡片 ID
                        if let newValue = newValue {
                            lastFocusedItemId = newValue
                        }
                    }
                    .onAppear {
                        // 恢复上次的焦点位置（延迟避免和系统冲突）
                        if let lastId = lastFocusedItemId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: MediaItem.self) { media in
            MediaDetailView(media: media)
        }
        .onAppear {
            viewModel.loadInitialData()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Category Media Card Component

private struct CategoryMediaCard: View {
    let media: MediaItem
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // 海报图片 - 与 HomeView 的 MediaCard 保持一致
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
                
                // 评分徽章 - 右上角
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
            
            // 标题 - 居中对齐
            Text(media.title)
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // 年份 - 居中对齐
            if let year = media.year {
                Text(String(year))
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview

struct CategoryMoreView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CategoryMoreView(source: "tmdb_trending", categoryTitle: "TMDB 流行趋势")
        }
    }
}
