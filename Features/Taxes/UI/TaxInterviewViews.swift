//
//  TaxInterviewViews.swift
//  FinnaCalcIOS
//
//  SwiftUI port of the FinnaCalc tax-engine interview flow:
//    - components/tax-engine/ui/TaxInterview.tsx
//    - components/tax-engine/ui/QuestionCard.tsx
//    - components/tax-engine/ui/RefundMeter.tsx
//    - components/tax-engine/ui/icons.ts
//
//  TaxInterview is the top-level estimator: it owns the @StateObject
//  TaxEngineViewModel, drives the life → sections → review → filing phase
//  machine, renders one section of QuestionCards at a time, and keeps the live
//  RefundMeter beside the flow. ReviewScreen / FilingScreen / LifeSituations
//  (and the panels they compose: AuditRiskPanel, SmartSuggestions,
//  PrintableSummary) are ported by sibling agents and composed by reference.
//
//  The pure engine (Engine/) and the TaxEngineViewModel are NOT modified — this
//  is presentation only. iOS 16 targets: no SectorMark, no iOS 17 APIs, no new
//  packages; post-await @State writes wrapped in Task { @MainActor in } where
//  applicable.
//

import SwiftUI

// MARK: - icons.ts → SF Symbols

/// Port of `components/tax-engine/ui/icons.ts` — the lucide-react name → icon
/// map used by section headers and life situations. Here each lucide name is
/// mapped to its closest SF Symbol so `Section.icon` / life-situation icon names
/// (which are still lucide names from the question bank) render natively.
enum TaxIcons {
    /// lucide name → SF Symbol system name.
    static let map: [String: String] = [
        "User": "person",
        "Users": "person.2",
        "Briefcase": "briefcase",
        "Store": "storefront",
        "TrendingUp": "chart.line.uptrend.xyaxis",
        "PiggyBank": "banknote",
        "Coins": "dollarsign.circle",
        "Sliders": "slider.horizontal.3",
        "Receipt": "doc.text",
        "Gift": "gift",
        "Wallet": "wallet.pass",
        "Home": "house",
        "GraduationCap": "graduationcap",
        "Baby": "figure.child",
        "Landmark": "building.columns",
        "Zap": "bolt",
    ]

    /// Resolve a lucide icon name to an SF Symbol, falling back to a sensible
    /// default. Mirrors `ICONS[name] ?? null` at the call sites.
    static func symbol(_ lucideName: String?) -> String? {
        guard let name = lucideName, !name.isEmpty else { return nil }
        return map[name]
    }
}

// MARK: - Display formatters (mirror lib/format.ts)

/// Local mirrors of `lib/format.ts`, scoped to the tax UI so money/percent read
/// identically to the web. `CalcFormat` (CalcSupport.swift) provides the same
/// half-up grouped rounding under the hood.
private enum TaxFormat {
    /// `formatCurrency(value, { cents })` — `$1,234.50` (cents) / `$1,235` (no cents).
    static func currency(_ value: Double, cents: Bool = true) -> String {
        CalcFormat.currency(value, fraction: cents ? 2 : 0)
    }

    /// `formatPercent(value, digits)` — appends `%` to the raw stored rate
    /// (the engine stores whole-number percents, e.g. 22 and 14.3).
    static func percent(_ value: Double, _ digits: Int) -> String {
        CalcFormat.decimal(value, fraction: digits) + "%"
    }
}

// MARK: - AnswerValue read helpers

private extension Optional where Wrapped == AnswerValue {
    /// TS `value === true`.
    var asBool: Bool {
        if case .boolean(let b)? = self { return b }
        return false
    }

    /// TS `typeof value === "string" ? value : ""`.
    var asString: String {
        if case .string(let s)? = self { return s }
        return ""
    }

    /// The web renders `String(value)` for numeric/text inputs. For numbers we
    /// mirror JS `String(number)` (no grouping, trailing zeros trimmed).
    func asFieldText(numeric: Bool) -> String {
        _ = numeric // both numeric and text inputs render `String(value)`
        switch self {
        case .some(.string(let s)): return s
        case .some(.number(let d)): return CalcFormat.raw(d)
        case .some(.boolean(let b)): return b ? "true" : "false"
        case .none: return ""
        }
    }
}

// MARK: - QuestionCard

