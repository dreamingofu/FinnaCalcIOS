//
//  AuthView.swift
//  FinnaCalcIOS
//
//  Sign in / sign up sheet. Ports the auth actions from lib/auth.tsx
//  (email+password, name on sign-up, needs-confirmation handling) and adds
//  native Sign in with Apple. Google is stubbed for a later update, per PLAN.md.
//
//  Phase 8 polishes the standalone sign-in / sign-up screens; this is the
//  functional version that makes the AuthManager usable now.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case signUp = "Sign up"
        var id: String { rawValue }
    }

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var working = false
    @State private var currentNonce: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && (mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    FCWordmark(size: 30)
                        .padding(.top, 8)

                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _ in errorText = nil; infoText = nil }

                    if !auth.configured {
                        FCBadge("Accounts aren’t configured yet", variant: .secondary)
                    }

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            FCTextField("Name", text: $name)
                        }
                        FCTextField("Email", text: $email, keyboardType: .emailAddress)
                        FCTextField("Password", text: $password, isSecure: true)
                    }

                    if let errorText {
                        message(errorText, color: Theme.destructive)
                    }
                    if let infoText {
                        message(infoText, color: Theme.mutedForeground)
                    }

                    FCButton(size: .lg, label: {
                        Text(mode == .signIn ? "Sign in" : "Create account")
                            .frame(maxWidth: .infinity)
                    }, action: submit)
                    .disabled(working || !canSubmit)

                    dividerOr

                    SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleApple)
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .disabled(working)

                    FCButton(variant: .outline, size: .lg, label: {
                        Text("Continue with Google").frame(maxWidth: .infinity)
                    }, action: {})
                    .disabled(true)
                    Text("Google sign-in arrives in a later update.")
                        .font(Theme.sans(Theme.FontSize.xs))
                        .foregroundStyle(Theme.mutedForeground)
                }
                .padding(24)
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dividerOr: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text("or").font(Theme.sans(Theme.FontSize.xs)).foregroundStyle(Theme.mutedForeground)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Email / password

    private func submit() {
        errorText = nil
        infoText = nil
        working = true
        Task { @MainActor in
            do {
                switch mode {
                case .signIn:
                    try await auth.signIn(email: email, password: password)
                    dismiss()
                case .signUp:
                    let result = try await auth.signUp(email: email, password: password, name: name)
                    if result.needsConfirmation {
                        infoText = "Check your email to confirm your account, then sign in."
                        mode = .signIn
                    } else {
                        dismiss()
                    }
                }
            } catch {
                errorText = describe(error)
            }
            working = false
        }
    }

    // MARK: Apple

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleAuth.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleAuth.sha256(nonce)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // Quietly ignore the user backing out of the Apple sheet.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled { return }
            errorText = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorText = "Apple sign-in failed: no identity token was returned."
                return
            }
            working = true
            Task { @MainActor in
                do {
                    try await auth.signInWithApple(idToken: idToken, nonce: nonce)
                    dismiss()
                } catch {
                    errorText = describe(error)
                }
                working = false
            }
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? AuthError)?.errorDescription ?? error.localizedDescription
    }
}

#Preview {
    AuthView().environmentObject(AuthManager())
}
