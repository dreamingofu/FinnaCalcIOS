//
//  Theme.swift
//  FinnaCalcIOS
//
//  The renovated FinnaCalc design system (imported from the Claude Design
//  project "FinnaCalc Design System"). Same brand — white/blue/slate, round
//  corners — with a refreshed, DARK-FIRST surface: ink page, slate-900 cards,
//  blue-500 brand, and IBM Plex–style typography with a monospaced figure font
//  for all numbers.
//
//  Tokens trace to the design project's tokens/{colors,typography,radius}.css
//  (raw --fc-* palette + semantic aliases; the dark layer is the default, light
//  is opt-in). The app is forced dark at the root (see FinnaCalcIOSApp); the
//  tokens still carry correct light values so a future light toggle just works.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - HSL → RGB (kept for callers that build brand-tint colors directly)

private func fcHSLToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
    let s = s / 100, l = l / 100
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    let (r, g, b): (Double, Double, Double) =
        h < 60  ? (c, x, 0) : h < 120 ? (x, c, 0) : h < 180 ? (0, c, x) :
        h < 240 ? (0, x, c) : h < 300 ? (x, 0, c) : (c, 0, x)
    return (r + m, g + m, b + m)
}

extension Color {
    /// Build a `Color` from HSL (`H S% L%`).
    init(h: Double, s: Double, l: Double) {
        let rgb = fcHSLToRGB(h: h, s: s, l: l)
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }
}

// MARK: - Light/Dark HSL token (kept for callers built before the hex tokens)

/// A design token with a light and dark HSL value, resolved per color scheme.
struct FCColorToken {
    let light: (h: Double, s: Double, l: Double)
    let dark: (h: Double, s: Double, l: Double)
}

extension Color {
    init(_ token: FCColorToken) {
        #if canImport(UIKit)
        self = Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? token.dark : token.light
            return UIColor(h: c.h, s: c.s, l: c.l)
        })
        #else
        self = Color(h: token.light.h, s: token.light.s, l: token.light.l)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(h: Double, s: Double, l: Double) {
        let rgb = fcHSLToRGB(h: h, s: s, l: l)
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
    }
}
#endif

// MARK: - Light/Dark hex token

