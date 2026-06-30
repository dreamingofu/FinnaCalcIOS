//
//  TaxInsightViews.swift
//  FinnaCalcIOS
//
//  SwiftUI port of three tax-engine UI surfaces from the FinnaCalc web app:
//    - SmartSuggestions   (components/tax-engine/ui/SmartSuggestions.tsx)
//    - LifeSituations     (components/tax-engine/ui/LifeSituations.tsx)
//    - PrintableSummary   (components/tax-engine/ui/PrintableSummary.tsx)
//
//  Each observes the `TaxEngineViewModel` (the SwiftUI port of useTaxEngine).
//  SmartSuggestions ports the web `computeSuggestions` heuristic 1:1; the other
//  two read the engine helpers already ported in Engine/ (LIFE_SITUATIONS data
//  lives inline since it's UI-shaping, and build1040Summary for the summary).
//
//  Faithful to the web: same copy, same ordering, same conditional rules. The
//  pure engine (Engine/) is NOT modified.
//

import SwiftUI

// MARK: - Life situations data
//
// Mirror of LIFE_SITUATIONS in components/tax-engine/questions/sections.ts.
// Kept here (UI layer) because it only shapes the intro screen; the section
// gates that consume these `ls_*` answers live in the engine.

/// One "check all that apply" option on the Life Situations screen.
struct LifeSituationOption: Identifiable {
    let id: String
    let label: String
    /// lucide icon name from the web; mapped to an SF Symbol for rendering.
    let icon: String
}

/// TS: `LIFE_SITUATIONS` — same ids, labels, and order.
let LIFE_SITUATIONS: [LifeSituationOption] = [
    LifeSituationOption(id: "ls_job", label: "I earned wages from a job (W-2)", icon: "Briefcase"),
    LifeSituationOption(id: "ls_self", label: "I was self-employed or freelanced", icon: "Store"),
    LifeSituationOption(id: "ls_invest", label: "I had investments (interest, dividends, or sales)", icon: "TrendingUp"),
    LifeSituationOption(id: "ls_retire", label: "I received retirement income or Social Security", icon: "PiggyBank"),
    LifeSituationOption(id: "ls_deps", label: "I have children or other dependents", icon: "Users"),
    LifeSituationOption(id: "ls_itemize", label: "I owned a home or have large deductions", icon: "Home"),
    LifeSituationOption(id: "ls_education", label: "I paid for higher education", icon: "GraduationCap"),
    LifeSituationOption(id: "ls_care", label: "I paid for child or dependent care", icon: "Baby"),
    LifeSituationOption(id: "ls_savings", label: "I contributed to an IRA, HSA, or retirement plan", icon: "Landmark"),
    LifeSituationOption(id: "ls_energy", label: "I bought an EV or made home energy upgrades", icon: "Zap"),
]

/// TS: `ICONS` (icons.ts) — lucide-react name → SF Symbol.
/// Only the names referenced by LIFE_SITUATIONS / sections are needed here.
private func sfSymbol(forLucide name: String) -> String {
    switch name {
    case "User":          return "person"
    case "Users":         return "person.2"
    case "Briefcase":     return "briefcase"
    case "Store":         return "storefront"
    case "TrendingUp":    return "chart.line.uptrend.xyaxis"
    case "PiggyBank":     return "banknote"
    case "Coins":         return "dollarsign.circle"
    case "Sliders":       return "slider.horizontal.3"
    case "Receipt":       return "doc.text"
    case "Gift":          return "gift"
    case "Wallet":        return "wallet.pass"
    case "Home":          return "house"
    case "GraduationCap": return "graduationcap"
    case "Baby":          return "figure.child"
    case "Landmark":      return "building.columns"
    case "Zap":           return "bolt"
    default:              return "checkmark" // TS fallback: `ICONS[ls.icon] ?? Check`
    }
}

// MARK: - Suggestion heuristic
//
// TS: `computeSuggestions(a, result)` in SmartSuggestions.tsx — same conditions,
// same order, same copy.

