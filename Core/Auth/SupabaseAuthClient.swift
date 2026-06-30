//
//  SupabaseAuthClient.swift
//  FinnaCalcIOS
//
//  The supabase-swift-backed `AuthClient`. Compiled only when the package is
//  linked; `makeAuthClient()` falls back to `UnconfiguredAuthClient` otherwise.
//
//  This is a faithful port of the auth calls in `../FinnaCalc/lib/auth.tsx`:
//    signIn      → auth.signInWithPassword
//    signUp      → auth.signUp({ data: { name } }) → needsConfirmation = !session
//    signInApple → auth.signInWithIdToken (native, replaces the web OAuth redirect)
//    state       → getSession() + onAuthStateChange  →  authStateChanges
//

#if canImport(Supabase)

import Foundation
import Supabase

final class SupabaseAuthClient: AuthClient {
    private let client: SupabaseClient

    var isConfigured: Bool { true }

    /// Fails to build only if the configured URL doesn't parse, in which case
    /// `makeAuthClient()` returns the unconfigured fallback instead.
    init?() {
        guard let url = SupabaseConfig.url else { return nil }
        client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
    }

    func currentUser() -> AuthUser? {
        client.auth.currentUser.map(Self.mapUser)
    }

    func signIn(email: String, password: String) async throws {
        do {
            _ = try await client.auth.signIn(email: email.normalizedEmail, password: password)
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    func signUp(email: String, password: String, name: String) async throws -> SignUpResult {
        do {
            let response = try await client.auth.signUp(
                email: email.normalizedEmail,
                password: password,
                data: ["name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines))]
            )
            // Email-confirmation projects return a user but no session.
            return SignUpResult(needsConfirmation: response.session == nil)
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        } catch {
            throw AuthError.message(error.localizedDescription)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func accessToken() async -> String? {
        client.auth.currentSession?.accessToken
    }

    func authStateChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session.map { Self.mapUser($0.user) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Port of `toUser` in lib/auth.tsx: name is the trimmed `user_metadata.name`,
    /// falling back to the email's local part.
    private static func mapUser(_ user: User) -> AuthUser {
        let email = user.email ?? ""
        let metaName = (user.userMetadata["name"]?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Match JS `email.split("@")[0]` exactly, including the empty local-part
        // edge case ("@domain.com" → ""), which Swift's split() would drop.
        let fallback = email.components(separatedBy: "@").first ?? ""
        return AuthUser(id: user.id.uuidString, email: email, name: metaName.isEmpty ? fallback : metaName)
    }
}

private extension String {
    /// `email.trim().toLowerCase()` from the web sign-in/sign-up handlers.
    var normalizedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

#endif
