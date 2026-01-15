# Top Shelf Extension 测试指南

## ✅ 诊断结果

Extension 已正确配置和嵌入：
- ✅ Extension 位于: MoviePilotTV.app/PlugIns/MoviePilotTVTopShelf.appex
- ✅ Bundle ID: com.hvg.moviepilot-atv.MoviePilotTVTopShelf
- ✅ Extension Point: com.apple.tv-top-shelf
- ✅ Principal Class: MoviePilotTVTopShelf.ContentProvider
- ✅ App Groups: group.com.hvg.moviepilot-atv (已配置)

## 🔧 完整测试步骤

### 1. 完全清理
在 Xcode 中:
```
Product > Clean Build Folder (按住 Option 键点击)
或按 Cmd+Shift+Option+K
```

### 2. 删除模拟器中的旧 App
在终端运行:
```bash
xcrun simctl uninstall booted com.hvg.moviepilot-atv
```

### 3. 重新构建并运行
- 选择 **MoviePilotTV** scheme（不是 MoviePilotTVTopShelf）
- 点击 Run (Cmd+R)

### 4. 登录并加载数据
- 登录你的账号
- 进入首页，等待推荐内容加载完成
- 确认日志显示:
  ```
  ✅ [TopShelfHelper] 验证成功: 读取到 10 项
  ```

### 5. 退出 App
- 按模拟器的 **Home 键** (Shift+Cmd+H)
- 返回 Apple TV 主屏幕

### 6. 等待系统加载 Extension
- **重要**: 将光标移到其他 app 图标上，停留 3-5 秒
- 然后移回你的 MoviePilotTV 图标
- 再等待 5-10 秒
- 观察 Top Shelf 区域

### 7. 查看 Xcode 日志
在 Xcode 控制台搜索框输入: `[TopShelf]`

应该看到:
```
🔝 [TopShelf] ========== ContentProvider 被调用 ==========
✅ [TopShelf] App Group 访问成功
✅ [TopShelf] 已登录
✅ [TopShelf] 成功加载 10 个推荐项
```

## 🐛 如果仍然看不到 Extension 日志

### 方案 A: 强制刷新模拟器
```bash
# 1. 关闭所有模拟器
xcrun simctl shutdown all

# 2. 删除缓存
rm -rf ~/Library/Developer/CoreSimulator/Caches

# 3. 退出 Xcode

# 4. 重启 Mac（可选但推荐）

# 5. 重新打开 Xcode 并运行
```

### 方案 B: 使用真实设备测试
tvOS 模拟器的 Top Shelf 支持不完整，可能需要在真实 Apple TV 上测试:
1. 连接 Apple TV 4K/HD 到 Mac
2. 在 Xcode 中选择真实设备
3. 运行 app
4. 在真实设备上更容易看到 Top Shelf 效果

### 方案 C: 手动触发（调试用）
在 ContentProvider.swift 的 `loadTopShelfContent` 方法最开始添加:
```swift
print("🔝 [TopShelf] ========== ContentProvider INIT ==========")
NSLog("🔝 [TopShelf] ContentProvider INIT")
```
使用 `NSLog` 可以确保日志一定输出。

## 📝 tvOS Top Shelf 行为说明

**重要**: tvOS 不会立即调用 Extension，它会在以下情况触发:
- ✅ App 图标获得焦点时（第一次可能需要等待）
- ✅ 系统认为需要更新时（通常几分钟内）
- ✅ App 从后台返回前台时
- ❌ **不会**在 App 内部数据更新时立即触发

第一次可能需要等待 **10-30 秒** 才会看到效果。

## ✅ 成功标志

当看到以下内容说明成功:
1. Xcode 控制台有 `[TopShelf] ContentProvider 被调用` 日志
2. Apple TV 主屏幕上你的 app 图标上方显示横向滚动的影视卡片
3. 点击卡片可以打开 app 并跳转到详情页