/// Heuristic "you might also qualify for…" nudges based on answers + result.
func computeSuggestions(_ a: Answers, _ result: TaxCalculationResult) -> [String] {
    var out: [String] = []

    // TS: const hasKids = (typeof a.q_qual_children === "number" ? a.q_qual_children : 0) > 0
    let hasKids: Bool = {
        if case .number(let n)? = a["q_qual_children"] { return n > 0 }
        return false
    }()

    // TS helper: `a.ls_X !== true`
    func notChecked(_ id: String) -> Bool { a[id] != .boolean(true) }
    func isTrue(_ id: String) -> Bool { a[id] == .boolean(true) }

    if hasKids && notChecked("ls_care") {
        out.append(
            "You have children — if you paid for daycare or after-school care, check \u{201C}I paid for child or dependent care\u{201D} to claim the Child & Dependent Care Credit."
        )
    }
    if hasKids && notChecked("ls_education") {
        out.append(
            "Paying for college? Check \u{201C}I paid for higher education\u{201D} — the American Opportunity Credit is worth up to $2,500 per student."
        )
    }
    if isTrue("ls_self") && notChecked("ls_savings") {
        out.append(
            "As a self-employed filer, contributing to a SEP-IRA or solo 401(k) can lower your taxable income — check \u{201C}I contributed to an IRA, HSA, or retirement plan.\u{201D}"
        )
    }
    if notChecked("ls_savings") && result.agi > 0 && result.agi < 40_000 {
        out.append(
            "At your income, retirement contributions may earn the Saver\u{2019}s Credit (up to 50% back). Check \u{201C}I contributed to an IRA, HSA, or retirement plan.\u{201D}"
        )
    }
    if result.deductionUsed == .standard && notChecked("ls_itemize") {
        out.append(
            "We used the standard deduction. If you own a home or made large charitable gifts, check \u{201C}I owned a home or have large deductions\u{201D} to compare itemizing."
        )
    }
    return out
}

// MARK: - SmartSuggestions

/// TS: `SmartSuggestions({ suggestions })` + the `computeSuggestions` it's fed.
/// Renders nothing when there are no suggestions (web returns `null`).
struct SmartSuggestions: View {
    @ObservedObject var vm: TaxEngineViewModel

    private var suggestions: [String] {
        computeSuggestions(vm.answers, vm.result)
    }

    var body: some View {
        // TS: if (suggestions.length === 0) return null
        if !suggestions.isEmpty {
            // Card with `border-primary/30` — a tinted border over the standard card.
            VStack(alignment: .leading, spacing: 0) {
                // CardHeader (pb-3) + CardTitle (flex items-center gap-2 text-base)
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.primary) // text-primary
                    Text("You might be leaving money on the table")
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.cardForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .padding(.bottom, -12) // pb-3 (header bottom shorter than default p-6)

                // CardContent: ul with space-y-2 of bulleted suggestions.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 8) { // li flex gap-2
                            Text("\u{2022}") // bullet, text-primary
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Theme.primary)
                            Text(s) // text-sm text-muted-foreground
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.primary.opacity(0.3), lineWidth: 1) // border-primary/30
            )
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - LifeSituations

/// TS: `LifeSituations({ answers, setAnswer })` — the "check all that apply"
/// intro screen. Selecting a situation toggles its `ls_*` boolean answer, which
/// unlocks the matching interview sections.
struct LifeSituations: View {
    @ObservedObject var vm: TaxEngineViewModel

    // Two-column grid (sm:grid-cols-2), gap-3.
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private func isSelected(_ id: String) -> Bool {
        vm.answers[id] == .boolean(true)
    }