private func fcRGB(_ hex: UInt32) -> (Double, Double, Double) {
    (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
}

/// A semantic color with a light and dark hex value, resolved per color scheme
/// (mirrors the design's `.light` vs default-dark `:root`).
func fcDynamic(light: UInt32, dark: UInt32) -> Color {
    #if canImport(UIKit)
    return Color(UIColor { traits in
        let (r, g, b) = traits.userInterfaceStyle == .dark ? fcRGB(dark) : fcRGB(light)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    })
    #else
    let (r, g, b) = fcRGB(light)
    return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    #endif
}

// MARK: - Theme

/// The renovated FinnaCalc design system: color tokens, radii, typography, and
/// elevation shared by every `FC*` component.
enum Theme {

    // Raw palette (design tokens/colors.css --fc-*)
    private enum P {
        static let white: UInt32 = 0xffffff
        static let ink: UInt32 = 0x020817
        static let slate900: UInt32 = 0x0f172a
        static let slate800: UInt32 = 0x1e293b
        static let slate700: UInt32 = 0x334155
        static let slate500: UInt32 = 0x64748b
        static let slate400: UInt32 = 0x94a3b8
        static let slate300: UInt32 = 0xcbd5e1
        static let slate200: UInt32 = 0xe2e8f0
        static let slate100: UInt32 = 0xf1f5f9
        static let slate50: UInt32 = 0xf8fafc
        static let blue500: UInt32 = 0x3b82f6
        static let blue600: UInt32 = 0x2563eb
        static let blue700: UInt32 = 0x1d4ed8
        static let blue800: UInt32 = 0x1e40af
        static let green600: UInt32 = 0x16a34a
        static let green400: UInt32 = 0x4ade80
        static let red600: UInt32 = 0xdc2626
        static let red500: UInt32 = 0xef4444
        static let amber500: UInt32 = 0xf59e0b
        static let sunkenDark: UInt32 = 0x0a1222
    }

    // MARK: Semantic color tokens (light, dark) — names preserved so the whole
    // app re-skins through the existing token usage.

    static let background          = fcDynamic(light: P.white,    dark: P.ink)        // surface-page
    static let surfaceSunken       = fcDynamic(light: P.slate50,  dark: P.sunkenDark)
    static let foreground          = fcDynamic(light: P.ink,      dark: P.slate50)    // text-strong
    static let textBody            = fcDynamic(light: P.slate700, dark: P.slate300)   // text-body

    static let card                = fcDynamic(light: P.white,    dark: P.slate900)   // surface-card
    static let cardForeground      = fcDynamic(light: P.ink,      dark: P.slate50)
    static let popover             = card
    static let popoverForeground   = cardForeground

    static let primary             = fcDynamic(light: P.blue600,  dark: P.blue500)    // brand
    static let primaryForeground   = fcDynamic(light: P.slate50,  dark: P.ink)        // brand-onfill
    static let brandHover          = fcDynamic(light: P.blue700,  dark: P.blue600)
    static let brandPress          = fcDynamic(light: P.blue800,  dark: P.blue700)
    static var brandTint: Color    { primary.opacity(0.14) }                          // icon chips / result tints

    static let secondary           = fcDynamic(light: P.slate100, dark: P.slate800)   // surface-muted
    static let secondaryForeground = foreground
    static let muted               = secondary
    static let mutedForeground     = fcDynamic(light: P.slate500, dark: P.slate400)   // text-muted
    static let accent              = secondary
    static let accentForeground    = foreground

    static let destructive           = fcDynamic(light: P.red600, dark: P.red500)     // negative
    static let destructiveForeground = fcDynamic(light: P.white,  dark: P.white)

    static let border              = fcDynamic(light: P.slate200, dark: P.slate800)   // border-subtle
    static let borderStrong        = fcDynamic(light: P.slate300, dark: P.slate700)
    static let input               = border
    static let ring                = primary

    static let caution             = fcDynamic(light: P.amber500, dark: P.amber500)
    static var cautionTint: Color  { caution.opacity(0.12) }

    // MARK: Corner radii — tokens/radius.css

    enum Radius {
        static let sm: CGFloat = 8    // chips, small controls
        static let md: CGFloat = 10   // buttons, inputs
        static let lg: CGFloat = 12   // cards
        static let xl: CGFloat = 16   // large cards, sheets
        static let xxl: CGFloat = 20  // hero panels, modal sheets
    }

    // MARK: Type scale — tokens/typography.css

    enum FontSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 14
        static let base: CGFloat = 16
        static let lg: CGFloat = 18
        static let xl: CGFloat = 20
        static let xl2: CGFloat = 24
        static let xl3: CGFloat = 30
        static let xl4: CGFloat = 36
        static let xl5: CGFloat = 44
    }

    /// Display/body face. The design specifies IBM Plex Sans; we substitute the
    /// system font (the design flags this swap explicitly — swap in a bundled
    /// IBM Plex face to match exactly).
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Numeric figure face — IBM Plex Mono in the design, the monospaced system
    /// font here. Use for ALL currency / rate / percentage figures (the design's
    /// signature: "figures are the heroes, rendered in the mono figure font").
    static func figure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Elevation — tokens/radius.css shadows (ink-tinted, low-spread)

    enum Elevation {
        case sm, md, lg, brand
        var color: Color {
            switch self {
            case .sm: return Color(hex: 0x020817, opacity: 0.05)
            case .md: return Color(hex: 0x020817, opacity: 0.10)
            case .lg: return Color(hex: 0x020817, opacity: 0.18)
            case .brand: return Theme.primary.opacity(0.35)
            }
        }
        var radius: CGFloat {
            switch self { case .sm: return 1.5; case .md: return 5; case .lg: return 16; case .brand: return 12 }
        }
        var y: CGFloat {
            switch self { case .sm: return 1; case .md: return 2; case .lg: return 12; case .brand: return 8 }
        }
    }
}

// Local hex init (file-private so it never collides with other extensions).
private extension Color {
    init(hex: UInt32, opacity: Double) {
        let (r, g, b) = fcRGB(hex)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension View {
    /// Apply a design-system elevation shadow.
    func fcShadow(_ elevation: Theme.Elevation) -> some View {
        shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
    }
}
