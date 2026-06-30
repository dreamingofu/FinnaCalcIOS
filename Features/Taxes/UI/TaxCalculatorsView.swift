//
//  TaxCalculatorsView.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/tax-calculators.tsx` — the "Tax
//  Optimization Tools" screen: a set of quick, self-contained federal-tax
//  calculators (Tax Calculator, Refund Estimator, Deduction Finder, Quarterly
//  Payments, Withholding) backed by the shared pure-Swift tax engine.
//
//  Faithful to the web: same inputs, same formulas (bracketTax / marginalRate /
//  computeSelfEmploymentTax / STANDARD_DEDUCTION_2024), same hypothetical
//  deduction catalog, same headline figures and rounding (toFixed(0) → integer).
//
//  The web lays this out as a left sidebar of tools + a right detail panel. On
//  iOS the tool list becomes a vertically-scrolling selectable list at the top
//  and the active calculator renders below it — a phone-appropriate adaptation
//  of the same single-screen, tab-like switching behavior.
//
//  Self-contained: no view model required.
//

import SwiftUI

// MARK: - TaxCalculatorsView

/// Quick federal-tax calculators & tools. Mirrors `TaxCalculators` in the web app.
struct TaxCalculatorsView: View {

    /// Which calculator is currently shown. Matches the web `activeCalculator`
    /// string ids ("tax-calculator", "refund-estimator", ...).
    private enum Tool: String, CaseIterable, Identifiable {
        case taxCalculator = "tax-calculator"
        case refundEstimator = "refund-estimator"
        case deductionFinder = "deduction-finder"
        case quarterlyCalculator = "quarterly-calculator"
        case withholdingCalculator = "withholding-calculator"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .taxCalculator: return "Tax Calculator"
            case .refundEstimator: return "Refund Estimator"
            case .deductionFinder: return "Deduction Finder"
            case .quarterlyCalculator: return "Quarterly Payments"
            case .withholdingCalculator: return "Withholding Calculator"
            }
        }

        var description: String {
            switch self {
            case .taxCalculator: return "Estimate your federal tax liability"
            case .refundEstimator: return "See your potential federal refund"
            case .deductionFinder: return "Discover potential federal write-offs"
            case .quarterlyCalculator: return "Calculate estimated federal tax payments"
            case .withholdingCalculator: return "Adjust federal paycheck withholdings"
            }
        }

        /// SF Symbol approximating the web lucide icon.
        var icon: String {
            switch self {
            case .taxCalculator: return "function"            // Calculator
            case .refundEstimator: return "dollarsign.circle"  // DollarSign
            case .deductionFinder: return "magnifyingglass"    // Search
            case .quarterlyCalculator: return "calendar"       // Calendar
            case .withholdingCalculator: return "chart.pie"    // PieChart
            }
        }
    }

    @State private var activeCalculator: Tool = .taxCalculator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // space-y-6
                header
                toolList
                activeCalculatorView
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Tax Tools")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tax Optimization Tools")
                .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                .foregroundColor(Theme.foreground)
            Text("Calculators and tools to maximize your refund")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Tool list (web left sidebar)

    private var toolList: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Tax Tools")
            }
            FCCardContent {
                VStack(spacing: 4) { // space-y-1
                    ForEach(Tool.allCases) { tool in
                        Button {
                            activeCalculator = tool
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.primary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tool.title)
                                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                                        .foregroundColor(Theme.foreground)
                                    Text(tool.description)
                                        .font(.system(size: Theme.FontSize.xs))
                                        .foregroundColor(Theme.mutedForeground)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12) // p-3
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                activeCalculator == tool ? Theme.muted : Color.clear
                            )
                            .overlay(alignment: .leading) {
                                // border-l-2 border-primary on the active item
                                if activeCalculator == tool {
                                    Rectangle()
                                        .fill(Theme.primary)
                                        .frame(width: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 0)
            }
        }
    }

    // MARK: Active calculator switch

    @ViewBuilder
    private var activeCalculatorView: some View {
        switch activeCalculator {
        case .taxCalculator: TaxCalculatorCard()
        case .refundEstimator: RefundEstimatorCard()
        case .deductionFinder: DeductionFinderCard()
        case .quarterlyCalculator: QuarterlyCalculatorCard()
        case .withholdingCalculator: WithholdingCalculatorCard()
        }
    }
}

