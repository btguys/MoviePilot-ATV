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
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("来自 TMDB 和豆瓣的精选内容")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 25)
                .padding(.horizontal, 90)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 90)
                
                // Content
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("正在加载推荐内容...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        Spacer()
                    }
                    .frame(height: 400)
                } else if viewModel.sections.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "star.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无推荐内容")
                            .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .padding(.top, 15)
                        Spacer()
                    }
                    .frame(height: 400)
                } else {
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(viewModel.sections) { section in
                            RecommendSectionView(section: section)
                        }
                        
                        // Bottom spacing
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 90)
                    .padding(.top, 30)
                }
            }
        }
        .background(Color.black)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(section.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, 30)
            
            // 使用 LazyHStack 而不是 ScrollView 来改善焦点行为
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(section.items) { item in
                        NavigationLink(destination: MediaDetailView(media: item)) {
                            MediaCard(media: item)
                                .frame(width: 220)
                        }
                        .buttonStyle(.card)
                    }
                }
                        .padding(.vertical, 20) // 放大时留出更多上下空间，避免裁切
                .padding(.horizontal, 30)
            }
            .focusSection()
        }
    }
}

struct RecommendView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendView()
    }
}
