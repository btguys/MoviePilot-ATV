# MoviePilot-ATV 智能助手功能規劃

## 1. 背景與目標

MoviePilot 後端已支援智能助手（Agent）模組，基於 MCP（Model Context Protocol）協議，允許 AI 理解用戶自然語意並調用系統工具（搜尋、訂閱、下載、站點管理等）。MoviePilot-ATV 目前缺乏語音/對話式交互能力，本功能旨在：

- 為 Apple TV 用戶提供自然語言驅動的智能助手入口
- 支援 Siri 遙控器語音輸入，降低文字輸入成本
- 與 MoviePilot 後端 MCP API 無縫整合

## 2. 核心設計決策

### 2.1 喚醒方式（兩層入口）

| 入口 | 觸發方式 | 說明 |
|------|---------|------|
| 主要入口 | **長按 Menu 按鍵** | 任意介面隨時喚醒，符合 ATV 用戶習慣 |
| 輔助入口 | **TabBar 右側 🎤 按鈕** | 方向鍵導航到達，提供視覺可見性 |

### 2.2 面板呈現

全屏 Overlay 形式（`.overlay` + ZStack），不影響當前頁面狀態，返回時完全恢復。

### 2.3 語音輸入流程

```
面板 TextField 自動聚焦 → tvOS 鍵盤 + Siri 麥克風按鈕出現
       ↓
用戶按住 Siri 按鈕說話 → tvOS 語音識別 → 文字進入 TextField
       ↓
2.5 秒無新文字 → 自動提交
       ↓
Agent 回覆 + 工具結果卡片
```

> **限制說明**：tvOS 不提供公開 API 監聽 Siri 按鈕按下/鬆開狀態，「Listening...」指示基於 `onChange` 文字變化 + 計時器推估。

### 2.4 API 整合方式

不走完整 MCP SDK，直接調用 REST API：

```
POST /api/v1/mcp/tools/call
  {
    "tool_name": "search_media",
    "arguments": { "keyword": "魷魚遊戲" }
  }
```

## 3. 架構設計

### 3.1 新增檔案結構

```
MoviePilotTV/
├── Services/
│   └── AgentService.swift        # MCP 工具調用封裝
├── ViewModels/
│   └── AgentViewModel.swift      # 對話狀態管理
├── Views/
│   ├── AgentPanelView.swift      # 全屏對話面板（overlay）
│   └── Components/
│       ├── AgentMessageBubble.swift       # 消息氣泡
│       ├── AgentToolResultCard.swift      # 工具結果卡片
│       ├── AgentInputBar.swift           # 輸入區域
│       └── FloatingAssistantButton.swift  # TabBar 浮動按鈕
└── Models/
    └── AgentMessage.swift        # 消息模型
```

### 3.2 組件依賴關係

```
MainView (TabView + FloatingAssistantButton)
       │
       ├─ selectedTab 切換
       └─ 硬體按鍵（Menu 長按）
              │
              ↓
AgentPanelView（全屏 overlay）
       │
       ├─ AgentMessageBubble（滾動消息列表）
       ├─ AgentToolResultCard（工具結果展示）
       └─ AgentInputBar（TextField + 語音狀態）
              │
              ↓
AgentViewModel（狀態管理）
       │
       ↓
AgentService（MCP REST API 封裝）
       │
       ↓
MoviePilot 後端 /api/v1/mcp/*
```

## 4. API 設計

### 4.1 AgentService

```swift
// MoviePilotTV/Services/AgentService.swift
@MainActor
class AgentService {
    static let shared = AgentService()
    private let apiEndpoint: String
    private let authManager = AuthenticationManager.shared

    /// 列出所有可用工具
    func listTools() async throws -> [MCPTool]

    /// 調用指定工具
    func callTool(name: String, arguments: [String: Any]) async throws -> AgentResponse
}
```

### 4.2 MCP API 端點

| 端點 | 方法 | 用途 |
|------|------|------|
| `/api/v1/mcp/tools` | GET | 列出所有可用工具 |
| `/api/v1/mcp/tools/call` | POST | 調用指定工具 |
| `/api/v1/mcp/tools/{name}` | GET | 獲取工具詳情 |

### 4.3 認證

復用現有 `AuthenticationManager.shared.accessToken`，以 `Bearer` Token 附加於請求 Header。

## 5. ViewModel 設計

```swift
// MoviePilotTV/ViewModels/AgentViewModel.swift
@MainActor
class AgentViewModel: ObservableObject {
    // 對話歷史
    @Published var messages: [AgentMessage] = []

    // 狀態
    @Published var isLoading = false
    @Published var isListening = false  // 語音識別中
    @Published var showError = false
    @Published var errorMessage = ""

    // 工具結果
    @Published var pendingToolCall: AgentToolCall?

    func sendMessage(_ text: String) async
    func handleToolResult(_ result: AgentResponse) async
    func clearHistory()
}
```