// MARK: - Shared helpers

/// Sanitize a numeric input string (removes commas, dollar signs, spaces, etc.).
/// Mirrors the web `sanitizeNumber`.
private func sanitizeNumber(_ value: String) -> Double {
    let filtered = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
    return Double(filtered) ?? 0
}

/// Strip everything except digits, dot, and minus — mirrors the web onChange
/// `value.replace(/[^\d.-]/g, "")` used on every input field.
private func filterNumericInput(_ value: String) -> String {
    String(value.filter { $0.isNumber || $0 == "." || $0 == "-" })
}

/// `$` + grouped integer (web pattern `$${n.toFixed(0).toLocaleString()}` and
/// `$${n.toLocaleString()}` both collapse to grouped whole-dollar figures here).
private func dollarsInt(_ value: Double) -> String {
    CalcFormat.currency(value, fraction: 0)
}

/// `$` + bare `toLocaleString()` (grouped, up to 3 decimals) — for the income
/// fields the web renders without `.toFixed(0)`, so typed cents are preserved.
private func dollarsLoc(_ value: Double) -> String {
    "$" + CalcFormat.locale(value)
}

/// A labeled row inside a tinted panel (web `flex justify-between ... bg-muted`).
private struct TaxRow: View {
    let label: String
    let value: String
    var labelColor: Color = Theme.foreground
    var valueColor: Color = Theme.foreground
    var bold: Bool = true
    var small: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: small ? Theme.FontSize.sm : Theme.FontSize.base))
                .foregroundColor(labelColor)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: small ? Theme.FontSize.sm : Theme.FontSize.base,
                              weight: bold ? .semibold : .regular))
                .foregroundColor(valueColor)
        }
    }
}

/// A muted rounded panel wrapping rows (web `p-3 bg-muted rounded-lg`).
private struct MutedPanel<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Theme.muted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

/// A labeled text input matching the web `<Label> + <Input>` pairs, with the
/// numeric `replace(/[^\d.-]/g, "")` onChange behavior applied on every edit.
private struct NumericField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var helper: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
            FCTextField(placeholder, text: $text, keyboardType: .numbersAndPunctuation)
                .onChange(of: text) { newValue in
                    let filtered = filterNumericInput(newValue)
                    if filtered != newValue { text = filtered }
                }
            if let helper {
                Text(helper)
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
    }
}

/// Placeholder empty-state shown in result columns before calculation
/// (web "Enter your info ..." muted boxes).
private struct EmptyResult: View {
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Theme.mutedForeground)
            Text(message)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

/// A small tinted callout box (web colored info/tip panels).
private struct TintColors {
    let bg: Color
    let border: Color
    let fg: Color
}

private extension Theme {
    // Soft tints approximating the web Tailwind 50/100 + 600/700/800 palette,
    // resolved per color scheme.
    static let greenSoftBG = Color(FCColorToken(light: (142, 76, 95), dark: (142, 40, 14)))
    static let greenSoftBorder = Color(FCColorToken(light: (142, 60, 80), dark: (142, 40, 28)))
    static let greenStrong = Theme.positive

    static let blueSoftBG = Color(FCColorToken(light: (214, 95, 95), dark: (217, 40, 16)))
    static let blueStrong = Color(FCColorToken(light: (221.2, 83.2, 53.3), dark: (217.2, 91.2, 59.8)))

    static let redSoftBG = Color(FCColorToken(light: (0, 86, 95), dark: (0, 40, 16)))
    static let redStrong = Theme.negative

