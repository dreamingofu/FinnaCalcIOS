//
//  FCBadge.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/ui/badge.tsx`.
//
//      inline-flex items-center rounded-full border px-2.5 py-0.5
//      text-xs font-semibold
//
//  The web badge is a non-interactive `<div>`; its `hover:` steps only apply on
//  pointer devices, so the native badge is a static label with no press state.
//

import SwiftUI

// MARK: - FCBadge

struct FCBadge<Content: View>: View {

    /// Mirrors `badgeVariants.variant` in badge.tsx.
    enum Variant {
        case `default`     // border-transparent bg-primary text-primary-foreground
        case secondary     // border-transparent bg-secondary text-secondary-foreground
        case destructive   // border-transparent bg-destructive text-destructive-foreground
        case outline       // text-foreground (visible border, no fill)
    }

    private let variant: Variant
    private let content: () -> Content

    init(variant: Variant = .default, @ViewBuilder content: @escaping () -> Content) {
        self.variant = variant
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) { content() }
            .font(.system(size: Theme.FontSize.xs, weight: .semibold)) // text-xs font-semibold
            .foregroundStyle(foreground)
            .padding(.horizontal, 10) // px-2.5
            .padding(.vertical, 2)    // py-0.5
            .background(fill)
            .overlay(
                Capsule().strokeBorder(borderColor, lineWidth: 1) // border (transparent unless outline)
            )
            .clipShape(Capsule()) // rounded-full
    }

    private var fill: Color {
        switch variant {
        case .default:     return Theme.primary
        case .secondary:   return Theme.secondary
        case .destructive: return Theme.destructive
        case .outline:     return .clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .default:     return Theme.primaryForeground
        case .secondary:   return Theme.secondaryForeground
        case .destructive: return Theme.destructiveForeground
        case .outline:     return Theme.foreground
        }
    }

    private var borderColor: Color {
        variant == .outline ? Theme.border : .clear // border-transparent on filled variants
    }
}

// MARK: - String convenience

extension FCBadge where Content == Text {
    init(_ title: String, variant: Variant = .default) {
        self.init(variant: variant) { Text(title) }
    }
}

// MARK: - Previews

#Preview("FCBadge — Light") {
    FCBadgeGallery().preferredColorScheme(.light)
}

#Preview("FCBadge — Dark") {
    FCBadgeGallery().preferredColorScheme(.dark)
}

private struct FCBadgeGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FCBadge("Default")
            FCBadge("Secondary", variant: .secondary)
            FCBadge("Destructive", variant: .destructive)
            FCBadge("Outline", variant: .outline)
            HStack {
                FCBadge(variant: .secondary) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Verified")
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
    }
}
