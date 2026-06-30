//
//  FinnaCalcIOSApp.swift
//  FinnaCalcIOS
//
//  App entry point.
//

import SwiftUI

@main
struct FinnaCalcIOSApp: App {
    var body: some Scene {
        WindowGroup {
            // Phase 1: the root is the design-system gallery so the app is
            // runnable on its own and you can eyeball every FC* component.
            // Phase 2 replaces this with the real navigation shell
            // (auth-gated TabView), per PLAN.md.
            DesignSystemGallery()
        }
    }
}
