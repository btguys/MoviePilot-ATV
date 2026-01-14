//
//  LoginView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var apiEndpoint = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var hasLoadedCredentials = false
    @State private var showTokenExpiredBanner = false
    @State private var tokenExpiredBannerMessage = ""
    
    @State private var showEndpointInput = false
    @State private var showUsernameInput = false
    @State private var showPasswordInput = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Logo and Title
                VStack(spacing: 20) {
                    Image("login-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)
                    
                    Text("Movie Pilot for ATV")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("影音订阅管理平台")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                
                // Login Form
                VStack(spacing: 30) {
                    // API Endpoint Field
                    TVInputField(
                        title: "API 服务器地址",
                        placeholder: "https://your-server.com",
                        text: $apiEndpoint,
                        isSecure: false,
                        showInput: $showEndpointInput
                    )
                    
                    // Username Field
                    TVInputField(
                        title: "用户名",
                        placeholder: "请输入用户名",
                        text: $username,
                        isSecure: false,
                        showInput: $showUsernameInput
                    )
                    
                    // Password Field
                    TVInputField(
                        title: "密码",
                        placeholder: "请输入密码",
                        text: $password,
                        isSecure: true,
                        showInput: $showPasswordInput
                    )
                    
                    // Login Button
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        } else {
                            Text("登录")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isLoading)
                    
                }
                .frame(width: 700)
                .padding(40)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .alert("登录失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadSavedCredentials()
            showTokenExpiredBannerIfNeeded()
        }
        .onChange(of: authManager.showTokenExpiredAlert) { show in
            guard show else { return }
            showTokenExpiredBannerIfNeeded()
        }
        .overlay(alignment: .top) {
            if showTokenExpiredBanner {
                Text(tokenExpiredBannerMessage.isEmpty ? "登录已过期，请重新登录" : tokenExpiredBannerMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var isFormValid: Bool {
        !apiEndpoint.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private func showTokenExpiredBannerIfNeeded() {
        guard authManager.showTokenExpiredAlert else { return }
        tokenExpiredBannerMessage = authManager.tokenExpiredMessage
        withAnimation(.easeInOut(duration: 0.25)) {
            showTokenExpiredBanner = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                showTokenExpiredBanner = false
            }
            authManager.showTokenExpiredAlert = false
        }
    }
    
    private func loadSavedCredentials() {
        guard !hasLoadedCredentials else { return }
        hasLoadedCredentials = true
        
        // 自动填充已保存的凭据（无默认值，避免暴露个人信息）
        if !authManager.apiEndpoint.isEmpty {
            apiEndpoint = authManager.apiEndpoint
        }
        
        if !authManager.savedUsername.isEmpty {
            username = authManager.savedUsername
        }
        
        if !authManager.savedPassword.isEmpty {
            password = authManager.savedPassword
        }
        
        print("✅ [LoginView] 已加载保存的凭据")
    }
    
    private func login() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task { @MainActor in
            do {
                try await authManager.login(
                    endpoint: apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                    username: username,
                    password: password
                )
                // Success - authManager will update isAuthenticated
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            } catch {
                errorMessage = "登录失败: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - TV Input Field Component
struct TVInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    @Binding var showInput: Bool
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                showInput = true
            }) {
                HStack {
                    if isSecure && !text.isEmpty {
                        Text(String(repeating: "•", count: text.count))
                            .font(.title3)
                            .foregroundColor(.white)
                    } else if !text.isEmpty {
                        Text(text)
                            .font(.title3)
                            .foregroundColor(.white)
                    } else {
                        Text(placeholder)
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(height: 60)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .focused($isFocused)
        }
        .alert(title, isPresented: $showInput) {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
            Button("确定") {
                showInput = false
            }
            Button("取消", role: .cancel) {
                showInput = false
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
            .font(.title3)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
