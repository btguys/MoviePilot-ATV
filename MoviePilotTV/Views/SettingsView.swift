import SwiftUI

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
                            
                            if isEditingTmdbKey {
                                VStack(spacing: 16) {
                                    TextField("请输入 TMDB API KEY", text: $tmdbApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 18))
                                        .focused($isTmdbKeyFocused)
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showLogoutAlert: .constant(false))
    }
}
