import SwiftUI

struct CachedAsyncImage<Content>: View where Content: View {
    @StateObject private var loader: ImageLoader
    private let content: (AsyncImagePhase) -> Content
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .onAppear { loader.load() }
            .onDisappear { loader.cancel() }  // 清理资源
            .onChange(of: loader.image) { _ in }
    }
    
    private var phase: AsyncImagePhase {
        if let image = loader.image {
            return .success(Image(uiImage: image))
        } else if let error = loader.error {
            return .failure(error)
        } else {
            return .empty
        }
    }
}
