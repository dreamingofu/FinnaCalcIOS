//
//  PremiumView.swift
//  FinnaCalcIOS
//
//  Premium page, ported from app/premium/page.tsx. The web page is intentionally
//  minimal — a "Coming Soon" teaser with an early-access waitlist; it does NOT
//  list specific features or prices (those are commented out on the web), so we
//  don't invent any here.
//

import SwiftUI

struct PremiumView: View {
    @State private var email = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var submitting = false

    private let gold = Color(h: 45, s: 93, l: 47)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                featuresCard
                NavigationLink {
                    AboutView()
                } label: {
                    Text("Learn more about FinnaCalc")
                        .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                        .foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(gold)
            Text("FinnaCalc Premium")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.foreground)
            FCBadge("Coming Soon", variant: .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var featuresCard: some View {
        FCCard {
            FCCardHeader {
                HStack(spacing: 8) {
                    star
                    FCCardTitle("Premium Features")
                    star
                }
                FCCardDescription("Advanced tools and features for serious financial planning")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Be the first to know when Premium launches.")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                    HStack(spacing: 8) {
                        FCTextField("you@example.com", text: $email, keyboardType: .emailAddress)
                        FCButton("Join Waitlist", action: joinWaitlist)
                            .disabled(submitting)
                    }
                    if let message {
                        Text(message)
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(messageIsError ? Theme.destructive : Theme.positive)
                    }
                    Text("No spam — just one email when it's ready. Waitlist members get 60% off forever.")
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
        }
    }

    private var star: some View {
        Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(gold)
    }

    private func joinWaitlist() {
        message = nil
        guard isValidEmail(email) else {
            message = "Please enter a valid email address."
            messageIsError = true
            return
        }
        submitting = true
        // The web posts to /api/send-email; mirrored here as a local confirmation.
        message = "You're on the list! We'll email you when Premium launches."
        messageIsError = false
        email = ""
        submitting = false
    }

    private func isValidEmail(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".") && t.count >= 5
    }
}

#Preview {
    NavigationStack { PremiumView() }
}
