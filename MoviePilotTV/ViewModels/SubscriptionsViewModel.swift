//
//  SubscriptionsViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

@MainActor
class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var filteredSubscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let apiService = APIService.shared
    private var currentFilter: SubscriptionFilter = .all
    
    func loadSubscriptions() {
        isLoading = true
        
        Task {
            do {
                subscriptions = try await apiService.getSubscriptions()
                filterSubscriptions(by: currentFilter)
            } catch {
                errorMessage = "加载订阅失败: \(error.localizedDescription)"
                showError = true
            }
            
            isLoading = false
        }
    }
    
    func filterSubscriptions(by filter: SubscriptionFilter) {
        currentFilter = filter
        
        switch filter {
        case .all:
            filteredSubscriptions = subscriptions
        case .movie:
            filteredSubscriptions = subscriptions.filter { $0.isMovie }
        case .tv:
            filteredSubscriptions = subscriptions.filter { $0.isTV }
        }
    }
    
    func deleteSubscription(_ subscription: Subscription) {
        guard let id = subscription.id else {
            errorMessage = "订阅ID无效，无法删除。"
            showError = true
            return
        }
        Task {
            do {
                try await apiService.deleteSubscription(id: id)
                // Remove from local list
                subscriptions.removeAll { $0.id == id }
                filterSubscriptions(by: currentFilter)
            } catch {
                errorMessage = "删除订阅失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}
