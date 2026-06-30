//
//  AppleAuth.swift
//  FinnaCalcIOS
//
//  Nonce helpers for native Sign in with Apple. The flow:
//    1. generate a random nonce; send its SHA-256 in the Apple request
//    2. on success, hand Supabase the raw nonce + identity token via
//       signInWithIdToken (see SupabaseAuthClient.signInWithApple)
//  This is the standard pattern from Apple's and Supabase's docs.
//
//  NOTE: Sign in with Apple needs the "Sign in with Apple" capability enabled on
//  the target (Signing & Capabilities) and a configured Apple provider in
//  Supabase Auth. The button compiles and lays out without it; it just won't
//  complete a sign-in at runtime until the capability is added.
//

import Foundation
import CryptoKit

enum AppleAuth {
    /// A cryptographically-random nonce of the given length.
    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var byte: UInt8 = 0
                if SecRandomCopyBytes(kSecRandomDefault, 1, &byte) != errSecSuccess {
                    byte = UInt8.random(in: 0...255)
                }
                return byte
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// Lowercase hex SHA-256, as required for the Apple request's `nonce`.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