/// Renders a single interview `Question` by its `inputType`, binding edits back
/// through `vm.setAnswer`. Port of QuestionCard.tsx:
///   - boolean → Toggle (Switch)
///   - dollar / integer → FCTextField with a decimal pad ($ prefix for dollar)
///   - select → Menu picker
///   - text → FCTextField
struct QuestionCard: View {
    let question: Question
    /// The live answer for this question (`answers[q.id]`).
    let value: AnswerValue?
    /// `onChange(v)` → `setAnswer(q.id, v)`.
    let onChange: (AnswerValue) -> Void

    private var isNumeric: Bool {
        question.inputType == .dollar || question.inputType == .integer
    }

    var body: some View {
        switch question.inputType {
        case .boolean: booleanCard
        case .select:  selectCard
        case .dollar, .integer, .text: fieldCard
        }
    }

    // boolean → a bordered row with label/help on the left and a Switch.
    private var booleanCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    .foregroundColor(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                if let help = question.helpText {
                    helpView(help)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { value.asBool },
                set: { onChange(.boolean($0)) }
            ))
            .labelsHidden()
            .tint(Theme.primary)
        }
        .padding(16)
        .modifier(QuestionCardChrome())
    }

    // select → label/help + a Menu styled like the web Select trigger.
    private var selectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            if let help = question.helpText {
                helpView(help)
            }
            selectMenu
        }
        .padding(16)
        .modifier(QuestionCardChrome())
    }

    private var selectMenu: some View {
        let current = value.asString
        let selectedLabel = question.options?.first { $0.value == current }?.label
        return Menu {
            ForEach(question.options ?? [], id: \.value) { option in
                Button(option.label) { onChange(.string(option.value)) }
            }
        } label: {
            HStack {
                Text(selectedLabel ?? "Select…")
                    .foregroundColor(selectedLabel == nil ? Theme.mutedForeground : Theme.foreground)
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
    }

    // dollar / integer / text → label/help + FCTextField (with optional $ prefix).
    private var fieldCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            if let help = question.helpText {
                helpView(help)
            }
            fieldRow
        }
        .padding(16)
        .modifier(QuestionCardChrome())
    }

    private var fieldRow: some View {
        HStack(spacing: 6) {
            if question.inputType == .dollar {
                Text("$")
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
            }
            FCTextField(
                placeholder,
                text: textBinding,
                keyboardType: keyboardType
            )
        }
    }

    private var placeholder: String {
        if let p = question.placeholder { return p }
        return question.inputType == .dollar ? "0.00" : ""
    }

    private var keyboardType: UIKeyboardType {
        switch question.inputType {
        case .dollar:  return .decimalPad
        case .integer: return .numberPad
        default:       return .default
        }
    }

    /// Mirrors the web `onChange` parsing: text passes through; numeric inputs
    /// parse to a finite Double (empty / invalid → 0). `allowNegative` keeps the
    /// minus sign for capital gains/losses.
    private var textBinding: Binding<String> {
        Binding(
            get: { value.asFieldText(numeric: isNumeric) },
            set: { raw in
                guard isNumeric else {
                    onChange(.string(raw))
                    return
                }
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    onChange(.number(0))
                    return
                }
                if let parsed = Double(trimmed), parsed.isFinite {
                    // Store the parsed value as-is — the web's `min="0"` is only an
                    // HTML hint and does not block typed negatives, so it keeps the
                    // entered value (engine paths re-clamp where it matters).
                    onChange(.number(parsed))
                } else {
                    // Allow an in-progress "-" or "." without snapping to 0.
                    if trimmed == "-" && question.allowNegative == true {
                        onChange(.string(trimmed))
                    } else {
                        onChange(.number(0))
                    }
                }
            }
        )
    }

    private func helpView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.xs))
            .foregroundColor(Theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `rounded-lg border border-border p-4` chrome shared by every QuestionCard
/// variant (padding is applied per-variant; this adds the border + shape).
private struct QuestionCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - RefundMeter

/// Live running refund / amount-owed estimate. Updates as answers change.
/// Refunds emphasize with `Theme.primary`, balances due with `Theme.destructive`.
/// Port of RefundMeter.tsx.
struct RefundMeter: View {
    let result: TaxCalculationResult

    private var owes: Bool { result.owes }
    private var amount: Double { abs(result.refundOrOwed) }

    var body: some View {
        FCCard {
            FCCardContent {
                VStack(alignment: .leading, spacing: 16) {
                    headline
                    figuresGrid
                    stateBlock
                    rateRow
                }
                .padding(.top, 24) // FCCardContent has pt-0; the web Card uses p-6.
            }
        }
    }

    // Centered headline: caption, big colored figure, "Federal estimate".
    private var headline: some View {
        VStack(spacing: 4) {
            Text(owes ? "Estimated amount you owe" : "Estimated federal refund")
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
            Text(TaxFormat.currency(amount, cents: false))
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
                .foregroundColor(owes ? Theme.destructive : Theme.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Federal estimate")
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    // Two-column grid of the running figures.
    private var figuresGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .topLeading),
                      GridItem(.flexible(), alignment: .topLeading)],
            alignment: .leading,
            spacing: 8
        ) {
            MeterRow(label: "Total income", value: result.totalIncome)
            MeterRow(label: "AGI", value: result.agi)
            MeterRow(
                label: result.deductionUsed == .itemized ? "Itemized ded." : "Standard ded.",
                value: result.deductionAmount
            )
            MeterRow(label: "Taxable income", value: result.taxableIncome)
            MeterRow(label: "Tax before credits", value: result.regularTax)
            MeterRow(
                label: "Credits",
                value: result.totalNonrefundableCredits + result.totalRefundableCredits
            )
            MeterRow(label: "Total tax", value: result.totalTax)
            MeterRow(label: "Payments", value: result.totalPayments)
        }
    }

    // State summary (only when a supported, income-taxing state is present), or a
    // no-income-tax note.
    @ViewBuilder
    private var stateBlock: some View {
        if let state = result.state, state.supported, state.hasIncomeTax {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(state.name) \(state.refundOrOwed < 0 ? "owed" : "refund")")
                        .foregroundColor(Theme.mutedForeground)
                    Spacer()
                    Text(TaxFormat.currency(abs(state.refundOrOwed), cents: false))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(state.refundOrOwed < 0 ? Theme.destructive : Theme.primary)
                }
                .font(.system(size: Theme.FontSize.sm))
                Text("State tax \(TaxFormat.currency(state.tax, cents: false))")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            .padding(.top, 12)
            .overlay(topBorder, alignment: .top)
        } else if let state = result.state, !state.hasIncomeTax {
            Text("\(state.name): no state income tax. 🎉")
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(topBorder, alignment: .top)
        }
    }

    // Marginal / effective rate footer.
    private var rateRow: some View {
        HStack {
            Text("Marginal rate: \(TaxFormat.percent(result.marginalRate, 0))")
            Spacer()
            Text("Effective rate: \(TaxFormat.percent(result.effectiveRate, 1))")
        }
        .font(.system(size: Theme.FontSize.xs))
        .foregroundColor(Theme.mutedForeground)
        .padding(.top, 12)
        .overlay(topBorder, alignment: .top)
    }

    private var topBorder: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    /// One labeled figure (`flex flex-col`: muted caption + bold value).
    private struct MeterRow: View {
        let label: String
        let value: Double
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .foregroundColor(Theme.mutedForeground)
                Text(TaxFormat.currency(value))
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(Theme.foreground)
            }
            .font(.system(size: Theme.FontSize.sm))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - TaxInterview