    static let yellowSoftBG = Color(FCColorToken(light: (48, 96, 89), dark: (48, 40, 16)))
    static let yellowBorder = Color(FCColorToken(light: (48, 90, 76), dark: (48, 40, 30)))
    static let yellowText = Color(FCColorToken(light: (32, 81, 29), dark: (48, 90, 76)))
}

// MARK: - Tax Calculator

private struct TaxCalculatorCard: View {
    @State private var income = ""
    @State private var filingStatus: FilingStatus = .single
    @State private var results: Result?

    private struct Result {
        let grossIncome: Double
        let standardDeduction: Double
        let taxableIncome: Double
        let estimatedTax: Double
        let effectiveRate: Double
        let marginalRate: Double
    }

    private func calculate() {
        let incomeNum = sanitizeNumber(income)
        // Web maps a 3-option select (single / married / head) onto engine statuses.
        let fs = filingStatus
        let standardDeduction = STANDARD_DEDUCTION_2024[fs] ?? STANDARD_DEDUCTION_2024[.single]!
        let taxableIncome = max(0, incomeNum - standardDeduction)
        let tax = bracketTax(taxableIncome, fs)
        let marginal = marginalRate(taxableIncome, fs) * 100
        results = Result(
            grossIncome: incomeNum,
            standardDeduction: standardDeduction,
            taxableIncome: taxableIncome,
            estimatedTax: tax,
            effectiveRate: incomeNum > 0 ? (tax / incomeNum) * 100 : 0,
            marginalRate: marginal
        )
    }

