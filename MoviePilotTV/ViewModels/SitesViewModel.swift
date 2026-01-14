//
//  SitesViewModel.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

@MainActor
class SitesViewModel: ObservableObject {
    @Published var sites: [Site] = []
    @Published var siteUserData: [String: SiteUserData] = [:] // 站点domain -> 流量数据
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let apiService = APIService.shared
    
    func loadSites() {
        isLoading = true
        
        Task {
            do {
                // 并行加载站点列表和流量数据
                async let sitesResult = apiService.getSites()
                async let userDataResult = apiService.getSiteUserData()
                
                sites = try await sitesResult
                let userData = try await userDataResult
                
                // 将流量数据转换为字典，使用domain作为key
                siteUserData = Dictionary(uniqueKeysWithValues: userData.map { ($0.domain, $0) })
                
                print("✅ [SitesViewModel] 成功加载 \(sites.count) 个站点和 \(userData.count) 个流量数据")
            } catch {
                errorMessage = "加载站点失败: \(error.localizedDescription)"
                showError = true
                print("❌ [SitesViewModel] 加载站点失败: \(error)")
            }
            
            isLoading = false
        }
    }
}
