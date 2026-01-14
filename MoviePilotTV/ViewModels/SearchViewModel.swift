//
//  SearchViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MediaItem] = []
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var selectedMedia: MediaItem?
    @Published var showSubscribeSheet = false
    
    private let apiService = APIService.shared
    private var searchTask: Task<Void, Never>?
    
    init() {
        // Auto-search with debounce
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self, !query.isEmpty else {
                    self?.searchResults = []
                    return
                }
                self.performSearch()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        isSearching = true
        
        searchTask = Task {
            do {
                let results = try await apiService.searchMedia(keyword: searchQuery)
                
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "搜索失败: \(error.localizedDescription)"
                    showError = true
                }
            }
            
            isSearching = false
        }
    }
    
    func subscribeToMedia(season: Int?) {
        guard let media = selectedMedia else { return }
        
        Task {
            do {
                // Check if we have a valid TMDB ID
                guard let tmdbId = media.tmdbId else {
                    errorMessage = "无法订阅: 该内容缺少 TMDB ID"
                    showError = true
                    return
                }
                
                // Convert year from String to Int
                let yearInt: Int? = if let yearStr = media.year {
                    Int(yearStr)
                } else {
                    nil
                }
                
                try await apiService.addSubscription(
                    tmdbId: tmdbId,
                    name: media.title,
                    year: yearInt,
                    type: media.mediaType ?? "movie",
                    season: season
                )
                
                // Show success (could add a toast notification)
                print("Successfully subscribed to \(media.title)")
                
            } catch {
                errorMessage = "订阅失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}
