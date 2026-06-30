//
//  AuthModels.swift
//  FinnaCalcIOS
//
//  Auth value types, ported from `../FinnaCalc/lib/auth.tsx`.
//

import Foundation

/// Mirrors the web `User` type: `{ id, email, name }`.
struct AuthUser: Equatable, Identifiable {
    let id: String
    let email: String
    let name: String

    /// What the header shows on the account chip: name, falling back to email.
    var displayName: String { name.isEmpty ? email : name }
}

/// Mirrors the web `SignUpResult`. When Supabase requires email confirmation it
/// returns a user but no session, so `needsConfirmation` is true.
struct SignUpResult: Equatable {
    let needsConfirmation: Bool
}

/// Mirrors the web `OAuthProvider` union.
enum OAuthProvider: String {
    case google
    case apple
}

enum AuthError: LocalizedError, Equatable {
    /// Supabase URL/anon key not set (or the package isn't present) — the app
    /// runs signed-out, exactly like the web's `isSupabaseConfigured === false`.
    case notConfigured
    case canceled
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Accounts aren’t available yet — Supabase credentials haven’t been configured."
        case .canceled:
            return "Sign-in was canceled."
        case .message(let text):
            return text
        }
    }
}
