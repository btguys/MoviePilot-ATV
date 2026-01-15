//
//  AuthenticationManager.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation
import Combine

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var apiEndpoint: String = ""
    @Published var accessToken: String = ""
    @Published var tmdbApiKey: String = ""
    @Published var savedUsername: String = ""
    @Published var savedPassword: String = ""
    @Published var showTokenExpiredAlert = false
    @Published var tokenExpiredMessage = ""
    @Published var showHomeSystemStatus: Bool = true
    
    private let userDefaults = UserDefaults.standard
    private let endpointKey = "apiEndpoint"
    private let tokenKey = "accessToken"
    private let tmdbApiKeyKey = "tmdbApiKey"
    private let usernameKey = "savedUsername"
    private let passwordKey = "savedPassword"
    private let showHomeSystemStatusKey = "showHomeSystemStatus"
    
    private init() {
        loadCredentials()
    }
    
    func saveEndpoint(_ endpoint: String) {
        apiEndpoint = endpoint
        userDefaults.set(endpoint, forKey: endpointKey)
    }
    
    func saveTmdbApiKey(_ key: String) {
        tmdbApiKey = key
        userDefaults.set(key, forKey: tmdbApiKeyKey)
        print("✅ [AuthManager] TMDB API KEY 已保存到 UserDefaults")
    }
    
    func saveShowHomeSystemStatus(_ show: Bool) {
        showHomeSystemStatus = show
        userDefaults.set(show, forKey: showHomeSystemStatusKey)
        print("✅ [AuthManager] 首页系统状态栏显示设置已保存: \(show)")
    }
    
    func login(endpoint: String, username: String, password: String) async throws {
        // Save endpoint and credentials for auto re-login
        saveEndpoint(endpoint)
        saveCredentials(username: username, password: password)
        
        // Create login request - Movie Pilot uses /api/v1/login/access-token with form data
        guard let url = URL(string: "\(endpoint)/api/v1/login/access-token") else {
            print("❌ Invalid URL: \(endpoint)/api/v1/login/access-token")
            throw APIError.invalidURL
        }
        
        print("🔵 Login attempt:")
        print("   URL: \(url)")
        print("   Username: \(username)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Use form-encoded data instead of JSON
        let formData = "username=\(username)&password=\(password)"
        request.httpBody = formData.data(using: .utf8)
        
        print("   Request body: \(formData)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("   Response status: \(httpResponse.statusCode)")
            print("   Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Authentication failed with status: \(httpResponse.statusCode)")
                throw APIError.authenticationFailed
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            
            print("✅ Login successful!")
            print("   Access token: \(loginResponse.accessToken.prefix(20))...")
            
            // Update UI state on main thread
            self.accessToken = loginResponse.accessToken
            self.isAuthenticated = true
            
            userDefaults.set(loginResponse.accessToken, forKey: tokenKey)
            
            // 同步登录状态到 Top Shelf Extension
            print("🔝 [AuthManager] 同步认证状态到 Top Shelf")
            TopShelfHelper.shared.updateAuthenticationState(
                token: loginResponse.accessToken,
                endpoint: endpoint
            )
            print("🔝 [AuthManager] 认证状态同步完成")
        } catch let error as DecodingError {
            print("❌ Decoding error: \(error)")
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Network error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    func logout() {
        isAuthenticated = false
        accessToken = ""
        userDefaults.removeObject(forKey: tokenKey)
        
        // 清除 Top Shelf 的登录状态
        TopShelfHelper.shared.updateAuthenticationState(token: nil, endpoint: nil)
    }
    
    func handleTokenExpired() {
        print("⚠️ [AuthManager] Token 已过期")
        tokenExpiredMessage = "登录已过期，请重新登录"
        showTokenExpiredAlert = true
        logout()
    }
    
    private func saveCredentials(username: String, password: String) {
        savedUsername = username
        savedPassword = password
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.set(password, forKey: passwordKey)
        print("✅ [AuthManager] 用户凭据已保存")
    }
    
    private func loadCredentials() {
        print("🔵 [AuthManager] 加载凭据...")
        
        if let endpoint = userDefaults.string(forKey: endpointKey) {
            apiEndpoint = endpoint
            print("   API Endpoint: \(endpoint)")
        } else {
            print("   ⚠️ 未找到保存的 API Endpoint")
        }
        
        if let token = userDefaults.string(forKey: tokenKey) {
            accessToken = token
            isAuthenticated = true
            print("   ✅ Token: \(token.prefix(20))...")
            print("   ✅ 已认证")
        } else {
            print("   ⚠️ 未找到保存的 Token")
        }
        
        if let key = userDefaults.string(forKey: tmdbApiKeyKey) {
            tmdbApiKey = key
            print("   ✅ TMDB API KEY: \(key.prefix(10))...")
        } else {
            print("   ⚠️ 未找到保存的 TMDB API KEY")
        }
        
        if let username = userDefaults.string(forKey: usernameKey) {
            savedUsername = username
            print("   ✅ 已保存的用户名: \(username)")
        }
        
        if let password = userDefaults.string(forKey: passwordKey) {
            savedPassword = password
            print("   ✅ 已保存的密码: ******")
        }
        
        // 加载显示系统状态栏设置，默认为 true
        showHomeSystemStatus = userDefaults.object(forKey: showHomeSystemStatusKey) as? Bool ?? true
        print("   ✅ 显示首页系统状态栏: \(showHomeSystemStatus)")
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}
