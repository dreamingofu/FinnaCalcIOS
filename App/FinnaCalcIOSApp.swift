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
        }
    }
}
