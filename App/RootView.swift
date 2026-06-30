//
//  RootView.swift
//  FinnaCalcIOS
//
//  The app's navigation shell, ported from components/header.tsx's structure:
//  the five sections (Home, Budgeting, Investing, Taxes, Education) become tabs,
//  and the header's account dropdown becomes a trailing toolbar button that
//  opens the account sheet (signed in) or the sign-in sheet (signed out).
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        if auth.loading {
            SplashView()
        } else {
            MainTabs()
        }
    }
}

// MARK: - Tabs

private struct MainTabs: View {
    private enum Tab: Hashable { case home, budgeting, investing, taxes, education }
    @State private var selection: Tab = .home

    // FinnaBot lives at the shell so the conversation survives panel open/close.
    @StateObject private var chat = ChatViewModel()
    @State private var showChat = false

    var body: some View {
        TabView(selection: $selection) {
            screen(.home, "Home", "house") { HomeView() }
            screen(.budgeting, "Budgeting", "wallet.bifold") { BudgetingView() }
            screen(.investing, "Investing", "chart.line.uptrend.xyaxis") { InvestingView() }
            screen(.taxes, "Taxes", "doc.text") { TaxesView() }
            screen(.education, "Education", "book") { EducationView() }
        }
        .tint(Theme.primary)
        // Floating FinnaBot button (the web's global chatbot), above the tab bar.
        .overlay(alignment: .bottomTrailing) {
            Button { showChat = true } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 60)
            .accessibilityLabel("Open FinnaBot")
        }
        .sheet(isPresented: $showChat) { FinnaBotView(chat: chat) }
    }

    @ViewBuilder
    private func screen<Content: View>(
        _ tab: Tab,
        _ title: String,
        _ icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { AccountToolbarButton() }
                }
        }
        .tabItem { Label(title, systemImage: icon) }
        .tag(tab)
    }
}

// MARK: - Account button

private struct AccountToolbarButton: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var showAccount = false
    @State private var showAuth = false

    var body: some View {
        Button {
            if auth.user != nil { showAccount = true } else { showAuth = true }
        } label: {
            if let user = auth.user {
                Text(user.displayName)
                    .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                    .lineLimit(1)
            } else {
                Image(systemName: "person.crop.circle")
            }
        }
        .tint(Theme.primary)
        // Re-inject the env object so the sheets always resolve it.
        .sheet(isPresented: $showAccount) { AccountView().environmentObject(auth) }
        .sheet(isPresented: $showAuth) { AuthView().environmentObject(auth) }
    }
}

// MARK: - Splash

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            FCWordmark(size: 34)
            ProgressView().tint(Theme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    RootView().environmentObject(AuthManager())
}
