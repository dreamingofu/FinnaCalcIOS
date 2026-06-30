//
//  AuthManager.swift
//  FinnaCalcIOS
//
//  Observable auth state for the app — the SwiftUI counterpart of the
//  `AuthProvider` / `useAuth` context in `../FinnaCalc/lib/auth.tsx`.
//

import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    /// The signed-in user, or nil. Mirrors `useAuth().user`.
    @Published private(set) var user: AuthUser?
    /// True until the initial session restore resolves. Mirrors `useAuth().loading`.
    @Published private(set) var loading: Bool

    /// Whether Supabase is configured. Mirrors `useAuth().configured`.
    let configured: Bool

    private let client: AuthClient
    private var stateTask: Task<Void, Never>?

    init(client: AuthClient = makeAuthClient()) {
        self.client = client
        self.configured = client.isConfigured

        guard client.isConfigured else {
            // No credentials → behave as a signed-out app, not loading.
            self.user = nil
            self.loading = false
            return
        }

        self.user = client.currentUser()
        self.loading = true

        // Restore session + subscribe to changes. The stream's first emission is
        // the restored session, like getSession() then onAuthStateChange().
        // Capture `self` weakly per-iteration so the long-lived task doesn't
        // form a retain cycle with the manager.
        stateTask = Task { [weak self] in
            guard let stream = self?.client.authStateChanges() else { return }
            for await newUser in stream {
                guard let self else { return }
                self.user = newUser
                self.loading = false
            }
        }

        // Don't sit on a splash forever if the first event is slow to arrive.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if self?.loading == true { self?.loading = false }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, name: String) async throws -> SignUpResult {
        try await client.signUp(email: email, password: password, name: name)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.signInWithApple(idToken: idToken, nonce: nonce)
    }

    func signOut() async {
        await client.signOut()
        user = nil
    }
}
