# MoviePilot TV

一款为 Apple TV 设计的 [Movie Pilot](https://github.com/jxxghp/MoviePilot) 客户端应用，提供影视内容浏览、搜索、订阅和下载管理功能。

![Platform](https://img.shields.io/badge/platform-tvOS%2017.0%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)

## 主要功能

### 首页
- 精选内容轮播展示
- TMDB 流行趋势（20部）
- 豆瓣热门电影（10部）
- 豆瓣热门剧集（10部）
- 最近订阅列表
- 系统状态卡片（存储用量、上下行速度，5 秒轮播刷新）

### 推荐榜单（8 个分类）

**TMDB 数据源：**
- TMDB 流行趋势
- TMDB 电影
- TMDB 剧集

**豆瓣数据源：**
- 豆瓣热门电影
- 豆瓣热门剧集
- 豆瓣电影 TOP250
- 豆瓣最新电影
- 豆瓣最新剧集

每个分类独立横向滚动，支持焦点导航，TaskGroup 并发加载。每个分类支持"查看更多"分页浏览。

### 搜索
- 实时搜索影视内容（500ms 防抖）
- 支持中英文搜索
- 网格布局展示结果
- 搜索完成后可查看资源详情并订阅

### 订阅管理
- 查看和管理订阅列表（首页缓存 + 后台刷新）
- 添加/删除订阅（支持 TMDB 和豆瓣）
- 按媒体类型筛选订阅
- 支持季级订阅（电视剧）
- 检查指定媒体订阅状态

### 下载管理
- 查看当前下载任务和进度
- 查看下载历史记录
- 暂停/停止下载任务
- 删除下载任务
- 查看下载器速度、上传/下载量

### 站点管理
- 查看站点列表
- 启用/停用站点
- 查看站点用户数据

### Top Shelf 集成
- Apple TV 主屏幕 Top Shelf 推荐内容展示
- Deep Linking：通过 `moviepilot://media` 链接直接跳转到媒体详情
- 支持 TMDB 和豆瓣来源的媒体跳转

### 系统设置
- 查看当前登录用户信息
- 查看 API 服务器地址
- TMDB API Key 配置（用于豆瓣影片自动查询 TMDB ID，支持 Infuse 跳转播放）
- 首页系统状态栏显示模式切换（完整/简洁/关闭）
- 退出登录

### 媒体详情
- 影片基本信息展示（海报、简介、评分、年份等）
- 季度/集数列表（电视剧）
- 演职人员信息
- 资源搜索和下载提交
- 订阅状态检查与操作
- 不存在剧集检测

### 剧集面板
- TMDB 剧集详情查询
- 剧集类型、评分、演员、制作人员信息

### 界面设计

#### 设计系统
- **ColorTokens**：22 个语义化颜色 token，统一的深色主题配色
- **FontTokens**：16 个语义化字体 token，tvOS 大字体优化

#### 深色主题
- 黑色背景，减少电视屏幕眩光
- 蓝色强调色，突出重要元素
- 大字体设计，适配电视观看距离
- 焦点高亮效果，清晰的导航指示

#### 布局特点
- TabView 顶层导航（Label + SF Symbols），各页面使用 NavigationStack
- 海报卡片 2:3 比例，MediaSection 横向滚动（记忆焦点）
- Featured 海报置顶，后续分区有统一左右/纵向留白
- 搜索结果网格自适应列数，聚焦高亮
- 统一的焦点动画（0.2s）

## 快速开始

### 环境要求

- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本
- tvOS 17.0 或更高版本

### 安装步骤

1. **打开项目**
   ```bash
   cd MoviePilot-ATV
   open MoviePilot-ATV.xcodeproj
   ```

2. **选择运行目标**
   - 选择 Apple TV 模拟器（推荐 Apple TV 4K）
   - 或连接真实的 Apple TV 设备

3. **运行应用**
   - 点击 Run 按钮（⌘R）
   - 在登录界面输入你的 Movie Pilot 服务器地址、用户名和密码

## 使用指南

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
├── 首页 - 缓存优先 + 后台刷新 + 系统状态卡片
├── 搜索 - 500ms 防抖搜索 + 订阅弹窗
├── 推荐 - 8 个分类 TaskGroup 并发加载 + 查看更多分页
├── 订阅 - 列表 + 缓存 + 类型筛选
├── 下载管理 - 任务、历史、暂停/删除
├── 站点 - 站点列表 + 启用/停用
└── 设置 - 账号信息 + TMDB Key + 显示模式

Top Shelf：主屏幕推荐内容 + Deep Linking (moviepilot://)
浮层：SystemStatusCard 展示存储用量与上下行速度（5s 定时刷新）
```

## 技术栈

- **语言**: Swift 5.0
- **UI 框架**: SwiftUI
- **架构模式**: MVVM
- **网络请求**: URLSession + URLCache 磁盘缓存（500MB）
- **状态管理**: Combine Framework + @MainActor
- **认证方式**: JWT Bearer Token（UserDefaults 持久化）
- **并发处理**: Swift Concurrency (async/await, TaskGroup)
- **持久化**: UserDefaults + 本地文件缓存
- **深链接**: Custom URL Scheme (moviepilot://)
- **扩展**: tvOS Top Shelf Extension

### UI 组件

- **ColorTokens**（22 个语义颜色） + **FontTokens**（16 个语义字体）
- **CachedAsyncImage**：两级缓存（内存 + 磁盘）
- **LoadingView** / **EmptyStateView**：通用加载和空状态组件
- **CardButtonStyle**：统一卡片焦点动画样式


## 测试与诊断

- 系统状态卡片可用作网络/下载速率的快速健康检查
- 调试日志使用 emoji 前缀：🔵 网络, ✅ 成功, ❌ 错误

## Movie Pilot API 端点映射

| 端点 | 方法 | 说明 | 状态 |
|------|------|------|------|
| `/api/v1/login/access-token` | POST | 登录获取 Token | ✅ |
| `/api/v1/user/current` | GET | 获取当前用户信息 | ✅ |
| `/api/v1/recommend/{source}` | GET | 推荐内容（支持 8 个分类） | ✅ |
| `/api/v1/recommend/tmdb_trending` | GET | TMDB 流行趋势 | ✅ |
| `/api/v1/media/search?title={keyword}` | GET | 搜索影视内容 | ✅ |
| `/api/v1/media/{source}:{id}` | GET | 媒体详情 | ✅ |
| `/api/v1/tmdb/credits/{id}/{type}` | GET | TMDB 演职人员 | ✅ |
| `/api/v1/tmdb/{tmdbId}/{season}` | GET | 剧集详情 | ✅ |
| `/api/v1/search/media/{source}:{id}` | GET | 搜索媒体资源 | ✅ |
| `/api/v1/subscribe/` | GET/POST | 订阅列表/添加订阅 | ✅ |
| `/api/v1/subscribe/{id}` | DELETE | 删除订阅 | ✅ |
| `/api/v1/subscribe/media/{source}:{id}` | GET | 检查订阅状态 | ✅ |
| `/api/v1/download/` | GET/POST | 下载列表/提交下载 | ✅ |
| `/api/v1/download/history` | GET | 下载历史 | ✅ |
| `/api/v1/download/stop` | POST | 暂停下载任务 | ✅ |
| `/api/v1/download/?name=&hash=` | DELETE | 删除下载任务 | ✅ |
| `/api/v1/download/clients` | GET | 下载器客户端列表 | ✅ |
| `/api/v1/site/` | GET | 站点列表 | ✅ |
| `/api/v1/site/{id}` | PUT | 启用/停用站点 | ✅ |
| `/api/v1/site/userdata/latest` | GET | 站点用户数据 | ✅ |
| `/api/v1/dashboard/storage` | GET | 存储空间信息 | ✅ |
| `/api/v1/dashboard/downloader` | GET | 下载/上传速率与用量 | ✅ |
| `/api/v1/system/setting/IndexerSites` | GET | 索引器站点配置 | ✅ |
| `/api/v1/mediaserver/notexists` | POST | 不存在的剧集检测 | ✅ |
| `/api/v1/system/img/0?imgurl=` | GET | 图片代理 | ✅ |

## 项目结构

```
MoviePilotTV/
├── Models/                      # 数据模型
│   ├── MediaItem.swift          # 媒体项目模型
│   ├── MediaDetail.swift        # 媒体详情模型
│   ├── Subscription.swift       # 订阅模型
│   ├── Download.swift           # 下载模型
│   ├── Downloader.swift         # 下载器模型
│   ├── Site.swift              # 站点模型
│   ├── SystemStatus.swift       # 系统状态模型
│   ├── Credits.swift            # 演职人员模型
│   ├── TMDBEpisode.swift        # TMDB 剧集模型
│   └── UserInfo.swift           # 用户信息模型
├── Views/                       # 视图层
│   ├── MainView.swift           # TabView 导航（7 个 tab）
│   ├── LoginView.swift          # 登录页面
│   ├── HomeView.swift           # 首页（缓存优先 + 后台刷新）
│   ├── SearchView.swift         # 搜索 + 订阅弹窗
│   ├── RecommendView.swift      # 8 分类 TaskGroup 并发加载
│   ├── MediaDetailView.swift    # 媒体详情页
│   ├── CategoryMoreView.swift   # 分类查看更多
│   ├── SubscriptionsView.swift  # 订阅列表
│   ├── DownloadsView.swift      # 下载管理
│   ├── SitesView.swift          # 站点管理
│   ├── SettingsView.swift       # 系统设置
│   ├── SystemStatusCard.swift   # 系统状态卡片
│   ├── CardButtonStyle.swift    # 卡片按钮样式
│   └── Components/              # 共享组件
│       ├── CachedAsyncImage.swift
│       ├── LoadingView.swift
│       └── EmptyStateView.swift
├── ViewModels/                  # 视图模型层（@MainActor）
│   ├── HomeViewModel.swift
│   ├── SearchViewModel.swift
│   ├── RecommendViewModel.swift
│   ├── MediaDetailViewModel.swift
│   ├── CategoryMoreViewModel.swift
│   ├── SubscriptionsViewModel.swift
│   ├── DownloadsViewModel.swift
│   ├── SitesViewModel.swift
│   └── SystemStatusViewModel.swift
├── Services/                    # 服务层
│   ├── APIService.swift         # API 请求 + URLCache 磁盘缓存
│   ├── AuthenticationManager.swift  # 认证管理
│   ├── LocalCacheManager.swift      # 本地缓存
│   └── WebSocketService.swift       # SSE 进度通道
├── Utilities/                   # 工具
│   ├── ColorTokens.swift        # 语义化颜色 token
│   ├── FontTokens.swift         # 语义化字体 token
│   ├── ImageCache.swift         # 图片缓存
│   ├── ImageLoader.swift        # 图片加载器
│   └── TopShelfHelper.swift     # Top Shelf + Deep Link 共享数据
└── Assets.xcassets/             # 图片资源 + Brand Assets
```

## 性能优化

### 并发加载
- 推荐页面使用 TaskGroup 并发加载 8 个分类
- 首页并发加载 3 个推荐源
- 系统状态并发获取存储和下载信息

### UI 优化
- 使用 LazyHStack 和 LazyVGrid 延迟加载
- CachedAsyncImage 异步加载图片（内存 50MB + 磁盘 500MB）
- 焦点状态仅影响当前元素
- 平滑动画过渡（0.2s）

### 内存管理
- Token 持久化存储在 UserDefaults
- URLCache 磁盘缓存减少网络请求
- 推荐数据在导航时保留，避免重复加载

## 常见问题

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

### Q: 什么是 TMDB API Key？必须配置吗？
**A:** 仅当使用豆瓣来源的影片时建议配置，用于自动查询 TMDB ID 以支持 Infuse 跳转播放。可以在应用的"设置"页面中填写。

### Q: 如何配置 Top Shelf？
**A:** 登录应用后，推荐内容会自动同步到 Apple TV 主屏幕的 Top Shelf。需要在 Xcode 中配置 App Group（`group.com.hvg.moviepilot-atv`）。

## 更新日志

### v1.2.0 (2026-04-28)

**新增：**
- 统一设计系统：ColorTokens（22 个语义颜色）和 FontTokens（16 个语义字体）
- 共享组件：LoadingView、EmptyStateView
- SettingsView 独立页面（TMDB API Key 配置、系统状态显示模式切换）

**改进：**
- 所有视图应用统一的 ColorTokens/FontTokens 设计系统
- 焦点动画统一为 0.2s
- CardButtonStyle 重命名为 `.cardButton` 解決 tvOS SDK 歧义
- 修复 MediaDetailView 加载动画（broken UUID() → @State 模式）
- 详情页加载时显示海报和标题，提升感知性能

### v1.1.0 (2026-01-19)

**新增：**
- 系统状态卡片（存储用量 + 下载/上传速度，5s 轮询）
- 紧凑型系统状态卡片 UI
- Top Shelf 集成 + Deep Linking
- 剧集详情面板
- 站点管理（启用/停用）
- 分页下载历史

**改进：**
- 推荐页面 8 个分类 TaskGroup 并发加载
- 首页缓存优先 + 后台刷新
- SearchView 500ms 防抖 + 取消上一次 Task
- Season 订阅支持
- UI 字体和边距优化

### v1.0.0 (2026-01-14)

- 初始版本
- 登录认证
- 首页、搜索、推荐
- 订阅管理基础功能
- URLSession 缓存配置

## 未来计划

- [ ] 搜索历史记录
- [ ] 高级搜索筛选（按类型、年份、分辨率等）
- [ ] 支持视频播放
- [ ] 多账户切换
- [ ] 国际化（i18n）支持
- [ ] 自动化测试

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用 GNU General Public License v3.0 (GPL-3.0)。详见 LICENSE 文件。

## 相关链接

- [Movie Pilot 项目](https://github.com/jxxghp/MoviePilot)
- [Movie Pilot API 文档](https://api.movie-pilot.org/)
- [Apple tvOS 开发文档](https://developer.apple.com/tvos/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui)

---

**最后更新**: 2026-04-29  
**版本**: v1.2.0  
**平台**: tvOS 17.0+
