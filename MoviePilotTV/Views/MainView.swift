//
//  MainView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

enum NavigationItem: String, CaseIterable {
    case home = "首页"
    case search = "搜索"
    case recommend = "推荐"
    case subscriptions = "订阅"
    case downloads = "下载管理"
    case sites = "站点"
    case settings = "设置"
}

struct MainView: View {
    @State private var selectedTab: NavigationItem = .home
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var systemStatusViewModel = SystemStatusViewModel()
    @State private var showLogoutAlert = false
    @FocusState private var focusedTab: NavigationItem?
    @Binding var deepLinkMedia: MediaItem?
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                HomeView(systemStatusViewModel: systemStatusViewModel)
                    .navigationDestination(for: MediaItem.self) { media in
                        MediaDetailView(media: media)
                    }
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(NavigationItem.home)
            
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .tag(NavigationItem.search)
            
            NavigationStack {
                RecommendView()
            }
            .tabItem {
                Label("推荐", systemImage: "star.fill")
            }
            .tag(NavigationItem.recommend)
            
            NavigationStack {
                SubscriptionsView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("订阅", systemImage: "bookmark.fill")
            }
            .tag(NavigationItem.subscriptions)
            .focused($focusedTab, equals: .subscriptions)
            
            NavigationStack {
                DownloadsView()
            }
            .tabItem {
                Label("下载", systemImage: "arrow.down.circle.fill")
            }
            .tag(NavigationItem.downloads)
            
            NavigationStack {
                SitesView()
            }
            .tabItem {
                Label("站点", systemImage: "server.rack")
            }
            .tag(NavigationItem.sites)
            
            NavigationStack {
                SettingsView(showLogoutAlert: $showLogoutAlert)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
            .tag(NavigationItem.settings)
        }
        .onAppear {
            // 仅在首页且设置开启时启动系统状态更新
            if selectedTab == .home && authManager.showHomeSystemStatus {
                systemStatusViewModel.startUpdating()
            }
        }
        .onChange(of: selectedTab) { newValue in
            // 仅在设置开启时控制系统状态更新
            if authManager.showHomeSystemStatus {
                if newValue == .home {
                    systemStatusViewModel.startUpdating()
                } else {
                    systemStatusViewModel.stopUpdating()
                }
            }
            // 当切换 tab 时，设置焦点到该 tab item
            focusedTab = newValue
        }
        .onChange(of: deepLinkMedia) { media in
            print("🎯 [MainView] deepLinkMedia onChange 被触发")
            if let media = media {
                print("🎯 [MainView] 媒体数据: \(media.title)")
                // 切换到首页
                selectedTab = .home
                // 清空导航路径并推入新媒体
                navigationPath = NavigationPath()
                navigationPath.append(media)
                print("✅ [MainView] 深链接导航已设置 - 已推入媒体到导航堆栈")
                // 清空 deepLinkMedia 以便下次使用
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    deepLinkMedia = nil
                }
            } else {
                print("⚠️ [MainView] deepLinkMedia 为 nil")
            }
        }
        .alert("退出登录", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("确认退出", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("确定要退出登录吗?")
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(deepLinkMedia: .constant(nil))
    }
}