### 5.1 消息模型

```swift
struct AgentMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole  // .user / .agent / .tool
    let content: String
    let toolName: String?       // tool role 專用
    let timestamp: Date

    enum MessageRole: String, Codable {
        case user
        case agent
        case tool
    }
}

struct AgentToolCall {
    let id: UUID
    let toolName: String
    let arguments: [String: Any]
}
```

## 6. View 設計

### 6.1 AgentPanelView（全屏面板）

- ZStack 全屏黑色半透明背景（`Color.black.opacity(0.95)`）
- 頂部：標題欄（「智能助手」）+ 關閉按鈕
- 中部：`ScrollView` 懶加載消息列表（`LazyVStack`）
- 底部：`AgentInputBar` 輸入區域
- 進場動畫：`.transition(.opacity)`
- 退場：按 Menu 或點擊關閉按鈕

### 6.2 AgentMessageBubble

| 角色 | 樣式 |
|------|------|
| user | 右側對齊，背景用 `Color.accentColor`，文字白色 |
| agent | 左側對齊，背景用深灰（`Color(white: 0.15)`），文字白色 |
| tool | 左側對齊，背景用深綠，內容為 `AgentToolResultCard` |

### 6.3 AgentToolResultCard

工具執行結果的格式化卡片，根據 `toolName` 渲染不同內容：

| toolName | 卡片內容 |
|----------|---------|
| `search_media` | 媒體列表卡片（海報 + 標題 + 年份 + 評分）|
| `add_subscribe` | 訂閱成功提示 + 狀態 |
| `download` | 下載任務卡片（標題 + 進度）|
| 其他 | 通用文字卡片 |

### 6.4 AgentInputBar

- `TextField`：置中提示文字「按住 Siri 遙控器說話」
- `FocusState` 控制自動聚焦
- `onChange(of: text)` + Timer 實現「說完自動提交」
- 右側麥克風按鈕（`mic.fill`），按下後手動聚焦 TextField
- 發送時顯示 `ProgressView`

### 6.5 FloatingAssistantButton

- 位於 TabBar 右側內側（需要自定義 TabBar）
- `Circle` 背景，`waveform.badge.plus` 圖示
- 聚焦時有 `ScaleFocusButtonStyle` 放大效果
- 點擊後開啟 `AgentPanelView`

## 7. TabBar 浮動按鈕實現

標準 `TabView.tabItem` 不支援混入自訂按鈕，需替換為自定義 TabBar：

```swift
struct CustomTabBar: View {
    @Binding var selectedTab: NavigationItem
    let onAgentTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems) { item in
                tabItem(for: item)
            }
            // 浮動助理按鈕
            FloatingAssistantButton(action: onAgentTapped)
        }
        .padding(.horizontal, 16)
    }
}
```

> **注意**：此變更涉及修改 `MainView` 的 TabView 結構，需同步更新 `MainView` 中所有引用 `selectedTab` 的邏輯。

## 8. 硬體按鍵監聽

### 8.1 長按 Menu 喚醒面板

在包裝的 `UIViewController` 層級監聽按鍵事件：

```swift
// MoviePilotTV/Views/Components/KeyEventView.swift
struct KeyEventView: UIViewControllerRepresentable {
    let onMenuLongPress: () -> Void

    func makeUIViewController(context: Context) -> KeyEventViewController {
        let vc = KeyEventViewController()
        vc.onMenuLongPress = onMenuLongPress
        return vc
    }
}

class KeyEventViewController: UIViewController {
    var onMenuLongPress: (() -> Void)?
    private var menuPressTimer: Timer?

    override func pressesBegan(_ event: UIPressesEvent, with session: UIPressesSession) {
        if event.keyCode == .keyboardMenu {
            menuPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.onMenuLongPress?()
            }
        }
    }

    override func pressesEnded(_ event: UIPressesEvent, with session: UIPressesSession) {
        menuPressTimer?.invalidate()
        menuPressTimer = nil
    }
}
```

### 8.2 Menu 按鍵結束面板

面板開啟時監聽 Menu 按鍵，觸發後關閉面板：

```swift
// AgentPanelView 中
struct AgentPanelView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ...內容
        }
        .onReceive(keyPublisher) { event in
            if event == .menu {
                dismiss()
            }
        }
    }
}
```

## 9. MVP 範圍

### 9.1 必須完成（MVP）

