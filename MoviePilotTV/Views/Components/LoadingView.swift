import SwiftUI

/// Unified loading indicator used across the app.
struct LoadingView: View {
    let message: String

    init(_ message: String = "加载中...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text(message)
                .font(FontTokens.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

#Preview {
    VStack {
        LoadingView()
        LoadingView("正在获取影片详情")
    }
    .background(Color.black)
}
