import SwiftUI

struct SettingsView: View {
    @Binding var showLogoutAlert: Bool
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var userInfo: UserInfo?
    @State private var isLoading = false
    @State private var tmdbApiKey: String = ""
    @State private var isEditingTmdbKey = false
    @FocusState private var isTmdbKeyFocused: Bool
    @FocusState private var isHomeStatusMenuFocused: Bool
    @FocusState private var isLogoutButtonFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("设置")
                    .font(FontTokens.pageTitle)
                    .padding(.top, 60)

                // 用户信息区域
                VStack(alignment: .leading, spacing: 20) {
                    Text("用户信息")
                        .font(FontTokens.settingsSectionTitle)
                        .foregroundColor(ColorTokens.textPrimary)

                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(ColorTokens.surfaceCard)
                        .cornerRadius(12)
                    } else if let user = userInfo {
                        HStack(spacing: 30) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(ColorTokens.accent)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(user.name)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(ColorTokens.textPrimary)
                                Text(user.email ?? "无邮箱信息")
                                    .font(.system(size: 20))
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(30)
                        .background(ColorTokens.surfaceCard)
                        .cornerRadius(12)
                    } else {
                        Text("无法获取用户信息")
                            .foregroundColor(ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(30)
                            .background(ColorTokens.surfaceCard)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 80)

                // 服务器信息区域
                VStack(alignment: .leading, spacing: 20) {
                    Text("服务器信息")
                        .font(FontTokens.settingsSectionTitle)
                        .foregroundColor(ColorTokens.textPrimary)

                    VStack(spacing: 16) {
                        // API 地址
                        HStack {
                            Text("API 地址")
                                .font(FontTokens.settingsValue)
                                .foregroundColor(ColorTokens.textPrimary)
                            Spacer()
                            Text(authManager.apiEndpoint)
                                .font(.system(size: 18))
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .padding(24)
                        .background(ColorTokens.surfaceCard)
                        .cornerRadius(12)

                        // TMDB API KEY
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("TMDB API KEY")
                                    .font(FontTokens.settingsValue)
                                    .foregroundColor(ColorTokens.textPrimary)
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
                                        .font(FontTokens.buttonSmall)
                                        .foregroundColor(tmdbApiKey.isEmpty ? ColorTokens.warning : ColorTokens.success)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            Text("用于豆瓣来源的影片自动查询 TMDB ID，以支持 Infuse 跳转播放。")
                                .font(FontTokens.caption)
                                .foregroundColor(ColorTokens.textSecondary)

                            if isEditingTmdbKey {
                                VStack(spacing: 16) {
                                    TextField("请输入 TMDB API KEY", text: $tmdbApiKey)
                                        .font(.system(size: 18))
                                        .focused($isTmdbKeyFocused)
                                        .padding(12)
                                        .background(ColorTokens.surfaceHover)
                                        .cornerRadius(10)
                                        .onSubmit {
                                            saveTmdbApiKey()
                                        }

                                    HStack(spacing: 16) {
                                        Button(action: {
                                            saveTmdbApiKey()
                                        }) {
                                            Text("保存")
                                                .font(FontTokens.buttonSmall)
                                                .foregroundColor(ColorTokens.textPrimary)
                                                .frame(width: 140, height: 50)
                                                .background(ColorTokens.accent)
                                                .cornerRadius(10)
                                        }

                                        Button(action: {
                                            tmdbApiKey = authManager.tmdbApiKey
                                            isEditingTmdbKey = false
                                        }) {
                                            Text("取消")
                                                .font(FontTokens.buttonSmall)
                                                .foregroundColor(ColorTokens.textPrimary)
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
                        .background(ColorTokens.surfaceCard)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 80)

                // 显示设置
                VStack(alignment: .leading, spacing: 20) {
                    Text("显示设置")
                        .font(FontTokens.settingsSectionTitle)
                        .foregroundColor(ColorTokens.textPrimary)

                    VStack(spacing: 16) {
                        HStack {
                            Text("首页系统状态栏")
                                .font(FontTokens.settingsValue)
                                .foregroundColor(ColorTokens.textPrimary)
                            Spacer()
                            Menu {
                                ForEach(HomeSystemStatusMode.allCases, id: \.self) { mode in
                                    Button(action: { authManager.saveHomeSystemStatusMode(mode) }) {
                                        HStack(spacing: 8) {
                                            Text(mode.displayName)
                                            if authManager.homeSystemStatusMode == mode {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(authManager.homeSystemStatusMode.displayName)
                                        .font(FontTokens.settingsValue)
                                        .foregroundColor(ColorTokens.textPrimary)
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(ColorTokens.textPrimary)
                                }
                                .padding(12)
                                .background(ColorTokens.surfaceCard)
                                .cornerRadius(12)
                            }
                            .focused($isHomeStatusMenuFocused)
                            .onMoveCommand { direction in
                                if direction == .down {
                                    isLogoutButtonFocused = true
                                }
                            }
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
                            .font(FontTokens.settingsValue)
                        Text("退出登录")
                            .font(FontTokens.buttonText)
                    }
                    .foregroundColor(ColorTokens.textPrimary)
                    .frame(width: 300, height: 60)
                    .background(ColorTokens.danger.opacity(0.8))
                    .cornerRadius(12)
                }
                .focused($isLogoutButtonFocused)
                .onMoveCommand { direction in
                    if direction == .up {
                        isHomeStatusMenuFocused = true
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .background(ColorTokens.appBackground)
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showLogoutAlert: .constant(false))
    }
}
