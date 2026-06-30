//
//  AuthClient.swift
//  FinnaCalcIOS
//
//  Backend-agnostic auth surface. `AuthManager` talks to this protocol so the
//  app compiles and runs whether or not the supabase-swift package is present
//  and whether or not credentials are configured.
//

import Foundation

protocol AuthClient: AnyObject {
    /// False when Supabase isn't configured (mirrors `isSupabaseConfigured`).
    var isConfigured: Bool { get }

    /// Best-effort synchronous snapshot of the current user (may be nil until
    /// the persisted session finishes loading; the stream below is the source
    /// of truth).
    func currentUser() -> AuthUser?

    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, name: String) async throws -> SignUpResult
    func signInWithApple(idToken: String, nonce: String) async throws
    func signOut() async

    /// Emits on every session change. The first value is the restored session
    /// on launch — equivalent to `getSession()` followed by `onAuthStateChange`
    /// in lib/auth.tsx.
    func authStateChanges() -> AsyncStream<AuthUser?>
}

/// Used when Supabase isn't configured (or the package isn't linked): the app
/// behaves as a signed-out client and never crashes — the native counterpart of
/// lib/auth.tsx short-circuiting on `!isSupabaseConfigured`.
final class UnconfiguredAuthClient: AuthClient {
    var isConfigured: Bool { false }
    func currentUser() -> AuthUser? { nil }
    func signIn(email: String, password: String) async throws { throw AuthError.notConfigured }
    func signUp(email: String, password: String, name: String) async throws -> SignUpResult { throw AuthError.notConfigured }
    func signInWithApple(idToken: String, nonce: String) async throws { throw AuthError.notConfigured }
    func signOut() async {}
    func authStateChanges() -> AsyncStream<AuthUser?> { AsyncStream { $0.finish() } }
}

/// Resolves the concrete client: the Supabase-backed one when the package is
/// available *and* credentials are set, otherwise the unconfigured fallback.
func makeAuthClient() -> AuthClient {
    #if canImport(Supabase)
    if SupabaseConfig.isConfigured, let client = SupabaseAuthClient() {
        return client
    }
    #endif
    return UnconfiguredAuthClient()
}