    var body: some View {
        VStack(spacing: 24) { // space-y-6
            // Centered intro header (text-center space-y-2).
            VStack(spacing: 8) {
                Text("Let\u{2019}s start with your situation")
                    .font(.system(size: Theme.FontSize.xl2, weight: .bold)) // text-2xl font-bold
                    .foregroundColor(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pick everything that applies to you. We\u{2019}ll only ask about what\u{2019}s relevant — and your estimated refund updates as you go.")
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 576) // max-w-xl, mx-auto
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(LIFE_SITUATIONS) { ls in
                    let selected = isSelected(ls.id)
                    Button {
                        vm.setAnswer(ls.id, .boolean(!selected))
                    } label: {
                        HStack(spacing: 12) { // flex items-center gap-3 p-4
                            // Icon chip: h-10 w-10 rounded-lg, tinted by selection.
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .fill(selected ? Theme.primary : Theme.muted)
                                Image(systemName: sfSymbol(forLucide: ls.icon))
                                    .font(.system(size: 20))
                                    .foregroundColor(selected ? Theme.primaryForeground : Theme.mutedForeground)
                            }
                            .frame(width: 40, height: 40)

                            Text(ls.label) // text-sm font-medium text-foreground
                                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                                .foregroundColor(Theme.foreground)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Trailing check when selected (ml-auto).
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        .padding(16) // p-4
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            // selected: bg-primary/5; else: plain card.
                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .fill(selected ? Theme.primary.opacity(0.05) : Theme.card)
                        )
                        .overlay(
                            // selected: border-primary; else: border-border.
                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .strokeBorder(selected ? Theme.primary : Theme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - PrintableSummary

/// TS: `PrintableSummary({ result })` — the clean 1040 summary shown on the
/// filing screen. Reads `build1040Summary` (Engine/Build1040Summary.swift).
struct PrintableSummary: View {
    @ObservedObject var vm: TaxEngineViewModel

    private var summary: Form1040Summary { build1040Summary(vm.result) }

    /// TS: `formatCurrency(value, { cents })` — "$1,234.50" or "$1,234".
    private func currency(_ value: Double, cents: Bool = true) -> String {
        let safe = value.isFinite ? value : 0
        return "$" + CalcFormat.decimal(safe, fraction: cents ? 2 : 0)
    }

    var body: some View {
        let s = summary
        VStack(alignment: .leading, spacing: 0) {
            // Header block (mb-4 border-b pb-4).
            VStack(alignment: .leading, spacing: 0) {
                Text("FinnaCalc \u{00B7} Tax Year \(String(s.taxYear)) estimate")
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                Text(s.filingStatusLabel) // text-lg font-bold
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.cardForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(s.headline.label) // mt-2 text-sm text-muted-foreground
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                    .padding(.top, 8)
                Text(currency(s.headline.amount, cents: false)) // text-3xl font-bold
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Theme.cardForeground)
                    .monospacedDigit() // tabular-nums
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1) // border-b
            }
            .padding(.bottom, 16) // mb-4

            // Groups (space-y-5).
            VStack(alignment: .leading, spacing: 20) {
                ForEach(s.groups, id: \.title) { g in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(g.title) // mb-1.5 text-sm font-semibold
                            .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                            .foregroundColor(Theme.foreground)
                            .padding(.bottom, 6)
                        VStack(alignment: .leading, spacing: 4) { // space-y-1
                            ForEach(Array(g.lines.enumerated()), id: \.offset) { _, l in
                                summaryRow(l)
                            }
                        }
                    }
                }

                // Optional state block.
                if let st = s.state {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(st.name) state")
                            .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                            .foregroundColor(Theme.foreground)
                            .padding(.bottom, 6)
                        if st.hasIncomeTax {
                            VStack(alignment: .leading, spacing: 4) {
                                summaryKeyValue(
                                    label: "State income tax",
                                    value: currency(st.tax)
                                )
                                summaryKeyValue(
                                    label: "State \(st.refundOrOwed < 0 ? "balance due" : "refund")",
                                    value: currency(abs(st.refundOrOwed))
                                )
                            }
                        } else {
                            Text("No state income tax.")
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Footer (mt-6 border-t pt-4 text-xs).
            Text("Educational federal estimate.")
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 1) // border-t
                }
                .padding(.top, 24) // mt-6
        }
        .padding(24) // p-6
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .foregroundStyle(Theme.cardForeground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    /// A summary line: label (+ optional form ref) on the left, amount right.
    @ViewBuilder
    private func summaryRow(_ l: SummaryLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Label + dim form-ref (text-sm text-muted-foreground).
            (
                Text(l.label).foregroundColor(Theme.mutedForeground)
                + Text(l.formRef.map { "  \($0)" } ?? "")
                    .foregroundColor(Theme.mutedForeground.opacity(0.7))
            )
            .font(.system(size: Theme.FontSize.sm))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(currency(l.amount)) // font-medium tabular-nums text-foreground
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
                .monospacedDigit()
        }
    }

    /// Plain key/value row used by the state block.
    @ViewBuilder
    private func summaryKeyValue(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#Preview("Tax insight views") {
    let vm = TaxEngineViewModel()
    return ScrollView {
        VStack(spacing: 24) {
            LifeSituations(vm: vm)
            SmartSuggestions(vm: vm)
            PrintableSummary(vm: vm)
        }
        .padding()
    }
    .background(Theme.background)
}
