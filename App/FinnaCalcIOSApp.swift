//
//  FinnaCalcIOSApp.swift
//  FinnaCalcIOS
//
//  App entry point.
//

import SwiftUI

@main
struct FinnaCalcIOSApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            // Phase 2: the navigation shell (TabView) with auth state injected.
            // The design-system gallery still lives in DesignSystemGallery.swift
            // for previews/QA.
            RootView()
                .environmentObject(auth)
                // The renovated design ships DARK-FIRST; light is a future opt-in.
                .preferredColorScheme(.dark)
                .task {
                    // Forward the Supabase access token to the API client as a
                    // Bearer (the API doesn't require it yet — PLAN Phase 0).
                    APIClient.shared.tokenProvider = { [weak auth] in await auth?.accessToken() }
                }
        }
    }
}
