//
//  MoviePilotTVApp.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import SwiftUI

@main
struct MoviePilotTVApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}
