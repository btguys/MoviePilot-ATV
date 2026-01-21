//
//  SubscriptionsView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct SubscriptionsView: View {
    @Binding var selectedTab: NavigationItem
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var selectedFilter: SubscriptionFilter = .all
    @FocusState private var focusedFilter: SubscriptionFilter?
    @State private var selectedSubscription: Subscription?
    @State private var subscriptionForMenu: Subscription?
    @State private var shouldAutoSearch = false
    @State private var navigationActive = false
    @State private var currentAutoSearch = false  // 仅用于当前导航的项
    @State private var focusedCardId: String?  // 记录当前焦点卡片
    @FocusState private var focusedCard: String?  // 焦点状态绑定
    @State private var firstCardId: String?  // 记录第一张卡片的ID
    @State private var shouldRestoreFocus = false  // 标记是否需要恢复焦点
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Filter Buttons - Centered
                    HStack {
                        Spacer()
                        HStack(spacing: 40) {
                            ForEach(SubscriptionFilter.allCases, id: \.self) { filter in
                                filterButton(for: filter)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 30)
                    
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
                            Spacer()
                        }
                        .frame(height: 400)
                    } else if viewModel.filteredSubscriptions.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "bookmark.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                            Text("暂无订阅")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                            Spacer()
                        }
                        .frame(height: 400)
                    } else {
                        subscriptionCardsView()
                            .padding(.horizontal, 90)
                            .padding(.vertical, 30)
                    }
                }
                .padding(.vertical, 20)
                .focusSection()
            }
            
            // Context Menu Overlay
            if let subscription = subscriptionForMenu {
                SubscriptionContextMenu(
                    subscription: subscription,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            subscriptionForMenu = nil
                        }
                    },
                    onSearch: {
                        currentAutoSearch = true
                        shouldAutoSearch = true
                        selectedSubscription = subscription
                        withAnimation(.easeInOut(duration: 0.2)) {
                            subscriptionForMenu = nil
                            navigationActive = true
                        }
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            subscriptionForMenu = nil
                            viewModel.deleteSubscription(subscription)
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.black)
        .onAppear {
            viewModel.loadSubscriptions()
            // 页面加载时不自动设置焦点，保持在 tab 导航上
            focusedFilter = nil
            // 如果是从详情页返回，需要恢复焦点
            if shouldRestoreFocus, let cardId = focusedCardId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusedCard = cardId
                    shouldRestoreFocus = false  // 重置标志
                }
            }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .subscriptions {
                viewModel.loadSubscriptions()
                shouldRestoreFocus = false  // 从其他tab切换过来时不恢复焦点
            }
        }
        .onChange(of: viewModel.filteredSubscriptions) { _ in
            // 当订阅列表更改时，更新第一张卡片的 ID
            if let firstSubscription = viewModel.filteredSubscriptions.first,
               let id = firstSubscription.id {
                firstCardId = String(id)
            } else {
                firstCardId = ""
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    @ViewBuilder
    private func filterButton(for filter: SubscriptionFilter) -> some View {
        Text(filter.displayName)
            .font(.system(size: 24, weight: selectedFilter == filter ? .bold : .regular))
            .foregroundColor(selectedFilter == filter ? .white : .gray)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(focusedFilter == filter ? Color.white.opacity(0.2) : Color.clear)
            )
            .scaleEffect(focusedFilter == filter ? 1.15 : 1.0)
            .shadow(color: focusedFilter == filter ? Color.white.opacity(0.4) : Color.clear, radius: focusedFilter == filter ? 8 : 0)
            .animation(.easeInOut(duration: 0.15), value: focusedFilter == filter)
            .focusable()
            .focused($focusedFilter, equals: filter)
            .onTapGesture {
                selectedFilter = filter
                viewModel.filterSubscriptions(by: filter)
            }
    }
    
    @ViewBuilder
    private func subscriptionCardsView() -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 220), spacing: 22)
            ],
            spacing: 30
        ) {
            ForEach(viewModel.filteredSubscriptions) { subscription in
                subscriptionCardItem(for: subscription)
            }
        }
        .focusSection()
    }
    
    @ViewBuilder
    private func subscriptionCardItem(for subscription: Subscription) -> some View {
        ZStack {
            NavigationLink(
                destination: MediaDetailView(
                    media: MediaItem.from(subscription),
                    shouldAutoSearch: shouldAutoSearch && selectedSubscription?.id == subscription.id
                ),
                isActive: Binding(
                    get: { navigationActive && selectedSubscription?.id == subscription.id },
                    set: { newValue in
                        if !newValue {
                            navigationActive = false
                            currentAutoSearch = false
                            shouldAutoSearch = false
                            selectedSubscription = nil
                            shouldRestoreFocus = true  // 标记需要恢复焦点
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    subscriptionForMenu = subscription
                }
            }) {
                SubscriptionCardContent(subscription: subscription)
            }
            .buttonStyle(.card)
            .focused($focusedCard, equals: String(subscription.id ?? 0))
            .onChange(of: focusedCard, initial: false) { oldValue, newValue in
                if newValue == String(subscription.id ?? 0) {
                    focusedCardId = String(subscription.id ?? 0)
                }
            }
        }
    }
}

enum SubscriptionFilter: String, CaseIterable {
    case all = "all"
    case movie = "movie"
    case tv = "tv"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .movie:
            return "电影"
        case .tv:
            return "电视剧"
        }
    }
}

struct SubscriptionCardContent: View {
    let subscription: Subscription
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // Poster
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                if let posterURL = subscription.posterURL {
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
                
                // State Badge
                VStack(alignment: .leading) {
                    HStack {
                        Text(subscription.stateText)
                            .font(.system(size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(stateColor)
                            .cornerRadius(6)
                        Spacer()
                    }
                    Spacer()
                    
                    // Progress Badge for TV Shows
                    if subscription.isTV, let progressText = subscription.progressText {
                        HStack {
                            Spacer()
                            Text(progressText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.9))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title
            Text(subscription.name ?? "未知")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Year
            if let year = subscription.year {
                Text(year)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var stateColor: Color {
        switch subscription.state {
        case "N":
            return Color.gray
        case "R":
            return Color.blue
        case "D":
            return Color.green
        default:
            return Color.gray
        }
    }
}

struct SubscriptionContextMenu: View {
    let subscription: Subscription
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onDelete: () -> Void
    
    @FocusState private var focusedButton: MenuButton?
    
    enum MenuButton {
        case search
        case delete
        case cancel
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 15) {
                Text(subscription.name ?? "未知")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 10) {
                    Button(action: onSearch) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("搜索资源")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.card)
                    .focused($focusedButton, equals: .search)
                    
                    Button(action: onDelete) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除订阅")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.red)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.card)
                    .focused($focusedButton, equals: .delete)
                }
                
                Button(action: onDismiss) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.gray)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.card)
                .focused($focusedButton, equals: .cancel)
            }
            .padding(30)
            .background(Color.black.opacity(0.9))
            .cornerRadius(16)
            .frame(maxWidth: 500)
            .focusSection()
            .onAppear {
                focusedButton = .search
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }
}

struct SubscriptionsView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionsView(selectedTab: .constant(.subscriptions))
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