    var body: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Federal Tax Calculator")
                FCCardDescription("Estimate your federal income tax liability")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 24) {
                    // Inputs
                    VStack(alignment: .leading, spacing: 16) {
                        NumericField(label: "Annual Income", placeholder: "$75,000", text: $income)

                        // Filing status select (web 3-option Select).
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filing Status")
                                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                                .foregroundColor(Theme.foreground)
                            Menu {
                                Button("Single") { filingStatus = .single }
                                Button("Married Filing Jointly") { filingStatus = .mfj }
                                Button("Head of Household") { filingStatus = .hoh }
                            } label: {
                                menuLabel(filingStatusLabel)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Deduction Type")
                                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                                .foregroundColor(Theme.foreground)
                            FCTextField("", text: .constant("Standard Deduction (Estimated)"))
                                .disabled(true)
                            Text("Itemized deductions can be explored in the Deduction Finder.")
                                .font(.system(size: Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                        }

                        FCButton(size: .lg, label: {
                            Text("Calculate Federal Tax").frame(maxWidth: .infinity)
                        }, action: calculate)
                    }

                    if let r = results {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Federal Tax Results")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                            VStack(spacing: 12) {
                                MutedPanel { TaxRow(label: "Gross Income", value: dollarsLoc(r.grossIncome)) }
                                MutedPanel { TaxRow(label: "Standard Deduction", value: dollarsInt(r.standardDeduction)) }
                                MutedPanel { TaxRow(label: "Taxable Income", value: dollarsLoc(r.taxableIncome)) }
                                Divider()
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text("Estimated Federal Tax")
                                            .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                            .foregroundColor(Theme.foreground)
                                        Spacer(minLength: 8)
                                        Text(dollarsInt(r.estimatedTax))
                                            .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                                            .foregroundColor(Theme.redStrong)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.redSoftBG)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

                                HStack(spacing: 12) {
                                    rateTile("Effective Rate", "\(CalcFormat.fixed(r.effectiveRate, 1))%")
                                    rateTile("Marginal Rate", "\(CalcFormat.raw(r.marginalRate))%")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filingStatusLabel: String {
        switch filingStatus {
        case .mfj: return "Married Filing Jointly"
        case .hoh: return "Head of Household"
        default: return "Single"
        }
    }

    private func rateTile(_ caption: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(caption)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
            Text(value)
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Theme.blueSoftBG)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

// MARK: - Refund Estimator

private struct RefundEstimatorCard: View {
    @State private var income = ""
    @State private var withheld = ""
    @State private var credits = ""
    @State private var results: Result?

    private struct Result {
        let taxLiability: Double
        let withheld: Double
        let credits: Double
        let refund: Double
        let owes: Bool
    }

    private func calculate() {
        let incomeNum = sanitizeNumber(income)
        let withheldNum = sanitizeNumber(withheld)
        let creditsNum = sanitizeNumber(credits)
        let standardDeduction = STANDARD_DEDUCTION_2024[.single]!
        let taxableIncome = max(0, incomeNum - standardDeduction)
        let tax = bracketTax(taxableIncome, .single)
        let totalTaxLiability = max(0, tax - creditsNum)
        let refund = withheldNum - totalTaxLiability
        results = Result(
            taxLiability: totalTaxLiability,
            withheld: withheldNum,
            credits: creditsNum,
            refund: refund,
            owes: refund < 0
        )
    }

    var body: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Federal Tax Refund Estimator")
                FCCardDescription("Estimate your potential federal tax refund")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        NumericField(label: "Total Annual Income", placeholder: "$65,000", text: $income)
                        NumericField(label: "Federal Tax Withheld", placeholder: "$8,500", text: $withheld)
                        NumericField(label: "Federal Tax Credits", placeholder: "$2,000", text: $credits)
                        FCButton(size: .lg, label: {
                            Text("Calculate Federal Refund").frame(maxWidth: .infinity)
                        }, action: calculate)
                    }

                    if let r = results {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Federal Refund Results")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)

                            VStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.greenStrong)
                                Text("\(r.owes ? "-" : "")\(dollarsInt(abs(r.refund)))")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(r.owes ? Theme.redStrong : Theme.greenStrong)
                                Text(r.owes ? "Estimated Federal Amount Owed" : "Estimated Federal Refund")
                                    .font(.system(size: Theme.FontSize.sm))
                                    .foregroundColor(Theme.greenStrong)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Theme.greenSoftBG)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .strokeBorder(Theme.greenSoftBorder, lineWidth: 2)
                            )

                            VStack(spacing: 8) {
                                MutedPanel(padding: 8) {
                                    TaxRow(label: "Fed. Tax Liability", value: dollarsInt(r.taxLiability), small: true)
                                }
                                MutedPanel(padding: 8) {
                                    TaxRow(label: "Fed. Tax Withheld", value: dollarsInt(r.withheld), small: true)
                                }
                                MutedPanel(padding: 8) {
                                    TaxRow(label: "Fed. Tax Credits", value: dollarsInt(r.credits), small: true)
                                }
                            }
                        }
                    } else {
                        EmptyResult(icon: "dollarsign.circle",
                                    message: "Enter your info to estimate your federal refund.")
                    }
                }
            }
        }
    }
}

// MARK: - Deduction Finder

private struct DeductionItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let common: Bool
    let hypotheticalValue: Double
}

private struct DeductionCategory: Identifiable {
    let id = UUID()
    let category: String
    let items: [DeductionItem]
}

