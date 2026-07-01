//
//  DesignSystemGallery.swift
//  FinnaCalcIOS
//
//  A single screen exercising every FC* component in both color schemes, for
//  eyeballing design-system parity against finnacalc.com. Not shipped in any
//  feature flow — it exists for SwiftUI previews and manual QA.
//

import SwiftUI

struct DesignSystemGallery: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Buttons") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { FCButton("Default") {}; FCButton("Secondary", variant: .secondary) {} }
                        HStack { FCButton("Destructive", variant: .destructive) {}; FCButton("Outline", variant: .outline) {} }
                        HStack { FCButton("Ghost", variant: .ghost) {}; FCButton("Link", variant: .link) {} }
                        HStack { FCButton("sm", size: .sm) {}; FCButton("lg", size: .lg) {}
                            FCButton(size: .icon) { Image(systemName: "plus") } action: {} }
                    }
                }

                section("Badges") {
                    HStack {
                        FCBadge("Default")
                        FCBadge("Secondary", variant: .secondary)
                        FCBadge("Destructive", variant: .destructive)
                        FCBadge("Outline", variant: .outline)
                    }
                }

                section("Text fields") {
                    VStack(spacing: 12) {
                        FCTextField("you@example.com", text: $email, keyboardType: .emailAddress)
                        FCTextField("Password", text: $password, isSecure: true)
                    }
                }

                section("Card") {
                    FCCard {
                        FCCardHeader {
                            FCCardTitle("Emergency Fund")
                            FCCardDescription("How many months of expenses you have saved.")
                        }
                        FCCardContent {
                            Text("3.5 months")
                                .font(Theme.sans(Theme.FontSize.base, weight: .medium))
                                .foregroundStyle(Theme.foreground)
                        }
                        FCCardFooter {
                            FCButton("Recalculate") {}
                            FCBadge("On track", variant: .secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Design System — Light") {
    DesignSystemGallery().preferredColorScheme(.light)
}

#Preview("Design System — Dark") {
    DesignSystemGallery().preferredColorScheme(.dark)
}
