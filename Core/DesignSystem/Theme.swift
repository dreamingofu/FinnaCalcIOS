//
//  Theme.swift
//  FinnaCalcIOS
//
//  Design tokens ported 1:1 from the FinnaCalc web app.
//  Colors mirror the CSS custom properties in `../FinnaCalc/app/globals.css`
//  (authored as `H S% L%`); radii mirror `../FinnaCalc/tailwind.config.ts`.
//
//  Do not hand-tune these values — they are a faithful copy of the web tokens
//  so the iOS app reads identically to finnacalc.com in both light and dark mode.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - HSL → RGB

/// Convert HSL (matching CSS `hsl()`) to RGB components in `0...1`.
/// This is the algorithm given in PLAN.md, factored out so both `Color` and
/// `UIColor` build from the exact same math.
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
    /// Build a `Color` from HSL, matching the CSS token format (`H S% L%`).
    init(h: Double, s: Double, l: Double) {
        let rgb = fcHSLToRGB(h: h, s: s, l: l)
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
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

// MARK: - Light/Dark token

/// A design token with a light and dark HSL value, resolved automatically per
/// the active color scheme (mirrors how the web flips `:root` vs `.dark`).
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

// MARK: - Theme

/// The FinnaCalc design system: color tokens, corner radii, and typography
/// scale shared by every `FC*` component.
enum Theme {

    // MARK: Color tokens (light, dark) — see globals.css `:root` / `.dark`.

    static let background          = Color(FCColorToken(light: (0, 0, 100),          dark: (222.2, 84, 4.9)))
    static let foreground          = Color(FCColorToken(light: (222.2, 84, 4.9),     dark: (210, 40, 98)))

    static let card                = Color(FCColorToken(light: (0, 0, 100),          dark: (222.2, 84, 4.9)))
    static let cardForeground      = Color(FCColorToken(light: (222.2, 84, 4.9),     dark: (210, 40, 98)))

    static let popover             = Color(FCColorToken(light: (0, 0, 100),          dark: (222.2, 84, 4.9)))
    static let popoverForeground   = Color(FCColorToken(light: (222.2, 84, 4.9),     dark: (210, 40, 98)))

    static let primary             = Color(FCColorToken(light: (221.2, 83.2, 53.3),  dark: (217.2, 91.2, 59.8)))
    static let primaryForeground   = Color(FCColorToken(light: (210, 40, 98),        dark: (222.2, 47.4, 11.2)))

    static let secondary           = Color(FCColorToken(light: (210, 40, 96),        dark: (217.2, 32.6, 17.5)))
    static let secondaryForeground = Color(FCColorToken(light: (222.2, 84, 4.9),     dark: (210, 40, 98)))

    static let muted               = Color(FCColorToken(light: (210, 40, 96),        dark: (217.2, 32.6, 17.5)))
    static let mutedForeground     = Color(FCColorToken(light: (215.4, 16.3, 46.9),  dark: (215, 20.2, 65.1)))

    static let accent              = Color(FCColorToken(light: (210, 40, 96),        dark: (217.2, 32.6, 17.5)))
    static let accentForeground    = Color(FCColorToken(light: (222.2, 84, 4.9),     dark: (210, 40, 98)))

    static let destructive           = Color(FCColorToken(light: (0, 84.2, 60.2),    dark: (0, 62.8, 30.6)))
    static let destructiveForeground = Color(FCColorToken(light: (210, 40, 98),      dark: (210, 40, 98)))

    static let border              = Color(FCColorToken(light: (214.3, 31.8, 91.4),  dark: (217.2, 32.6, 17.5)))
    static let input               = Color(FCColorToken(light: (214.3, 31.8, 91.4),  dark: (217.2, 32.6, 17.5)))
    static let ring                = Color(FCColorToken(light: (221.2, 83.2, 53.3),  dark: (224.3, 76.3, 48)))

    // MARK: Corner radii — tailwind.config.ts (`--radius: 0.75rem` = 12pt).

    enum Radius {
        static let lg: CGFloat = 12  // var(--radius)            → rounded-lg  (Card)
        static let md: CGFloat = 10  // calc(var(--radius) - 2px) → rounded-md (Button, Input)
        static let sm: CGFloat = 8   // calc(var(--radius) - 4px) → rounded-sm
    }

    // MARK: Typography scale — Tailwind font sizes used by the ported components.

    enum FontSize {
        static let xs: CGFloat = 12   // text-xs   (Badge)
        static let sm: CGFloat = 14   // text-sm   (Button, CardDescription)
        static let base: CGFloat = 16 // text-base (Input)
        static let xl2: CGFloat = 24  // text-2xl  (CardTitle)
    }
}