private let deductionItemsData: [DeductionCategory] = [
    DeductionCategory(category: "Home & Property", items: [
        DeductionItem(name: "Mortgage Interest", amount: "Up to $750k loan", common: true, hypotheticalValue: 8000),
        DeductionItem(name: "Property Taxes", amount: "SALT Cap $10k", common: true, hypotheticalValue: 5000),
        DeductionItem(name: "Home Office", amount: "$5/sq ft (max $1.5k)", common: false, hypotheticalValue: 1500),
        DeductionItem(name: "Energy Credits", amount: "Up to $3.2k", common: false, hypotheticalValue: 1000),
    ]),
    DeductionCategory(category: "Medical & Health", items: [
        DeductionItem(name: "Medical Expenses", amount: "> 7.5% of AGI", common: false, hypotheticalValue: 3000),
        DeductionItem(name: "HSA Contributions", amount: "Up to $4.15k/$8.3k", common: true, hypotheticalValue: 4150),
    ]),
    DeductionCategory(category: "Education", items: [
        DeductionItem(name: "Student Loan Interest", amount: "Up to $2.5k", common: true, hypotheticalValue: 2500),
        DeductionItem(name: "Educator Expenses", amount: "Up to $300", common: false, hypotheticalValue: 300),
    ]),
    DeductionCategory(category: "Charitable & Other", items: [
        DeductionItem(name: "Charitable Donations", amount: "Up to 60% AGI", common: true, hypotheticalValue: 2000),
        DeductionItem(name: "State & Local Taxes (SALT)", amount: "Up to $10k", common: true, hypotheticalValue: 10000),
        DeductionItem(name: "Business Expenses", amount: "Self-employed", common: false, hypotheticalValue: 5000),
    ]),
    DeductionCategory(category: "Retirement", items: [
        DeductionItem(name: "Traditional IRA", amount: "Up to $7k/$8k", common: true, hypotheticalValue: 7000),
        DeductionItem(name: "Self-Employed Retirement", amount: "Varies", common: false, hypotheticalValue: 10000),
    ]),
]

private struct DeductionFinderCard: View {
    @State private var selected: Set<String> = []

    private func key(_ category: String, _ name: String) -> String { "\(category)-\(name)" }

    private struct Summary {
        let totalItemized: Double
        let standardDeduction: Double
        let shouldItemize: Bool
        let savings: Double
        let selectedCount: Int
    }

    /// Recomputed live whenever a checkbox toggles (web `calculateDeductions`).
    private var summary: Summary? {
        guard !selected.isEmpty else { return nil }
        var total: Double = 0
        var count = 0
        for category in deductionItemsData {
            for item in category.items where selected.contains(key(category.category, item.name)) {
                count += 1
                total += item.hypotheticalValue
            }
        }
        let standardDeduction = STANDARD_DEDUCTION_2024[.single]!
        let shouldItemize = total > standardDeduction
        return Summary(
            totalItemized: total,
            standardDeduction: standardDeduction,
            shouldItemize: shouldItemize,
            savings: shouldItemize ? total - standardDeduction : 0,
            selectedCount: count
        )
    }

