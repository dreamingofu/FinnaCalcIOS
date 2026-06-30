//
//  AdvisingView.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/app/advising/page.tsx`.
//  Personal Financial Advising offering — a "Coming Soon to Premium" marketing
//  page with a feature list, an email-notify capture, and CTAs back to the free
//  calculators. Built on the Phase 1 design system so it reads like finnacalc.com.
//
//  The web "Notify Me", "View All Calculators", and "Try Emergency Fund
//  Calculator" actions are internal Next routes / form posts; on iOS we surface
//  them as SwiftUI `Link`s (mailto + finnacalc.com deep links) so the CTAs stay
//  functional in a standalone port. The decorative blue accents map to
//  `Theme.primary`, matching the web's `blue-600` intent.
//

import SwiftUI

struct AdvisingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""

    /// The premium advisory features advertised on the page (web bullet list).
    private let features = [
        "AI-Powered Financial Planning",
        "Personalized Budget Recommendations",
        "Debt Consolidation Strategies",
        "Retirement Planning Guidance",
        "Tax Optimization Strategies",
        "Business Growth Financial Planning",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // mb-4 — Back button row.
                HStack {
                    FCButton(variant: .outline, size: .default) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                    } action: {
                        dismiss()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 16)

                // text-center hero.
                VStack(spacing: 0) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(Theme.primary) // text-blue-600
                        .padding(.bottom, 24)            // mb-6

                    Text("Personal Financial Advising")
                        .font(.system(size: 30, weight: .bold)) // text-3xl
                        .foregroundColor(Theme.foreground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 16) // mb-4

                    Text("Coming Soon to Premium Version")
                        .font(.system(size: 18)) // text-lg
                        .foregroundColor(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 32) // mb-8

                    premiumCard

                    // mt-8 — free-calculator CTAs.
                    VStack(spacing: 16) {
                        Text("Start with our free financial calculators today:")
                            .font(.system(size: Theme.FontSize.base))
                            .foregroundColor(Theme.mutedForeground)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 0)

                        VStack(spacing: 16) {
                            Link(destination: URL(string: "https://finnacalc.com/")!) {
                                ctaLabel("View All Calculators", variant: .outline)
                            }
                            Link(destination: URL(string: "https://finnacalc.com/emergency-fund-calculator")!) {
                                ctaLabel("Try Emergency Fund Calculator", variant: .default)
                            }
                        }
                    }
                    .padding(.top, 32)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 640, alignment: .center) // max-w-2xl content column
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16) // px-4
            .padding(.vertical, 32)   // py-8
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.muted.opacity(0.4)) // bg-muted/40
    }

    // MARK: - Premium card

    private var premiumCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("What's Coming to Premium")
                FCCardDescription("Personalized financial guidance and advisory services")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 16) { // space-y-4
                    // text-left feature list (space-y-3).
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.self) { feature in
                            HStack(alignment: .center, spacing: 12) { // gap-3
                                Circle()
                                    .fill(Theme.primary) // bg-blue-600
                                    .frame(width: 8, height: 8)
                                Text(feature)
                                    .font(.system(size: Theme.FontSize.base))
                                    .foregroundColor(Theme.cardForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // pt-4 border-t — notify capture.
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                            .overlay(Theme.border)
                            .padding(.top, 16) // pt-4

                        Text("Get notified when our premium advisory services become available!")
                            .font(.system(size: Theme.FontSize.sm)) // text-sm
                            .foregroundColor(Theme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            FCTextField("Enter your email", text: $email, keyboardType: .emailAddress)

                            Link(destination: notifyURL) {
                                ctaLabel("Notify Me", variant: .default)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Helpers

    /// mailto link that pre-fills our waitlist subject (the web "Notify Me" form
    /// posts an email; on iOS we open the user's mail composer instead).
    private var notifyURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "helpfinnacalc@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Notify me about Premium Advising"),
            URLQueryItem(name: "body", value: email.isEmpty ? nil : "Please notify \(email) when advising launches."),
        ]
        return components.url ?? URL(string: "mailto:helpfinnacalc@gmail.com")!
    }

    /// Renders a tappable label styled like an `FCButton` for use inside `Link`
    /// (which needs a plain view, not a `Button`).
    @ViewBuilder
    private func ctaLabel(_ title: String, variant: FCButtonVariant) -> some View {
        let isPrimary = variant == .default
        Text(title)
            .font(.system(size: Theme.FontSize.sm, weight: .medium))
            .foregroundColor(isPrimary ? Theme.primaryForeground : Theme.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 40) // h-10
            .padding(.horizontal, 16) // px-4
            .background(isPrimary ? Theme.primary : Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(isPrimary ? .clear : Theme.input, lineWidth: 1)
            )
    }
}

#Preview("Advising — Light") {
    AdvisingView().preferredColorScheme(.light)
}

#Preview("Advising — Dark") {
    AdvisingView().preferredColorScheme(.dark)
}
