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
            if selectedTab == .home {
                systemStatusViewModel.startUpdating()
            }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .home {
                systemStatusViewModel.startUpdating()
            } else {
                systemStatusViewModel.stopUpdating()
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

// MARK: - Settings View (inlined for target membership)

struct SettingsView: View {
    @Binding var showLogoutAlert: Bool
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var userInfo: UserInfo?
    @State private var isLoading = false
    @State private var tmdbApiKey: String = ""
    @State private var isEditingTmdbKey = false
    @FocusState private var isTmdbKeyFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("设置")
                    .font(.system(size: 48, weight: .bold))
                    .padding(.top, 60)
                
                // 用户信息区域
                VStack(alignment: .leading, spacing: 20) {
                    Text("用户信息")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    } else if let user = userInfo {
                        HStack(spacing: 30) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(user.name)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(user.email ?? "无邮箱信息")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(30)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    } else {
                        Text("无法获取用户信息")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(30)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 80)
                
                // 服务器信息区域
                VStack(alignment: .leading, spacing: 20) {
                    Text("服务器信息")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        // API 地址
                        HStack {
                            Text("API 地址")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Spacer()
                            Text(authManager.apiEndpoint)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // TMDB API KEY
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("TMDB API KEY")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                Spacer()
                                if !isEditingTmdbKey {
                                    Button(action: {
                                        isEditingTmdbKey = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTmdbKeyFocused = true
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: tmdbApiKey.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill")
                                            Text(tmdbApiKey.isEmpty ? "未设置" : "已设置")
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(tmdbApiKey.isEmpty ? .orange : .green)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            Text("用于豆瓣来源的影片自动查询 TMDB ID，以支持 Infuse 跳转播放。")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            if isEditingTmdbKey {
                                VStack(spacing: 16) {
                                    TextField("请输入 TMDB API KEY", text: $tmdbApiKey)
                                        .font(.system(size: 18))
                                        .focused($isTmdbKeyFocused)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                        .onSubmit {
                                            saveTmdbApiKey()
                                        }
                                    
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            saveTmdbApiKey()
                                        }) {
                                            Text("保存")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 140, height: 50)
                                                .background(Color.blue)
                                                .cornerRadius(10)
                                        }
                                        
                                        Button(action: {
                                            tmdbApiKey = authManager.tmdbApiKey
                                            isEditingTmdbKey = false
                                        }) {
                                            Text("取消")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 140, height: 50)
                                                .background(Color.gray.opacity(0.6))
                                                .cornerRadius(10)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 80)
                
                // 调试工具
                VStack(alignment: .leading, spacing: 20) {
                    Text("Top Shelf 调试")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            print("🔧 [Debug] 手动触发 Top Shelf 数据检查")
                            TopShelfHelper.shared.debugPrintSharedData()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "ladybug")
                                    .font(.system(size: 20))
                                Text("检查数据")
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 300, height: 60)
                            .background(Color.blue.opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            print("🔧 [Debug] 手动触发 Top Shelf 刷新")
                            print("📝 [Debug] tvOS 会自动刷新 Top Shelf，请退出 app 并等待 2-3 秒")
                            print("📝 [Debug] 或者尝试切换到其他 app 再回来")
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                                Text("手动刷新")
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 300, height: 60)
                            .background(Color.orange.opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.top, 20)
                
                // 退出登录按钮
                Button(action: {
                    showLogoutAlert = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                        Text("退出登录")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 300, height: 60)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .background(Color.black)
        .task {
            await loadUserInfo()
            tmdbApiKey = authManager.tmdbApiKey
        }
    }
    
    private func loadUserInfo() async {
        isLoading = true
        defer { isLoading = false }
        do {
            userInfo = try await APIService.shared.getCurrentUser()
        } catch {
            print("加载用户信息失败: \(error)")
        }
    }
    
    private func saveTmdbApiKey() {
        authManager.saveTmdbApiKey(tmdbApiKey)
        isEditingTmdbKey = false
        print("✅ [SettingsView] TMDB API KEY 已保存")
    }
}