/// The adaptive tax interview — the top-level estimator view. Owns the engine
/// view model, drives the life → sections → review → filing phase machine, and
/// keeps the live RefundMeter alongside the flow. Port of TaxInterview.tsx.
struct TaxInterview: View {

    /// TS `type Phase = "life" | "sections" | "review" | "filing"`.
    enum Phase { case life, sections, review, filing }

    @StateObject private var vm = TaxEngineViewModel()
    @State private var phase: Phase = .life
    @State private var sectionIndex = 0
    @State private var showResetConfirm = false

    private var visibleSections: [Section] { vm.visibleSections }

    /// `Math.min(sectionIndex, visibleSections.length - 1)`.
    private var clampedIndex: Int {
        guard !visibleSections.isEmpty else { return 0 }
        return min(sectionIndex, visibleSections.count - 1)
    }

    private var currentSection: Section? {
        guard !visibleSections.isEmpty else { return nil }
        return visibleSections[clampedIndex]
    }

    private var currentQuestions: [Question] {
        guard let section = currentSection else { return [] }
        return vm.visibleQuestions(in: section)
    }

    /// `progress` (0–100) over visible sections + the review step.
    private var progress: Double {
        switch phase {
        case .life: return 0
        case .sections:
            let denom = Double(visibleSections.count + 1)
            guard denom > 0 else { return 0 }
            return (Double(clampedIndex + 1) / denom * 100).rounded()
        case .review, .filing: return 100
        }
    }

