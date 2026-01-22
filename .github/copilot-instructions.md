# AI Coding Agent Instructions for MoviePilot-ATV

## Project Overview
MoviePilot-ATV is a tvOS 17.0+ client for [Movie Pilot](https://github.com/jxxghp/MoviePilot), built with SwiftUI. It provides browsing, searching, and subscription management for movies and TV shows.

## Architecture Pattern: MVVM with Service Layer

### Core Components
- **Views/**: SwiftUI views using `TabView` navigation ([MainView.swift](../MoviePilotTV/Views/MainView.swift))
- **ViewModels/**: `@MainActor` classes with `@Published` properties for UI state
- **Services/**: Singleton services (`APIService`, `AuthenticationManager`, `LocalCacheManager`)
- **Models/**: Codable structs for API responses

### Data Flow
1. **Cache-First Pattern**: Load cached data immediately, then refresh from network in background
   - See [HomeViewModel.swift](../MoviePilotTV/ViewModels/HomeViewModel.swift) `loadData()` method
2. **Concurrent Loading**: Use `async let` and `TaskGroup` for parallel API requests
   - Example: [RecommendViewModel.swift](../MoviePilotTV/ViewModels/RecommendViewModel.swift) loads 8 categories concurrently

## Key Conventions

### Concurrency
- All ViewModels must use `@MainActor` to avoid thread-safety issues
- Use `async/await` with `Task {}` for network calls - never blocking calls on MainActor
- Example pattern from [HomeViewModel.swift](../MoviePilotTV/ViewModels/HomeViewModel.swift#L31-L33):
  ```swift
  Task {
      await refreshData()
  }
  ```

### State Management
- `AuthenticationManager.shared`: Centralized auth state, persists tokens to UserDefaults
- `LocalCacheManager.shared`: Multi-key caching for home, recommendations, subscriptions
- Session state stored in UserDefaults keys: `apiEndpoint`, `accessToken`, `tmdbApiKey`

### Image Caching
- Always use `CachedAsyncImage` component (not `AsyncImage`) for performance
- Two-tier cache: memory (500MB) + disk (via [ImageCache.swift](../MoviePilotTV/Utilities/ImageCache.swift))
- Custom `ImageLoader` manages lifecycle with `onAppear`/`onDisappear`

### API Integration
- Base service: [APIService.swift](../MoviePilotTV/Services/APIService.swift) with URL caching enabled
- Form-encoded login: `/api/v1/login/access-token` returns Bearer token
- All requests include `Authorization: Bearer <token>` header
- Handle 401 by showing `tokenExpiredAlert` from `AuthenticationManager`

## Critical Workflows

### Build & Run
```bash
# Open in Xcode
open MoviePilot-ATV.xcodeproj

# Select Apple TV 4K simulator or physical device
# Run with ⌘R - app auto-logs in with saved credentials
```

### App Groups Setup
- **Required** for TopShelf extension: `group.com.hvg.moviepilot-atv`
- Shared data: `accessToken`, cached recommendations for Top Shelf
- Verify in [ContentProvider.swift](../MoviePilotTVTopShelf/ContentProvider.swift) and [TopShelfHelper.swift](../MoviePilotTV/Utilities/TopShelfHelper.swift)

### System Status Polling
- [SystemStatusViewModel.swift](../MoviePilotTV/ViewModels/SystemStatusViewModel.swift): 5-second timer
- Endpoints: `/api/v1/dashboard/storage` + `/api/v1/dashboard/downloader`
- First load fetches both, subsequent polls reuse storage cache

## tvOS-Specific Patterns

### Focus Management
- Use `@FocusState` for tab navigation (see [MainView.swift](../MoviePilotTV/Views/MainView.swift))
- Never force-unwrap focus states - tvOS handles focus automatically
- Card buttons use `.buttonStyle(CardButtonStyle())` for focus effects

### Navigation
- `NavigationStack` with typed `NavigationPath` for deep linking
- Deep link scheme: `moviepilot://media?source=<source>&id=<id>&title=<title>`
- Handle in [MoviePilotTVApp.swift](../MoviePilotTV/MoviePilotTVApp.swift) `onOpenURL`

### Layout
- Use `LazyHStack`/`LazyVGrid` for scrollable collections (performance)
- Standard image sizes: Poster 200x300, Backdrop 540x300
- Typography: Title 28-34px, Body 17-24px, Caption 13-16px

## Integration Points

### Movie Pilot API
- Standard endpoints: `/api/v1/recommend/{source}`, `/api/v1/media/search`, `/api/v1/subscribe`
- Response format: Direct array or `{ success: bool, data: [...], message: "" }`
- Full endpoint mapping in [README.md](../README.md#-api-端点映射)

### TMDB Integration
- TMDB API key stored in UserDefaults via `AuthenticationManager.saveTmdbApiKey()`
- Used for credits endpoint: `/api/v1/tmdb/credits/{tmdb_id}`

### WebSocket/SSE
- [WebSocketService.swift](../MoviePilotTV/Services/WebSocketService.swift) uses Server-Sent Events, not WebSockets
- Publishes `ProgressMessage` for real-time search/download progress
- Custom `AnyCodable` type for flexible JSON decoding

## Common Patterns to Follow

### Adding New Recommendation Category
1. Add endpoint to [APIService.swift](../MoviePilotTV/Services/APIService.swift) `getRecommendations()`
2. Update [RecommendViewModel.swift](../MoviePilotTV/ViewModels/RecommendViewModel.swift) `categories` array
3. Add cache key to [LocalCacheManager.swift](../MoviePilotTV/Services/LocalCacheManager.swift)

### Adding New View
1. Create ViewModel with `@MainActor`, singleton service references
2. Add `NavigationItem` enum case to [MainView.swift](../MoviePilotTV/Views/MainView.swift)
3. Use `@StateObject private var viewModel = XViewModel()` pattern
4. Implement cache-first loading if applicable

## Testing & Debugging
- No automated tests currently - manual testing in tvOS simulator
- Debug prints use emoji prefixes: 🔵 Network, ✅ Success, ❌ Error, 🔝 TopShelf
- Use SystemStatusCard in HomeView to verify network connectivity

## What NOT to Do
- Never use `AsyncImage` directly - always use `CachedAsyncImage`
- Never make network calls on MainActor without `await`
- Never hardcode server URLs - always use `AuthenticationManager.apiEndpoint`
- Never bypass URLSession cache policy - it's configured for disk caching
- Don't create ViewModels with `@ObservedObject` - use `@StateObject`
