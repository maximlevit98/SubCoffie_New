//
//  SubscribeCoffieCleanApp.swift
//  SubscribeCoffieClean
//
//  Created by Максим on 11.01.2026.
//

import SwiftUI

@main
struct SubscribeCoffieCleanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callbacks for Google and Apple sign in
                    Task {
                        do {
                            try await AuthService.shared.handleOAuthCallback(url: url)
                        } catch {
                            print("❌ Failed to handle OAuth callback: \(error)")
                        }
                    }
                }
        }
    }
}
