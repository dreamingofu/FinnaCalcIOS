//
//  FCButton.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/ui/button.tsx`.
//
//  Web `hover:` states map to the native pressed state (the `/90`, `/80`
//  opacity steps), since there is no pointer hover on iOS. `disabled:opacity-50`
//  and `disabled:pointer-events-none` map to SwiftUI's `isEnabled`.
//

import SwiftUI

// MARK: - Variant / Size

// Declared at top level (not nested in the generic `FCButton<Label>`) so the
// style struct can name them without binding `Label`. Aliased back onto
// `FCButton` below so call sites can still write `FCButton.Variant`.

/// Mirrors `buttonVariants.variant` in button.tsx.
enum FCButtonVariant {
    case `default`     // bg-primary text-primary-foreground hover:bg-primary/90
    case destructive   // bg-destructive text-destructive-foreground hover:bg-destructive/90
    case outline       // border border-input bg-background hover:bg-accent hover:text-accent-foreground
    case secondary     // bg-secondary text-secondary-foreground hover:bg-secondary/80
    case ghost         // hover:bg-accent hover:text-accent-foreground
    case link          // text-primary underline-offset-4 hover:underline
}

/// Mirrors `buttonVariants.size` in button.tsx.
enum FCButtonSize {
    case `default`     // h-10 px-4 py-2
    case sm            // h-9  px-3
    case lg            // h-11 px-8
    case icon          // h-10 w-10
}

extension FCButton {
    typealias Variant = FCButtonVariant
    typealias Size = FCButtonSize
}

// MARK: - FCButton

/// A button styled to match the web `<Button>`. Use the trailing-closure init
/// for arbitrary content (icon + label), or the `String` convenience init.
///
/// ```swift
/// FCButton("Save") { save() }
/// FCButton(variant: .outline, size: .sm) { Label("Add", systemImage: "plus") } action: { add() }
/// ```
struct FCButton<Label: View>: View {
    private let variant: Variant
    private let size: Size
    private let action: () -> Void
    private let label: () -> Label

    init(
        variant: Variant = .default,
        size: Size = .default,
        @ViewBuilder label: @escaping () -> Label,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.size = size
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(FCButtonStyle(variant: variant, size: size))
    }
}

extension FCButton where Label == Text {
    /// Convenience for a plain text button: `FCButton("Save") { ... }`.
    init(
        _ title: String,
        variant: Variant = .default,
        size: Size = .default,
        action: @escaping () -> Void
    ) {
        self.init(variant: variant, size: size, label: { Text(title) }, action: action)
    }
}

// MARK: - ButtonStyle

/// Carries the variant/size styling and resolves the pressed (hover-equivalent)
/// and disabled states. Kept as a `ButtonStyle` so press feedback is built in.
private struct FCButtonStyle: ButtonStyle {
    let variant: FCButtonVariant
    let size: FCButtonSize

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            // base: gap-2, text-sm font-medium, [&_svg]:size-4
            .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
            .imageScale(.medium)
            .foregroundStyle(foreground(pressed: pressed))
            .underline(variant == .link && pressed, color: Theme.primary)
            .frame(height: height)
            .frame(width: size == .icon ? Theme.ButtonMetrics.iconSide : nil)
            .padding(.horizontal, horizontalPadding)
            .background(background(pressed: pressed))
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5) // disabled:opacity-50
            .animation(.easeOut(duration: 0.15), value: pressed) // transition-colors
    }

    // MARK: Metrics

    private var height: CGFloat {
        switch size {
        case .default, .icon: return 40 // h-10
        case .sm:             return 36 // h-9
        case .lg:             return 44 // h-11
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .default: return 16 // px-4
        case .sm:      return 12 // px-3
        case .lg:      return 32 // px-8
        case .icon:    return 0  // square
        }
    }

    // MARK: Colors

    /// Background fill; `pressed` applies the web `hover:` opacity step.
    private func background(pressed: Bool) -> some View {
        let color: Color
        switch variant {
        case .default:     color = Theme.primary.opacity(pressed ? 0.9 : 1)
        case .destructive: color = Theme.destructive.opacity(pressed ? 0.9 : 1)
        case .secondary:   color = Theme.secondary.opacity(pressed ? 0.8 : 1)
        case .outline:     color = pressed ? Theme.accent : Theme.background
        case .ghost:       color = pressed ? Theme.accent : Color.clear
        case .link:        color = Color.clear
        }
        return color
    }

    private func foreground(pressed: Bool) -> Color {
        switch variant {
        case .default:     return Theme.primaryForeground
        case .destructive: return Theme.destructiveForeground
        case .secondary:   return Theme.secondaryForeground
        case .outline, .ghost: return pressed ? Theme.accentForeground : Theme.foreground
        case .link:        return Theme.primary
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .outline {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.input, lineWidth: 1) // border border-input
        }
    }
}

// MARK: - Metrics namespace

extension Theme {
    enum ButtonMetrics {
        static let iconSide: CGFloat = 40 // h-10 w-10
    }
}

// MARK: - Previews

#Preview("FCButton — Light") {
    FCButtonGallery().preferredColorScheme(.light)
}

#Preview("FCButton — Dark") {
    FCButtonGallery().preferredColorScheme(.dark)
}

private struct FCButtonGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    FCButton("Default") {}
                    FCButton("Secondary", variant: .secondary) {}
                    FCButton("Destructive", variant: .destructive) {}
                    FCButton("Outline", variant: .outline) {}
                    FCButton("Ghost", variant: .ghost) {}
                    FCButton("Link", variant: .link) {}
                }
                Divider()
                FCButton("Small", size: .sm) {}
                FCButton("Large", size: .lg) {}
                FCButton(variant: .outline, size: .icon) {
                    Image(systemName: "plus")
                } action: {}
                FCButton("Disabled") {}.disabled(true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
    }
}
