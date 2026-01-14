# MoviePilot TV

一款为 Apple TV 设计的 Movie Pilot 客户端应用，提供影视内容浏览、搜索和订阅功能。

![Platform](https://img.shields.io/badge/platform-tvOS%2017.0%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-Personal%20Use-blue)

## ✨ 主要功能

### 🏠 首页
- 🎬 精选内容轮播展示
- 📊 TMDB 流行趋势（20部）
- 🎥 豆瓣热门电影（10部）
- 📺 豆瓣热门剧集（10部）
- 📌 最近订阅列表

### ⭐ 推荐榜单（8 个分类）

**TMDB 数据源：**
- 🔥 流行趋势 - 当前最热门的影视内容
- 🎬 热门电影 - TMDB 热门电影榜单
- 📺 热门剧集 - TMDB 热门剧集榜单

**豆瓣数据源：**
- 🎥 热门电影 - 豆瓣当前热映和热门电影
- 📺 热门剧集 - 豆瓣热门电视剧
- 🏆 电影 TOP250 - 豆瓣评分最高的 250 部电影
- 🎬 豆瓣电影 - 豆瓣推荐电影
- 📺 豆瓣剧集 - 豆瓣推荐剧集

每个分类独立横向滚动，支持焦点导航，并发加载提升性能。

### 🔍 搜索
- 实时搜索影视内容
- 支持中英文搜索
- 网格布局展示结果
- 显示海报、标题、年份和评分

### 📺 其他功能
- 订阅管理 - 查看和管理订阅内容
- 下载管理 - 查看下载任务和历史
- 站点管理 - 管理下载站点配置
- 系统状态 - 实时查看存储和下载/上传速度（5 秒刷新）

## 🚀 快速开始

### 环境要求

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本
- tvOS 17.0 或更高版本

### 安装步骤

1. **打开项目**
   ```bash
   cd /Users/ykyau/xcode/MoviePoilt-TV
   open MoviePilotTV.xcodeproj
   ```

2. **配置服务器地址**（可选）
   
   默认配置：
   ```
   ```

   如需修改，编辑 `LoginView.swift`:
   ```swift
   @State private var endpoint = "http://your-server:4000"
   @State private var username = "your-username"
   @State private var password = "your-password"
   ```

3. **选择运行目标**
   - 选择 Apple TV 模拟器（推荐 Apple TV 4K）
   - 或连接真实的 Apple TV 设备

4. **运行应用**
   - 点击 Run 按钮（⌘R）
   - 应用将自动使用默认凭据登录

## 🎮 使用指南

### tvOS 遥控器操作

| 操作 | 说明 |
|------|------|
| 方向键 | 上下左右移动焦点 |
| 触摸板滑动 | 快速浏览内容 |
| 点击/选择 | 确认选择 |
| Menu 按钮 | 返回上一级 |
| Play/Pause | 播放/暂停 |

### 键盘快捷键（模拟器）

| 按键 | 功能 |
|------|------|
| 方向键 | 导航 |
| 回车 | 选择 |
| ESC | 返回 |
| 空格 | 播放/暂停 |

### 导航结构

```
TabView（顶层导航）
├── 🏠 首页 - 缓存优先 + 后台刷新
├── 🔍 搜索 - 实时搜索 + 订阅弹窗
├── ⭐ 推荐 - 8 个并发加载分类
├── 📺 订阅 - 列表 + 缓存
├── 📥 下载管理 - 下载任务、速度
├── 🌐 站点管理 - 站点状态切换
└── ⚙️ 设置 - 账号与接口配置

浮层：右下角 SystemStatusCard 展示存储用量与上下行速度（5s 定时刷新）
```

## 🛠 技术栈

- **语言**: Swift 5.0
- **UI 框架**: SwiftUI
- **架构模式**: MVVM
- **网络请求**: URLSession + async/await
- **状态管理**: Combine Framework
- **认证方式**: JWT Bearer Token
- **并发处理**: Swift Concurrency (async/await, TaskGroup)

## 📱 界面设计

### 深色主题
- 黑色背景，减少电视屏幕眩光
- 蓝色强调色，突出重要元素
- 大字体设计，适配电视观看距离
- 焦点高亮效果，清晰的导航指示

### 布局特点
- TabView 顶层导航（Label + SF Symbols），各页面使用 NavigationStack
- 海报卡片 2:3 比例，MediaSection 横向滚动（记忆焦点）
- Featured 海报置顶，后续分区有统一左右/纵向留白（90 / 20）
- 搜索结果网格自适应列数，聚焦高亮

### 字体规范（tvOS 优化）
| 元素 | 字体大小 |
|------|---------|
| 页面标题 | 32px |
| 分类标题 | 26-28px |
| 导航按钮 | 18px |
| 卡片标题 | 16px |
| 辅助信息 | 13-16px |

## 🔧 高级配置

### API 服务器配置

编辑 `AuthenticationManager.swift` 中的持久化键：

```swift
private let endpointKey = "apiEndpoint"
private let tokenKey = "accessToken"
private let tmdbApiKeyKey = "tmdbApiKey"
```

### 系统状态轮询
- `SystemStatusViewModel` 通过 `startUpdating()` 启动 5 秒定时器
- 首次拉取同时请求存储与下载信息，后续仅刷新下载速度（可复用存储缓存）
- 数据源：`/api/v1/dashboard/storage` 与 `/api/v1/dashboard/downloader`

### 推荐分类自定义

编辑 `RecommendViewModel.swift` 中的 `categories` 数组:

```swift
let categories: [(String, String)] = [
    ("tmdb_trending", "TMDB 流行趋势"),
    ("douban_movie_hot", "豆瓣热门电影"),
    // 添加或移除分类
]
```

## 🧪 测试与诊断

- 当前仓库未包含自动化测试脚本；推荐在 tvOS 模拟器内以 TabView 全路径自测。
- 系统状态卡片可用作网络/下载速率的快速健康检查。

## 📊 API 端点映射

| 端点 | 方法 | 说明 | 状态 |
|------|------|------|------|
| `/api/v1/login/access-token` | POST | 登录获取 Token | ✅ |
| `/api/v1/recommend/tmdb_trending` | GET | TMDB 流行趋势 | ✅ |
| `/api/v1/recommend/tmdb_movies` | GET | TMDB 热门电影 | ✅ |
| `/api/v1/recommend/tmdb_tvs` | GET | TMDB 热门剧集 | ✅ |
| `/api/v1/recommend/douban_movie_hot` | GET | 豆瓣热门电影 | ✅ |
| `/api/v1/recommend/douban_tv_hot` | GET | 豆瓣热门剧集 | ✅ |
| `/api/v1/recommend/douban_movie_top250` | GET | 豆瓣 TOP250 | ✅ |
| `/api/v1/recommend/douban_movies` | GET | 豆瓣电影 | ✅ |
| `/api/v1/recommend/douban_tvs` | GET | 豆瓣剧集 | ✅ |
| `/api/v1/media/search?title={keyword}` | GET | 搜索影视内容 | ✅ |
| `/api/v1/subscribe` | GET | 获取订阅列表 | ✅ |
| `/api/v1/dashboard/storage` | GET | 存储空间信息 | ✅ |
| `/api/v1/dashboard/downloader` | GET | 下载/上传速率与用量 | ✅ |
| `/api/v1/site/` | GET | 站点列表 | ✅ |
| `/api/v1/site/{id}` | PUT | 启用/停用站点 | ✅ |

## 📂 项目结构

```
MoviePilotTV/
├── Models/                  # 数据模型
│   ├── MediaItem.swift      # 媒体项目模型
│   ├── Subscription.swift   # 订阅模型
│   ├── Download.swift       # 下载模型
│   └── Site.swift          # 站点模型
├── Views/                   # 视图层
│   ├── MainView.swift       # TabView 导航 + SystemStatusCard 注入
│   ├── HomeView.swift       # 首页（缓存优先 + 后台刷新）
│   ├── SearchView.swift     # 搜索 + 订阅弹窗
│   ├── RecommendView.swift  # 8 分类并发加载
│   ├── SubscriptionsView.swift
│   ├── DownloadsView.swift
│   ├── SitesView.swift
│   ├── SettingsView.swift
│   └── Components/          # MediaSection, CachedAsyncImage 等
├── ViewModels/              # 视图模型层（@MainActor）
│   ├── HomeViewModel.swift  # 先读缓存再刷新
│   ├── RecommendViewModel.swift  # TaskGroup 并发
│   ├── SearchViewModel.swift     # 500ms 防抖搜索
│   ├── SystemStatusViewModel.swift # 5s 轮询系统状态
│   └── ...
└── Services/                # 服务层
   ├── APIService.swift     # API + 缓存配置 + 系统状态
   ├── AuthenticationManager.swift  # 认证管理（UserDefaults 持久化）
   ├── LocalCacheManager.swift      # 本地缓存（多 key）
   └── WebSocketService.swift       # SSE 进度通道
```

## 🚀 性能优化

### 并发加载
- 推荐页面使用 `TaskGroup` 并发加载 8 个分类
- 首页并发加载 3 个推荐源
- 显著提升加载速度（3-5秒完成所有请求）

### UI 优化
- 使用 `LazyHStack` 和 `LazyVGrid` 延迟加载
- AsyncImage 异步加载图片
- 焦点状态仅影响当前元素
- 平滑动画过渡（0.2秒）

### 内存管理
- Token 持久化存储在 UserDefaults
- 图片自动缓存
- 推荐数据在导航时保留，避免重复加载

## ❓ 常见问题

### Q: 登录失败怎么办？
**A:** 检查以下几点：
1. 服务器地址是否正确（包括端口号）
2. 网络连接是否正常
3. 用户名和密码是否正确
4. 服务器是否正在运行

### Q: 推荐内容加载慢？
**A:** 应用会并发加载 8 个推荐分类，首次加载可能需要 3-5 秒。后续访问会使用缓存数据。

### Q: 如何搜索中文内容？
**A:** 在搜索框中点击，tvOS 会弹出文本输入对话框，直接输入中文即可。

### Q: 为什么有些图片不显示？
**A:** 可能原因：
1. 网络问题导致图片加载失败
2. 图片 URL 失效
3. 该内容没有海报图片

应用会显示灰色占位符。

### Q: 可以在 iPhone 或 iPad 上使用吗？
**A:** 当前版本专为 tvOS 设计和优化。如需支持其他平台，需要适配 UI 布局和交互方式。

### Q: 如何更新推荐内容？
**A:** 推荐内容在每次进入推荐页面时会重新加载。也可以退出应用重新进入。

## 📝 更新日志

### v1.1.0 (2026-01-05)

**新增：**
- SystemStatusCard 展示存储用量与下载/上传速度，5s 轮询 `/api/v1/dashboard/storage` 与 `/api/v1/dashboard/downloader`
- SettingsView 补充 TabView 导航（与 Home/Search/Recommend/Subscriptions/Downloads/Sites 组成主入口）
- README 对齐当前导航、系统状态与 API 端点

**性能与体验：**
- 首页与推荐继续采用缓存优先、后台刷新与 TaskGroup 并发
- SearchView 使用 500ms 防抖 + 取消上一次 Task

## 🔮 未来计划

- [ ] 实现媒体详情页面
- [ ] 添加订阅功能（添加/删除订阅）
- [ ] 实现下载管理完整功能
- [ ] 添加搜索历史记录
- [ ] 实现高级搜索筛选
- [ ] 支持视频播放
- [ ] 添加用户设置页面
- [ ] 支持多账户切换

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目仅供学习和个人使用。

## 🔗 相关链接

- [Movie Pilot 项目](https://github.com/jxxghp/MoviePilot)
- [Movie Pilot API 文档](https://api.movie-pilot.org/)
- [Apple tvOS 开发文档](https://developer.apple.com/tvos/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui)

---

**开发者**: AI Copilot  
**最后更新**: 2026-01-05  
**版本**: v1.1.0  
**平台**: tvOS 17.0+
