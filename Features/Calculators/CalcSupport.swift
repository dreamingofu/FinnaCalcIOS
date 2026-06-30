//
//  CalcSupport.swift
//  FinnaCalcIOS
//
//  Shared toolkit for the standalone calculators (Phase 3). Every calculator
//  view is built from these pieces so they read consistently and match the web
//  calculators' look: labeled inputs, a full-width Calculate button, and a
//  grid of bold, color-coded results (green = headline, red = cost).
//

import SwiftUI

// MARK: - Result accent colors

extension Theme {
    /// Tailwind green-600 / green-400 — headline/positive result figures.
    static let positive = Color(FCColorToken(light: (142, 76, 36), dark: (142, 69, 58)))
    /// Tailwind red-600 / red-400 — cost/negative result figures.
    static let negative = Color(FCColorToken(light: (0, 72, 51), dark: (0, 91, 71)))
}

// MARK: - Parsing & formatting (mirrors the web helpers)

extension String {
    /// `Number.parseFloat(x) || 0` — empty/invalid input becomes 0.
    var calcValue: Double { Double(trimmingCharacters(in: .whitespaces)) ?? 0 }
}

enum CalcFormat {
    /// Grouped with a fixed number of fraction digits — the web `fmt()` helper
    /// (`toLocaleString(undefined, { min/maxFractionDigits })`).
    static func decimal(_ value: Double, fraction: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.roundingMode = .halfUp // match JS toFixed/toLocaleString (half away from zero)
        f.minimumFractionDigits = fraction
        f.maximumFractionDigits = fraction
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    /// Grouped integer — the web `value.toLocaleString()` on whole numbers.
    static func int(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.roundingMode = .halfUp
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    /// Mirrors JS `Number.toLocaleString()` with no options: grouped, with 0–3
    /// fraction digits (trailing zeros trimmed). Use wherever the web renders a
    /// figure via `value.toLocaleString()`.
    static func locale(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.roundingMode = .halfUp
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    /// Mirrors JS `String(number)` / React's raw `{value}` render: no grouping,
    /// decimals preserved (trailing zeros trimmed).
    static func raw(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 10
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    /// Fixed fraction digits, no grouping — the web `value.toFixed(n)`
    /// (half-up rounding, matching JS for positive values).
    static func fixed(_ value: Double, _ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.roundingMode = .halfUp
        f.minimumFractionDigits = n
        f.maximumFractionDigits = n
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }

    static func currency(_ value: Double, fraction: Int = 2) -> String {
        "$" + decimal(value, fraction: fraction)
    }
}

// MARK: - Inputs

/// Labeled numeric field (web `<Label>` + `<Input type="number">`).
struct CalcField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundStyle(Theme.foreground)
            FCTextField(placeholder, text: $text, keyboardType: keyboard)
        }
    }
}

/// Labeled dropdown (web `<Select>`). `options` are (value, label) pairs.
struct CalcPicker<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundStyle(Theme.foreground)
            Menu {
                ForEach(options, id: \.value) { option in
                    Button(option.label) { selection = option.value }
                }
            } label: {
                HStack {
                    Text(options.first { $0.value == selection }?.label ?? "")
                        .foregroundStyle(Theme.foreground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mutedForeground)
                }
                .font(.system(size: Theme.FontSize.base))
                .frame(height: 40)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.input, lineWidth: 1)
                )
            }
        }
    }
}

/// Two-column layout for grouped inputs (web `grid grid-cols-2 gap-4`).
struct CalcGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)],
            alignment: .leading,
            spacing: 16
        ) { content() }
    }
}

// MARK: - Results

/// A single result figure: muted caption + bold, color-coded value.
struct CalcResult: View {
    let label: String
    let value: String
    var color: Color = Theme.foreground
    /// `text-3xl` headline (true) vs `text-2xl` (false).
    var emphasized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
            Text(value)
                .font(.system(size: emphasized ? 30 : 24, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Results" heading + a two-column grid of `CalcResult`s.
struct CalcResultsSection<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.foreground)
            CalcGrid { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Inline validation error (web `text-sm text-destructive`).
struct CalcErrorText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: Theme.FontSize.sm))
            .foregroundStyle(Theme.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Page scaffold

/// Standard calculator page: a card with an icon/title/description header, the
/// inputs, a full-width Calculate button, and the results. Pushed via
/// NavigationLink from the hub, so the system back button replaces the web's
/// manual "Back" button.
struct CalculatorScaffold<Inputs: View, Results: View>: View {
    let icon: String
    let title: String
    let description: String
    var calculateTitle: String = "Calculate"
    let onCalculate: () -> Void
    @ViewBuilder var inputs: () -> Inputs
    @ViewBuilder var results: () -> Results

    var body: some View {
        ScrollView {
            FCCard {
                FCCardHeader {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        FCCardTitle(title)
                    }
                    FCCardDescription(description)
                }
                FCCardContent {
                    VStack(alignment: .leading, spacing: 16) {
                        inputs()
                        FCButton(size: .lg, label: {
                            Text(calculateTitle).frame(maxWidth: .infinity)
                        }, action: onCalculate)
                        results()
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }
}