    var body: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Federal Deduction Finder")
                FCCardDescription("Discover potential federal tax deductions")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(deductionItemsData) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Circle().fill(Theme.primary).frame(width: 8, height: 8)
                                Text(category.category)
                                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                    .foregroundColor(Theme.foreground)
                            }
                            VStack(spacing: 12) {
                                ForEach(category.items) { item in
                                    deductionCell(category.category, item)
                                }
                            }
                        }
                    }

                    if let s = summary {
                        summaryCard(s)
                    }
                }
            }
        }
    }

    private func deductionCell(_ category: String, _ item: DeductionItem) -> some View {
        let k = key(category, item.name)
        let isOn = selected.contains(k)
        return Button {
            if isOn { selected.remove(k) } else { selected.insert(k) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.name)
                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if item.common {
                        FCBadge("Common", variant: .secondary)
                    }
                }
                Text(item.amount)
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(isOn ? Theme.primary : Theme.mutedForeground)
                    Text("I believe I qualify")
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.foreground)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(isOn ? Theme.primary : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryCard(_ s: Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Potential Federal Deduction Summary")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.foreground)
            TaxRow(label: "Selected Potential Deductions", value: "\(s.selectedCount) items")
            TaxRow(label: "Estimated Itemized Total*", value: dollarsInt(s.totalItemized))
            TaxRow(label: "Standard Deduction (Single)", value: dollarsInt(s.standardDeduction))
            Divider()
            HStack {
                Text("Recommendation")
                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                Spacer(minLength: 8)
                Text(s.shouldItemize ? "Likely Better to Itemize (Federal)" : "Likely Better to Take Standard (Federal)")
                    .font(.system(size: Theme.FontSize.sm, weight: .bold))
                    .foregroundColor(Theme.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

            if s.shouldItemize {
                Text("Itemizing could potentially increase your federal deduction by \(dollarsInt(s.savings))!*")
                    .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                    .foregroundColor(Theme.greenStrong)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Theme.greenSoftBG)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            }

            Text("*Based on hypothetical values. Actual amounts vary. State deduction rules differ.")
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.blueSoftBG)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

// MARK: - Quarterly Calculator

private struct QuarterlyCalculatorCard: View {
    @State private var netIncome = ""
    @State private var results: Result?

    private struct Result {
        let netIncome: Double
        let selfEmploymentTax: Double
        let incomeTax: Double
        let totalTax: Double
        let quarterlyPayment: Double
    }

    private func calculate() {
        let net = sanitizeNumber(netIncome)
        let se = computeSelfEmploymentTax([.taxpayer: net, .spouse: 0], [.taxpayer: 0, .spouse: 0])
        let selfEmploymentTax = se.seTax
        let deductibleSETax = se.deduction
        let adjustedIncome = net - deductibleSETax
        let standardDeduction = STANDARD_DEDUCTION_2024[.single]!
        let taxableIncome = max(0, adjustedIncome - standardDeduction)
        let incomeTax = bracketTax(taxableIncome, .single)
        let totalFederalTax = incomeTax + selfEmploymentTax
        results = Result(
            netIncome: net,
            selfEmploymentTax: selfEmploymentTax,
            incomeTax: incomeTax,
            totalTax: totalFederalTax,
            quarterlyPayment: totalFederalTax / 4
        )
    }

    var body: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Quarterly Federal Tax Payment Calculator")
                FCCardDescription("Estimate federal tax payments for self-employed individuals")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        NumericField(label: "Expected Annual Net Income (After Expenses)",
                                     placeholder: "$80,000", text: $netIncome)
                        FCButton(size: .lg, label: {
                            Text("Calculate Federal Quarterly Payments").frame(maxWidth: .infinity)
                        }, action: calculate)
                    }

                    if let r = results {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Federal Payment Results")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)

                            MutedPanel(padding: 16) {
                                TaxRow(label: "Net Income (Est.)", value: dollarsLoc(r.netIncome), small: true)
                                TaxRow(label: "Fed. Income Tax (Est.)", value: dollarsInt(r.incomeTax), small: true)
                                TaxRow(label: "SE Tax (Est.)", value: dollarsInt(r.selfEmploymentTax), small: true)
                                Divider()
                                TaxRow(label: "Total Annual Federal Tax (Est.)", value: dollarsInt(r.totalTax))
                            }

                            Text("Estimated Federal Payments")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)

                            VStack(spacing: 12) {
                                quarterRow("Q1", "Due: April 15", r.quarterlyPayment)
                                quarterRow("Q2", "Due: June 17", r.quarterlyPayment)
                                quarterRow("Q3", "Due: September 16", r.quarterlyPayment)
                                quarterRow("Q4", "Due: January 15, 2025", r.quarterlyPayment)
                            }

                            Text("State quarterly payments may also be required.")
                                .font(.system(size: Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        EmptyResult(icon: "calendar",
                                    message: "Enter net income to estimate federal payments.")
                    }
                }
            }
        }
    }

    private func quarterRow(_ label: String, _ due: String, _ amount: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: Theme.FontSize.base, weight: .medium))
                    .foregroundColor(Theme.foreground)
                Text(due)
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
            }
            Spacer(minLength: 8)
            Text(dollarsInt(amount))
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.foreground)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Withholding Calculator

private struct WithholdingCalculatorCard: View {
    @State private var income = ""
    @State private var payPeriods = "26"
    @State private var allowances = "0"
    @State private var results: Result?

    private struct Result {
        let annualTax: Double
        let perPaycheck: Double
        let monthlyWithholding: Double
        let payPeriods: Double
        let allowances: Double
    }

