//
//  AccountView.swift
//  FinnaCalcIOS
//
//  Signed-in account sheet — the native equivalent of the header dropdown in
//  components/header.tsx (name + email, and Sign out).
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let user = auth.user {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(Theme.sans(20, weight: .semibold))
                                .foregroundStyle(Theme.foreground)
                            Text(user.email)
                                .font(Theme.sans(Theme.FontSize.sm))
                                .foregroundStyle(Theme.mutedForeground)
                        }
                    }

                    VStack(spacing: 0) {
                        linkRow("Premium") { PremiumView() }
                        Divider()
                        linkRow("Advising") { AdvisingView() }
                        Divider()
                        linkRow("About") { AboutView() }
                        Divider()
                        linkRow("Privacy Policy") { PrivacyView() }
                        Divider()
                        linkRow("Terms of Service") { TermsView() }
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))

                    FCButton(variant: .destructive, size: .lg, label: {
                        Text("Sign out").frame(maxWidth: .infinity)
                    }, action: {
                        working = true
                        Task { @MainActor in
                            await auth.signOut()
                            dismiss()
                        }
                    })
                    .disabled(working)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow<Destination: View>(_ title: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                    .font(Theme.sans(Theme.FontSize.base))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AccountView().environmentObject(AuthManager())
}