- [ ] `AgentService` — MCP 工具調用封裝（`POST /api/v1/mcp/tools/call`）
- [ ] `AgentViewModel` — 基本對話狀態管理
- [ ] `AgentPanelView` — 全屏對話面板（overlay 形式）
- [ ] `AgentMessageBubble` — user / agent 消息氣泡
- [ ] `AgentToolResultCard` — 搜索結果卡片（`search_media` 工具）
- [ ] `AgentInputBar` — 輸入框 + 自動提交邏輯
- [ ] `FloatingAssistantButton` — TabBar 浮動按鈕（需自定義 TabBar）
- [ ] `MainView` 整合 — 浮動按鈕綁定 + 開啟面板
- [ ] Menu 長按喚醒面板（`UIViewControllerRepresentable`）

### 9.2 可延後（V2）

- [ ] 完整的 `AgentTabView`（獨立 Tab 頁面）
- [ ] 更多工具的結果卡片（`add_subscribe`、`download` 等）
- [ ] SSE 流式輸出（Agent 回覆打字機效果）
- [ ] 對話歷史本地緩存
- [ ] 記憶功能（記住用戶偏好）

## 10. 關鍵檔案清單

### 10.1 新增檔案

| 檔案路徑 | 說明 |
|---------|------|
| `MoviePilotTV/Services/AgentService.swift` | MCP API 調用封裝 |
| `MoviePilotTV/ViewModels/AgentViewModel.swift` | 對話 ViewModel |
| `MoviePilotTV/Views/AgentPanelView.swift` | 全屏對話面板 |
| `MoviePilotTV/Views/Components/AgentMessageBubble.swift` | 消息氣泡元件 |
| `MoviePilotTV/Views/Components/AgentToolResultCard.swift` | 工具結果卡片 |
| `MoviePilotTV/Views/Components/AgentInputBar.swift` | 輸入區域元件 |
| `MoviePilotTV/Views/Components/FloatingAssistantButton.swift` | 浮動按鈕元件 |
| `MoviePilotTV/Views/Components/KeyEventView.swift` | 硬體按鍵監聽包裝 |
| `MoviePilotTV/Models/AgentMessage.swift` | 消息資料模型 |

### 10.2 修改檔案

| 檔案路徑 | 變更說明 |
|---------|---------|
| `MoviePilotTV/Views/MainView.swift` | 整合浮動按鈕 + 面板開關狀態 + 自定義 TabBar |

## 11. 測試驗證

### 11.1 功能驗證清單

- [ ] 在任意 Tab 頁面長按 Menu → AgentPanelView 正確彈出
- [ ] 點擊 TabBar 右側 🎤 按鈕 → AgentPanelView 正確彈出
- [ ] TextField 自動聚焦，tvOS 鍵盤 + Siri 麥克風按鈕出現
- [ ] 按住 Siri 按鈕說話 → 語音識別為文字並填入 TextField
- [ ] 說完 2.5 秒後自動發送，無需用戶點擊確認
- [ ] Agent 回覆正確顯示在消息列表
- [ ] `search_media` 工具結果以卡片形式展示
- [ ] 按 Menu 鍵 → 面板關閉，回到之前頁面
- [ ] 面板關閉後焦點正確恢復到之前的元素
- [ ] 網路錯誤時顯示友好錯誤提示

### 11.2 API 驗證

```bash
# 列出所有工具
curl -H "X-API-KEY: $API_KEY" http://localhost:3001/api/v1/mcp/tools

# 調用搜索工具
curl -X POST -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"tool_name": "search_media", "arguments": {"keyword": "魷魚遊戲"}}' \
  http://localhost:3001/api/v1/mcp/tools/call
```

## 12. 技術債與已知限制

1. **自定義 TabBar**：標準 `TabView.tabItem` 不支援自訂按鈕混入，需要重構 `MainView` 為自定義 `HStack` TabBar
2. **語音結束檢測**：tvOS 無公開 API，只能靠 Timer 推估，建議值 2.5 秒
3. **Menu 長按監聽**：需要 UIKit 層級的 `pressesBegan/Ended` 處理
4. **MCP 通訊協議**：首版僅使用 REST 封裝，未實現完整 MCP SDK 的會話管理
5. **流式輸出**：首版不支援 SSE 流式，Agent 回覆為一次性完整返回

## 13. 開發順序

```
Phase 1: 基礎設施
  1. AgentMessage 模型
  2. AgentService（MCP REST 封裝）
  3. AgentViewModel

Phase 2: 面板 UI
  4. AgentMessageBubble
  5. AgentInputBar
  6. AgentToolResultCard（search_media 結果卡片）
  7. AgentPanelView（組合以上元件）

Phase 3: 整合
  8. KeyEventView（Menu 長按監聽）
  9. FloatingAssistantButton
  10. 自定義 TabBar（CustomTabBar）
  11. MainView 整合

Phase 4: 驗收
  12. 完整功能測試
  13. UI 微調
```