    private func calculate() {
        let incomeNum = sanitizeNumber(income)
        let payPeriodsNum = sanitizeNumber(payPeriods) != 0 ? sanitizeNumber(payPeriods) : 26
        let allowancesNum = sanitizeNumber(allowances)
        let standardDeduction = STANDARD_DEDUCTION_2024[.single]!
        let taxableIncome = max(0, incomeNum - standardDeduction)
        let annualTax = bracketTax(taxableIncome, .single)
        let simplifiedAllowanceValue: Double = 5150
        let adjustedAnnualTax = max(0, annualTax - (allowancesNum * simplifiedAllowanceValue * 0.12))
        results = Result(
            annualTax: adjustedAnnualTax,
            perPaycheck: adjustedAnnualTax / payPeriodsNum,
            monthlyWithholding: adjustedAnnualTax / 12,
            payPeriods: payPeriodsNum,
            allowances: allowancesNum
        )
    }

    var body: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Federal Withholding Calculator")
                FCCardDescription("Estimate federal tax withholdings from your paycheck (simplified)")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        NumericField(label: "Annual Salary", placeholder: "$75,000", text: $income)
                        NumericField(label: "Pay Periods per Year", placeholder: "26 (bi-weekly)",
                                     text: $payPeriods, helper: "Weekly: 52, Bi-weekly: 26, Monthly: 12")
                        NumericField(label: "W-4 Allowances (Simplified)", placeholder: "0",
                                     text: $allowances, helper: "Note: Uses older allowance system for estimation.")
                        FCButton(size: .lg, label: {
                            Text("Calculate Federal Withholding").frame(maxWidth: .infinity)
                        }, action: calculate)
                    }

                    if let r = results {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Federal Withholding Results")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)

                            VStack(spacing: 8) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.blueStrong)
                                Text(dollarsInt(r.perPaycheck))
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(Theme.blueStrong)
                                Text("Federal Tax Per Paycheck (Est.)")
                                    .font(.system(size: Theme.FontSize.sm))
                                    .foregroundColor(Theme.blueStrong)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Theme.blueSoftBG)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

                            VStack(spacing: 12) {
                                MutedPanel { TaxRow(label: "Est. Annual Federal Tax", value: dollarsInt(r.annualTax)) }
                                MutedPanel { TaxRow(label: "Est. Monthly Federal Withholding", value: dollarsInt(r.monthlyWithholding)) }
                                MutedPanel { TaxRow(label: "Pay Periods", value: CalcFormat.raw(r.payPeriods)) }
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                (Text("Tip: ").bold() +
                                 Text("Use the official IRS Withholding Estimator for accurate W-4 adjustments. State withholding not included."))
                                    .font(.system(size: Theme.FontSize.sm))
                                    .foregroundColor(Theme.yellowText)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.yellowSoftBG)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .strokeBorder(Theme.yellowBorder, lineWidth: 1)
                            )
                        }
                    } else {
                        EmptyResult(icon: "chart.pie",
                                    message: "Enter info to estimate federal withholding.")
                    }

                    // About W-4 panel (always shown, web bottom info box).
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.foreground)
                            Text("About W-4 Withholding")
                                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                        }
                        Text("Your W-4 form tells your employer how much federal tax to withhold. Adjusting it helps match your tax liability to avoid owing or overpaying significantly.")
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(Theme.mutedForeground)
                        Link(destination: URL(string: "https://www.irs.gov/individuals/tax-withholding-estimator")!) {
                            HStack(spacing: 4) {
                                Text("Use Official IRS Estimator")
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                            }
                            .font(.system(size: Theme.FontSize.sm, weight: .medium))
                            .foregroundColor(Theme.primary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.muted)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Shared menu label

/// A dropdown label styled like `FCTextField` / web `<SelectTrigger>`.
private func menuLabel(_ text: String) -> some View {
    HStack {
        Text(text)
            .foregroundColor(Theme.foreground)
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 12))
            .foregroundColor(Theme.mutedForeground)
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

// MARK: - Preview

#Preview("Tax Calculators") {
    NavigationStack {
        TaxCalculatorsView()
    }
}
