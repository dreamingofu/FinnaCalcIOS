//
//  FCCard.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/ui/card.tsx`.
//  The web file exports Card + Header/Title/Description/Content/Footer; this
//  mirrors that composition so call sites read the same way.
//
//      FCCard {
//          FCCardHeader {
//              FCCardTitle("ROI")
//              FCCardDescription("Return on investment")
//          }
//          FCCardContent { ... }
//          FCCardFooter { FCButton("Calculate") {} }
//      }
//

import SwiftUI

// MARK: - Card

/// The primary content container — rounded 12, hairline border, soft `shadow-sm`.
/// Set `interactive` when the whole card navigates somewhere (a touch stronger
/// elevation to read as tappable).
struct FCCard<Content: View>: View {
    var interactive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .foregroundStyle(Theme.cardForeground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .fcShadow(interactive ? .md : .sm)
    }
}

// MARK: - Card sections

/// `flex flex-col space-y-1.5 p-6`
struct FCCardHeader<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { // space-y-1.5
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24) // p-6
    }
}

/// `text-2xl font-semibold leading-none tracking-tight`
///
/// `leading-none` (line-height: 1) is an accepted approximation: SwiftUI has no
/// API to compress line height below a font's natural leading (`.lineSpacing`
/// only adds space), so wrapped multi-line titles render with the system's
/// default leading. FinnaCalc's card titles are short single-line strings, for
/// which this is pixel-identical; matching exactly would require a UIKit
/// attributed-text view and isn't worth that cost here.
struct FCCardTitle: View {
    private let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.sans(Theme.FontSize.xl2, weight: .semibold))
            .tracking(-0.6)         // tracking-tight (-0.025em @ 24pt)
            .lineSpacing(0)         // leading-none (best-effort; see note above)
            .foregroundStyle(Theme.cardForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `text-sm text-muted-foreground`
struct FCCardDescription: View {
    private let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundStyle(Theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `p-6 pt-0`
struct FCCardContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        // pt-0 — no top padding (sits flush under the header)
    }
}

/// `flex items-center p-6 pt-0`
struct FCCardFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Previews

#Preview("FCCard — Light") {
    FCCardGallery().preferredColorScheme(.light)
}

#Preview("FCCard — Dark") {
    FCCardGallery().preferredColorScheme(.dark)
}

private struct FCCardGallery: View {
    var body: some View {
        ScrollView {
            FCCard {
                FCCardHeader {
                    FCCardTitle("Loan Calculator")
                    FCCardDescription("Estimate monthly payments and total interest.")
                }
                FCCardContent {
                    Text("Card content goes here.")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundStyle(Theme.foreground)
                }
                FCCardFooter {
                    FCButton("Calculate") {}
                    FCButton("Reset", variant: .ghost) {}
                }
            }
            .padding(24)
        }
        .background(Theme.background)
    }
}
