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

    /// Badge variants (design Badge.prompt.md).
    enum Variant {
        case `default`     // brand emphasis (filled)
        case secondary     // neutral category tag (muted fill)
        case destructive   // destructive (red fill)
        case outline       // quiet label (border, no fill)
        case positive      // gains (green tint)
        case negative      // costs (red tint)
        case caution       // pending (amber tint)
    }

    private let variant: Variant
    private let dot: Bool
    private let content: () -> Content

    init(variant: Variant = .default, dot: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.variant = variant
        self.dot = dot
        self.content = content
    }

    var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(foreground).frame(width: 6, height: 6)
            }
            content()
        }
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
        case .positive:    return Theme.positive.opacity(0.12)
        case .negative:    return Theme.negative.opacity(0.12)
        case .caution:     return Theme.cautionTint
        }
    }

    private var foreground: Color {
        switch variant {
        case .default:     return Theme.primaryForeground
        case .secondary:   return Theme.secondaryForeground
        case .destructive: return Theme.destructiveForeground
        case .outline:     return Theme.foreground
        case .positive:    return Theme.positive
        case .negative:    return Theme.negative
        case .caution:     return Theme.caution
        }
    }

    private var borderColor: Color {
        variant == .outline ? Theme.border : .clear // border-transparent on filled variants
    }
}

// MARK: - String convenience

extension FCBadge where Content == Text {
    init(_ title: String, variant: Variant = .default, dot: Bool = false) {
        self.init(variant: variant, dot: dot) { Text(title) }
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
