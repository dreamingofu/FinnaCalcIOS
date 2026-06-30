/**
 * Build1040Summary.swift
 *
 * Pure-Swift port of components/tax-engine/export/build1040Summary.ts.
 *
 * Pure structuring of a `TaxCalculationResult` into print/PDF-ready groups. No
 * SwiftUI, no I/O — the printable view and any future PDF generator both read
 * this. Foundation-only.
 *
 * Faithful 1:1 mirror of the TypeScript: same group/line ordering, same labels,
 * same form references, same conditional inclusion rules.
 *
 * NOTE ON CREDIT DICTIONARY ORDER: in TS, `Object.entries(...)` iterates in
 * insertion order. Swift's `[String: Double]` is unordered, so to produce a
 * deterministic, stable summary the credit entries are emitted in sorted-key
 * order here. (The engine's dictionaries are small, so this only affects the
 * relative ordering of the per-credit lines, not their content.)
 */

import Foundation

/// TS: `interface SummaryLine { label; amount; formRef? }`.
public struct SummaryLine: Codable, Equatable {
    public var label: String
    public var amount: Double
    public var formRef: String?

    public init(label: String, amount: Double, formRef: String? = nil) {
        self.label = label
        self.amount = amount
        self.formRef = formRef
    }
}

/// TS: `interface SummaryGroup { title; lines }`.
public struct SummaryGroup: Codable, Equatable {
    public var title: String
    public var lines: [SummaryLine]

    public init(title: String, lines: [SummaryLine]) {
        self.title = title
        self.lines = lines
    }
}

/// TS: `Form1040Summary.headline`.
public struct Form1040Headline: Codable, Equatable {
    public var label: String
    public var amount: Double
    public var owes: Bool

    public init(label: String, amount: Double, owes: Bool) {
        self.label = label
        self.amount = amount
        self.owes = owes
    }
}

/// TS: `Form1040Summary.state` (optional block).
public struct Form1040SummaryState: Codable, Equatable {
    public var name: String
    public var hasIncomeTax: Bool
    public var tax: Double
    public var refundOrOwed: Double
    public var note: String?

    public init(name: String, hasIncomeTax: Bool, tax: Double, refundOrOwed: Double, note: String? = nil) {
        self.name = name
        self.hasIncomeTax = hasIncomeTax
        self.tax = tax
        self.refundOrOwed = refundOrOwed
        self.note = note
    }
}

/// TS: `interface Form1040Summary`.
public struct Form1040Summary: Codable, Equatable {
    /// TS literal type `2024`.
    public var taxYear: Int
    public var filingStatusLabel: String
    public var headline: Form1040Headline
    public var groups: [SummaryGroup]
    public var state: Form1040SummaryState?

    public init(
        taxYear: Int = 2024,
        filingStatusLabel: String,
        headline: Form1040Headline,
        groups: [SummaryGroup],
        state: Form1040SummaryState? = nil
    ) {
        self.taxYear = taxYear
        self.filingStatusLabel = filingStatusLabel
        self.headline = headline
        self.groups = groups
        self.state = state
    }
}

/// TS: `const FILING_LABELS: Record<FilingStatus, string>`.
private let filingLabels: [FilingStatus: String] = [
    .single: "Single",
    .mfj: "Married filing jointly",
    .mfs: "Married filing separately",
    .hoh: "Head of household",
    .qss: "Qualifying surviving spouse",
]

/// Title-case a camelCase credit key, e.g. "childTaxCredit" → "Child tax credit".
/// TS: `labelizeCredit`.
private func labelizeCredit(_ key: String) -> String {
    // TS: key.replace(/([A-Z])/g, " $1").toLowerCase()
    var spaced = ""
    for ch in key {
        if ch.isUppercase {
            spaced += " "
        }
        spaced.append(ch)
    }
    spaced = spaced.lowercased()
    // TS: spaced.charAt(0).toUpperCase() + spaced.slice(1)
    guard let first = spaced.first else { return spaced }
    return String(first).uppercased() + spaced.dropFirst()
}

/// TS: `build1040Summary(r: TaxCalculationResult): Form1040Summary`.
public func build1040Summary(_ r: TaxCalculationResult) -> Form1040Summary {
    var groups: [SummaryGroup] = []

    groups.append(SummaryGroup(
        title: "Income",
        lines: [
            SummaryLine(label: "Total income", amount: r.totalIncome, formRef: "1040 line 9"),
            SummaryLine(label: "Adjustments to income", amount: r.totalAdjustments, formRef: "Schedule 1"),
            SummaryLine(label: "Adjusted gross income (AGI)", amount: r.agi, formRef: "1040 line 11"),
        ]
    ))

    var deductionLines: [SummaryLine] = [
        SummaryLine(
            label: r.deductionUsed == .itemized ? "Itemized deductions" : "Standard deduction",
            amount: r.deductionAmount,
            formRef: "1040 line 12"
        )
    ]
    if r.qbiDeduction > 0 {
        deductionLines.append(SummaryLine(label: "QBI deduction", amount: r.qbiDeduction, formRef: "1040 line 13"))
    }
    deductionLines.append(SummaryLine(label: "Taxable income", amount: r.taxableIncome, formRef: "1040 line 15"))
    groups.append(SummaryGroup(title: "Deductions", lines: deductionLines))

    var taxLines: [SummaryLine] = [
        SummaryLine(label: "Income tax", amount: r.regularTax, formRef: "1040 line 16")
    ]
    if r.amt > 0 {
        taxLines.append(SummaryLine(label: "Alternative minimum tax", amount: r.amt, formRef: "Schedule 2"))
    }
    for key in r.nonrefundableCredits.keys.sorted() {
        let amount = r.nonrefundableCredits[key]!
        taxLines.append(SummaryLine(label: "\u{2212} \(labelizeCredit(key))", amount: -amount))
    }
    if r.seTax > 0 {
        taxLines.append(SummaryLine(label: "Self-employment tax", amount: r.seTax, formRef: "Schedule 2"))
    }
    if r.additionalMedicareTax > 0 {
        taxLines.append(SummaryLine(label: "Additional Medicare tax", amount: r.additionalMedicareTax))
    }
    if r.niit > 0 {
        taxLines.append(SummaryLine(label: "Net investment income tax", amount: r.niit))
    }
    taxLines.append(SummaryLine(label: "Total tax", amount: r.totalTax, formRef: "1040 line 24"))
    groups.append(SummaryGroup(title: "Tax & credits", lines: taxLines))

    var payLines: [SummaryLine] = []
    for key in r.refundableCredits.keys.sorted() {
        let amount = r.refundableCredits[key]!
        payLines.append(SummaryLine(label: labelizeCredit(key), amount: amount))
    }
    payLines.append(SummaryLine(
        label: "Total payments & refundable credits",
        amount: r.totalPayments,
        formRef: "1040 line 33"
    ))
    groups.append(SummaryGroup(title: "Payments", lines: payLines))

    let stateBlock: Form1040SummaryState?
    if let s = r.state, s.supported {
        stateBlock = Form1040SummaryState(
            name: s.name,
            hasIncomeTax: s.hasIncomeTax,
            tax: s.tax,
            refundOrOwed: s.refundOrOwed,
            note: s.note
        )
    } else {
        stateBlock = nil
    }

    return Form1040Summary(
        taxYear: 2024,
        filingStatusLabel: filingLabels[r.filingStatus] ?? "",
        headline: Form1040Headline(
            label: r.owes ? "Estimated balance due" : "Estimated federal refund",
            amount: abs(r.refundOrOwed),
            owes: r.owes
        ),
        groups: groups,
        state: stateBlock
    )
}
