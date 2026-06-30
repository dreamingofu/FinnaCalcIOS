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
            VStack(alignment: .leading, spacing: 24) {
                if let user = auth.user {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(user.email)
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }

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

                Spacer()
            }
            .padding(24)
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
}

#Preview {
    AccountView().environmentObject(AuthManager())
}
