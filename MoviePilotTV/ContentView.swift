//
//  ContentView.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Image Cache Utilities
// Moved here to ensure compilation without modifying Xcode project structure manually

class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 200 // Maximum number of images
        cache.totalCostLimit = 1024 * 1024 * 200 // 200 MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellable: AnyCancellable?
    private let url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else { return }
        
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.isLoading = false
                self?.image = image
                if let image = image {
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                }
            }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

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
            .onChange(of: loader.image) { _ in } // Force update
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
