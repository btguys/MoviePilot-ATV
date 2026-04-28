import SwiftUI

/// Unified empty state display used across the app.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text(title)
                .font(.title2)
                .foregroundColor(.gray)

            if let subtitle {
                Text(subtitle)
                    .font(FontTokens.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

#Preview {
    VStack {
        EmptyStateView(icon: "film.stack", title: "未找到相关内容")
        EmptyStateView(icon: "bookmark.slash", title: "暂无订阅", subtitle: "去搜索页面添加订阅")
    }
    .background(Color.black)
}
