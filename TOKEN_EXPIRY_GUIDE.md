# Token 过期处理功能说明

## 功能概述

本应用已实现 Token 过期的全局检测和友好的用户体验优化，包括：

1. **自动检测 Token 过期**：当 API 返回 403 状态码且响应内容包含 `{"detail":"token校验不通过"}` 时，自动识别为 token 过期
2. **友好的提示框**：弹出中文提示"登录已过期，请重新登录"
3. **自动跳转登录页**：Token 过期时自动登出并跳转到登录界面
4. **凭据记忆功能**：保存用户输入的 API 地址、用户名和密码
5. **一键重新登录**：提供"使用上次保存的凭据登录"快捷按钮

## 实现细节

### 1. APIService.swift - Token 过期检测

在 `performRequest` 方法中添加了 403 错误检测：

```swift
// 检查是否是 token 过期 (403 + {"detail":"token校验不通过"})
if httpResponse.statusCode == 403 {
    if let responseString = String(data: data, encoding: .utf8),
       responseString.contains("token校验不通过") {
        print("⚠️ [APIService] Token 已过期")
        authManager.handleTokenExpired()
        throw APIError.tokenExpired
    }
}
```

### 2. AuthenticationManager.swift - 凭据管理

新增功能：

- **保存用户凭据**：`savedUsername`, `savedPassword` 属性及对应的 UserDefaults 存储
- **Token 过期处理**：`handleTokenExpired()` 方法触发全局提示和登出
- **全局状态管理**：`showTokenExpiredAlert`, `tokenExpiredMessage` 用于控制提示框

关键方法：

```swift
func handleTokenExpired() {
    tokenExpiredMessage = "登录已过期，请重新登录"
    showTokenExpiredAlert = true
    logout()
}

private func saveCredentials(username: String, password: String) {
    savedUsername = username
    savedPassword = password
    userDefaults.set(username, forKey: usernameKey)
    userDefaults.set(password, forKey: passwordKey)
}
```

### 3. LoginView.swift - 自动填充和快捷登录

新增功能：

- **自动填充**：`onAppear` 时从 `authManager` 加载已保存的凭据
- **一键登录按钮**：当有保存的凭据时显示绿色的"使用上次保存的凭据登录"按钮
- **Token 过期提示**：监听 `authManager.showTokenExpiredAlert` 显示友好提示

关键变量和方法：

```swift
private var hasSavedCredentials: Bool {
    !authManager.savedUsername.isEmpty && 
    !authManager.savedPassword.isEmpty && 
    !authManager.apiEndpoint.isEmpty
}

private func quickLogin() {
    apiEndpoint = authManager.apiEndpoint
    username = authManager.savedUsername
    password = authManager.savedPassword
    login()
}
```

## 用户体验流程

### 首次登录
1. 用户在登录页输入 API 地址、用户名、密码
2. 点击"登录"按钮
3. 登录成功后，凭据自动保存到 UserDefaults

### Token 过期时
1. 用户在使用应用时，某个 API 请求返回 403 + "token校验不通过"
2. APIService 检测到 token 过期，调用 `authManager.handleTokenExpired()`
3. 弹出提示框："登录已过期，请重新登录"
4. 自动登出，跳转到登录页
5. 登录页自动填充之前保存的 API 地址、用户名和密码
6. 用户可以：
   - 直接点击绿色的"使用上次保存的凭据登录"按钮（一键登录）
   - 或修改凭据后点击蓝色的"登录"按钮

### 长时间未打开应用
1. 用户再次打开应用时，如果 token 仍有效，自动登录
2. 如果 token 已过期，首次 API 调用时触发上述"Token 过期时"的流程

## 数据持久化

以下数据保存在 UserDefaults 中：

- `apiEndpoint`: API 服务器地址
- `accessToken`: 访问令牌
- `savedUsername`: 用户名
- `savedPassword`: 密码（明文存储，建议生产环境使用 Keychain）
- `tmdbApiKey`: TMDB API 密钥

## 安全建议

**重要提示**：当前密码以明文形式存储在 UserDefaults 中，这在生产环境中不够安全。建议：

1. 使用 iOS Keychain 存储敏感信息（用户名、密码）
2. 考虑实现 Refresh Token 机制
3. 在设置中提供"记住密码"选项开关

## 测试场景

### 模拟 Token 过期
1. 正常登录应用
2. 手动修改服务器端 token 使其失效，或等待 token 自然过期
3. 在应用中执行任何 API 操作（如浏览推荐、搜索等）
4. 验证是否弹出"登录已过期，请重新登录"提示
5. 验证是否自动跳转到登录页且凭据已自动填充
6. 点击"使用上次保存的凭据登录"验证一键登录功能

### 测试凭据记忆
1. 输入自定义的 API 地址、用户名、密码并登录
2. 完全关闭应用（force quit）
3. 重新打开应用
4. 如果 token 仍有效，应自动登录
5. 如果手动登出，返回登录页应看到之前输入的凭据已自动填充

## 相关文件

- [Services/APIService.swift](MoviePilotTV/Services/APIService.swift) - API 调用和错误处理
- [Services/AuthenticationManager.swift](MoviePilotTV/Services/AuthenticationManager.swift) - 认证和凭据管理
- [Views/LoginView.swift](MoviePilotTV/Views/LoginView.swift) - 登录界面
- [MoviePilotTVApp.swift](MoviePilotTV/MoviePilotTVApp.swift) - 应用入口

## 更新日志

**2026-01-13**
- ✅ 添加 Token 过期全局检测（403 + "token校验不通过"）
- ✅ 实现友好的中文提示框
- ✅ 实现凭据记忆功能（API 地址、用户名、密码）
- ✅ 添加一键重新登录功能
- ✅ 自动填充上次保存的登录信息