    var body: some View {
        Group {
            switch phase {
            // ReviewScreen / FilingScreen own their own ScrollView + scaffolding,
            // so they render full-screen (no outer scroll → no nested-scroll
            // collapse). Their internal back/file CTAs drive the phase machine.
            case .review:
                ReviewScreen(vm: vm, onEdit: goToSection, onFile: { phase = .filing })
            case .filing:
                FilingScreen(vm: vm, onBack: { phase = .review })

            // The interview phases scroll inside the estimator scaffold (header,
            // progress, the active step, and the live meter).
            case .life, .sections:
                interviewScaffold
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Tax Estimator")
        .navigationBarTitleDisplayMode(.inline)
        // AlertDialog → confirmation alert for "Start over".
        .alert("Start over?", isPresented: $showResetConfirm) {
            Button("Keep my answers", role: .cancel) {}
            Button("Start over", role: .destructive) {
                vm.reset()
                phase = .life
                sectionIndex = 0
            }
        } message: {
            Text("This clears every answer you've entered and resets your estimate. This can't be undone.")
        }
    }

    // Scrollable scaffold for the life + sections phases.
    private var interviewScaffold: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if phase != .life {
                    ProgressView(value: progress, total: 100)
                        .tint(Theme.primary)
                }
                content
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // Header: "IRS-accurate" badge + "Start over".
    private var header: some View {
        HStack(spacing: 8) {
            Spacer()
            FCBadge("IRS-accurate", variant: .secondary)
            FCButton(variant: .ghost, size: .sm) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Start over")
                }
            } action: {
                showResetConfirm = true
            }
        }
    }

    // The interview body for the life + sections phases. On iPhone the flow
    // stacks vertically (active step on top, live meter below); the web's
    // two-column grid doesn't fit a phone.
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            if phase == .life {
                lifePhase
            } else {
                sectionsPhase
            }

            // Live meter — shown on every interview step.
            VStack(spacing: 12) {
                RefundMeter(result: vm.result)
                if phase == .sections {
                    Text("Step \(clampedIndex + 1) of \(visibleSections.count)")
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Phases

    private var lifePhase: some View {
        VStack(alignment: .leading, spacing: 24) {
            LifeSituations(vm: vm)
            HStack {
                Spacer()
                FCButton(label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }, action: { phase = .sections })
            }
        }
    }

    @ViewBuilder
    private var sectionsPhase: some View {
        if let section = currentSection {
            VStack(alignment: .leading, spacing: 24) {
                FCCard {
                    FCCardHeader {
                        HStack(spacing: 8) {
                            if let symbol = TaxIcons.symbol(section.icon) {
                                Image(systemName: symbol)
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.primary)
                            }
                            FCCardTitle(section.title)
                        }
                        if let description = section.description {
                            FCCardDescription(description)
                        }
                    }
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 12) {
                            if currentQuestions.isEmpty {
                                Text("Nothing to enter here based on your answers — continue.")
                                    .font(.system(size: Theme.FontSize.sm))
                                    .foregroundColor(Theme.mutedForeground)
                            }
                            ForEach(currentQuestions, id: \.id) { q in
                                QuestionCard(
                                    question: q,
                                    value: vm.answers[q.id],
                                    onChange: { vm.setAnswer(q.id, $0) }
                                )
                            }
                        }
                    }
                }

                HStack {
                    FCButton(variant: .outline, label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                    }, action: back)
                    Spacer()
                    FCButton(label: {
                        HStack(spacing: 8) {
                            Text(clampedIndex < visibleSections.count - 1 ? "Next" : "Review")
                            Image(systemName: "arrow.right")
                        }
                    }, action: next)
                }
            }
        }
    }

    // MARK: Navigation

    private func goToSection(_ id: String) {
        if let idx = visibleSections.firstIndex(where: { $0.id == id }) {
            sectionIndex = idx
        } else {
            sectionIndex = 0
        }
        phase = .sections
    }

    private func next() {
        if clampedIndex < visibleSections.count - 1 {
            sectionIndex = clampedIndex + 1
        } else {
            phase = .review
        }
    }

    private func back() {
        if clampedIndex > 0 {
            sectionIndex = clampedIndex - 1
        } else {
            phase = .life
        }
    }
}

// MARK: - Preview

#Preview("Tax Interview") {
    NavigationStack {
        TaxInterview()
    }
}
