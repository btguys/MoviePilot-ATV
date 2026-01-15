# Top Shelf Extension 配置指南

## 完成步骤

### 1. 在 Xcode 中添加 Top Shelf Extension Target

1. 打开 Xcode 项目
2. 选择菜单 **File > New > Target...**
3. 在模板选择界面，选择 **tvOS** 平台
4. 选择 **TV Services Extension**（或者搜索 "Top Shelf"）
5. 点击 **Next**
6. 配置扩展：
   - **Product Name**: `MoviePilotTVTopShelf`
   - **Organization Identifier**: 使用与主 app 相同的
   - **Bundle Identifier**: 应该是 `com.yourcompany.MoviePilotTV.MoviePilotTVTopShelf`
   - **Language**: Swift
7. 点击 **Finish**
8. 当询问是否激活 scheme 时，点击 **Activate**

### 2. 删除自动生成的文件

Xcode 会自动生成一些默认文件，删除它们并使用我们创建的文件：

1. 删除自动生成的 `ServiceProvider.swift`（如果有）
2. 删除自动生成的 `ContentProvider.swift`（如果与我们创建的不同）
3. 保留我们创建的 `ContentProvider.swift` 和 `Info.plist`

### 3. 将文件添加到 Target

1. 在 Xcode 左侧文件列表中，找到我们创建的文件：
   - `MoviePilotTVTopShelf/ContentProvider.swift`
   - `MoviePilotTVTopShelf/Info.plist`
   - `MoviePilotTV/Utilities/TopShelfHelper.swift`
   
2. 对于每个文件，在右侧 **File Inspector** 中：
   - `ContentProvider.swift` → 勾选 `MoviePilotTVTopShelf` target
   - `Info.plist` → 确保是 extension 的 Info.plist
   - `TopShelfHelper.swift` → 勾选 `MoviePilotTV` target（主 app）

### 4. 配置 App Groups

为了让主 app 和 extension 共享数据，需要配置 App Groups：

#### 4.1 在 Apple Developer 网站配置

1. 访问 [developer.apple.com](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles**
3. 点击 **Identifiers**
4. 找到你的 App ID，点击编辑
5. 启用 **App Groups** capability
6. 创建或选择 App Group：`group.com.moviepilot.tv`（或你的 bundle ID）
7. 对主 app 和 extension 都重复这个步骤

#### 4.2 在 Xcode 配置

1. 选择 **MoviePilotTV** target
2. 切换到 **Signing & Capabilities** tab
3. 点击 **+ Capability**
4. 添加 **App Groups**
5. 点击 **+** 添加 group：`group.com.moviepilot.tv`

6. 选择 **MoviePilotTVTopShelf** target
7. 重复上述步骤，添加相同的 App Group

### 5. 配置 URL Scheme

为了支持深链接，需要在主 app 中配置 URL scheme：

1. 选择 **MoviePilotTV** target
2. 切换到 **Info** tab
3. 展开 **URL Types** section（如果没有，点击 + 添加）
4. 添加新的 URL Type：
   - **Identifier**: `com.moviepilot.tv`
   - **URL Schemes**: `moviepilot`
   - **Role**: `Editor`

### 6. 更新 Info.plist（如果需要）

确保主 app 的 `Info.plist` 包含：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.moviepilot.tv</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>moviepilot</string>
        </array>
    </dict>
</array>
```

### 7. 添加 Top Shelf 图片资源（可选）

如果想自定义 Top Shelf Image：

1. 在 `Assets.xcassets` 中的 `Brand Assets.brandassets`
2. 检查 **Top Shelf Image** 和 **Top Shelf Image Wide**
3. 添加尺寸：
   - **Top Shelf Image**: 2320×720 @1x, 4640×1440 @2x
   - **Top Shelf Image Wide**: 1920×720 @1x, 3840×1440 @2x

### 8. 编译和测试

1. 选择 **MoviePilotTV** scheme
2. 选择 Apple TV 设备或模拟器
3. 点击 **Run** (Cmd+R)
4. 登录后，在首页会自动更新 Top Shelf 内容
5. 按 **Home** 键返回 Apple TV 主界面
6. 将光标移动到 app 图标上（不点击）
7. 应该能看到顶部显示推荐影片卡片

### 9. 测试深链接

1. 在 Apple TV 主界面，将光标移到 app 上
2. 看到 Top Shelf 内容后，点击其中一个影片卡片
3. App 应该打开并直接跳转到该影片的详情页

## 常见问题

### Top Shelf 不显示内容

1. 确认已登录
2. 在首页等待推荐内容加载完成
3. 检查控制台日志，搜索 `[TopShelf]` 或 `[TopShelfHelper]`
4. 重启 Apple TV 或重新安装 app

### 深链接不工作

1. 确认 URL Scheme 已正确配置
2. 检查 App Groups 是否正确设置
3. 查看控制台日志，搜索 `[DeepLink]`

### Extension 编译错误

1. 确认所有必要的文件都添加到了正确的 target
2. 检查 `Info.plist` 配置是否正确
3. 清理项目：**Product > Clean Build Folder** (Cmd+Shift+K)

## 工作原理

1. **主 app 登录时**：`AuthenticationManager` 通过 `TopShelfHelper` 将 token 保存到共享的 App Group
2. **首页加载推荐时**：`HomeViewModel` 通过 `TopShelfHelper` 将推荐内容保存到共享 App Group
3. **Apple TV 显示 app 时**：系统调用 `ContentProvider.loadTopShelfContent()`
4. **ContentProvider 读取**：从共享 App Group 读取推荐内容和登录状态
5. **显示 Top Shelf**：创建 `TVTopShelfSectionedContent` 并显示影片卡片
6. **用户点击卡片**：触发深链接 URL（`moviepilot://media?id=...&source=...`）
7. **App 处理深链接**：`MoviePilotTVApp.onOpenURL()` 解析 URL 并导航到详情页

## 文件清单

- ✅ `MoviePilotTVTopShelf/ContentProvider.swift` - Top Shelf 内容提供者
- ✅ `MoviePilotTVTopShelf/Info.plist` - Extension 配置
- ✅ `MoviePilotTV/Utilities/TopShelfHelper.swift` - Top Shelf 数据同步助手
- ✅ `MoviePilotTV/MoviePilotTVApp.swift` - 深链接处理
- ✅ `MoviePilotTV/Views/MainView.swift` - 深链接导航
- ✅ `MoviePilotTV/ViewModels/HomeViewModel.swift` - Top Shelf 数据更新
- ✅ `MoviePilotTV/Services/AuthenticationManager.swift` - 登录状态同步
