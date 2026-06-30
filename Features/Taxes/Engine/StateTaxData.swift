/**
 * StateTaxData.swift
 *
 * State tax module — a config-driven engine: each state supplies its 2024
 * brackets, standard deduction, and exemptions; a generic computation applies
 * them starting from federal AGI (with the common Social Security / retirement
 * subtractions). State-specific subtractions, itemizing, and credits beyond
 * these are simplified — each state carries a `note` describing the estimate's
 * limits.
 *
 * Pure-Swift port of components/tax-engine/engine/stateTaxData (types.ts,
 * data2024.ts, index.ts). Foundation-only — no SwiftUI/UIKit/Combine.
 *
 * Faithful 1:1 mirror of the TypeScript: same exported names, same constants,
 * same formulas, same rounding, same conditionals and order of operations.
 * TS `number` -> Swift `Double`, TS optional (`?` / `| undefined`) -> Swift
 * `Optional`, TS `Record<FilingStatus, T>` -> `[FilingStatus: T]`,
 * TS `StateCode | ""` -> `StateCode?`.
 *
 * NOTE: `StateResult` is already defined in TaxModels.swift and is reused here
 * (it is the engine's public result type). `dollar` / `nonNeg` come from
 * TaxRound.swift.
 */

import Foundation

// MARK: - types.ts

public struct StateBracket: Equatable {
    public let rate: Double
    public let min: Double
    public let max: Double

    public init(rate: Double, min: Double, max: Double) {
        self.rate = rate
        self.min = min
        self.max = max
    }
}

public struct StateInput {
    /// TS: `StateCode | ""` — empty represented by `nil`.
    public var code: StateCode?
    /// Federal AGI from the federal computation.
    public var federalAgi: Double
    /// Taxable Social Security included in federal AGI (subtracted by most states).
    public var taxableSocialSecurity: Double
    /// Taxable retirement/pension distributions (subtracted by states that exclude them).
    public var retirementDistributions: Double
    public var filingStatus: FilingStatus
    /// Number of dependents claimed.
    public var dependents: Double
    /// State income tax withheld (W-2 box 17 + any extra).
    public var stateWithholding: Double
    public var age65: Bool

    public init(
        code: StateCode? = nil,
        federalAgi: Double,
        taxableSocialSecurity: Double,
        retirementDistributions: Double,
        filingStatus: FilingStatus,
        dependents: Double,
        stateWithholding: Double,
        age65: Bool
    ) {
        self.code = code
        self.federalAgi = federalAgi
        self.taxableSocialSecurity = taxableSocialSecurity
        self.retirementDistributions = retirementDistributions
        self.filingStatus = filingStatus
        self.dependents = dependents
        self.stateWithholding = stateWithholding
        self.age65 = age65
    }
}

public struct StateConfig {
    public let code: StateCode
    public let name: String
    public let hasIncomeTax: Bool
    /// Brackets per filing status (use the builders to share across statuses).
    public let brackets: [FilingStatus: [StateBracket]]?
    public let standardDeduction: [FilingStatus: Double]?
    /// Per-person deduction (taxpayer + spouse).
    public let personalExemption: Double?
    /// Per-dependent deduction.
    public let dependentExemption: Double?
    /// Per-person credit applied against tax (e.g. California).
    public let exemptionCredit: Double?
    /// Per-dependent credit applied against tax (e.g. California).
    public let dependentExemptionCredit: Double?
    /// Whether the state taxes Social Security benefits (all 15 here: false).
    public let taxesSocialSecurity: Bool?
    /// Whether the state excludes retirement/pension income (IL, PA).
    public let excludesRetirement: Bool?
    public let note: String?

    public init(
        code: StateCode,
        name: String,
        hasIncomeTax: Bool,
        brackets: [FilingStatus: [StateBracket]]? = nil,
        standardDeduction: [FilingStatus: Double]? = nil,
        personalExemption: Double? = nil,
        dependentExemption: Double? = nil,
        exemptionCredit: Double? = nil,
        dependentExemptionCredit: Double? = nil,
        taxesSocialSecurity: Bool? = nil,
        excludesRetirement: Bool? = nil,
        note: String? = nil
    ) {
        self.code = code
        self.name = name
        self.hasIncomeTax = hasIncomeTax
        self.brackets = brackets
        self.standardDeduction = standardDeduction
        self.personalExemption = personalExemption
        self.dependentExemption = dependentExemption
        self.exemptionCredit = exemptionCredit
        self.dependentExemptionCredit = dependentExemptionCredit
        self.taxesSocialSecurity = taxesSocialSecurity
        self.excludesRetirement = excludesRetirement
        self.note = note
    }
}

// MARK: - data2024.ts

/// `const FLAT = (rate) => [{ rate, min: 0, max: Infinity }]`
private func FLAT(_ rate: Double) -> [StateBracket] {
    return [StateBracket(rate: rate, min: 0, max: .infinity)]
}

/// Same brackets for every filing status.
private func uniform(_ b: [StateBracket]) -> [FilingStatus: [StateBracket]] {
    return [.single: b, .mfj: b, .mfs: b, .hoh: b, .qss: b]
}

/// Map single/mfj/hoh → all statuses (mfs uses single; qss uses mfj).
private func byStatus(
    single: [StateBracket],
    mfj: [StateBracket],
    hoh: [StateBracket]
) -> [FilingStatus: [StateBracket]] {
    return [.single: single, .mfs: single, .mfj: mfj, .qss: mfj, .hoh: hoh]
}

/// Standard deduction record from the common (single, mfj, hoh) values.
private func std(
    _ single: Double,
    _ mfj: Double,
    _ hoh: Double,
    _ mfs: Double? = nil,
    _ qss: Double? = nil
) -> [FilingStatus: Double] {
    return [
        .single: single,
        .mfj: mfj,
        .hoh: hoh,
        .mfs: mfs ?? single,
        .qss: qss ?? mfj,
    ]
}

private let NO_TAX_NOTE = "No state income tax."

public let STATE_CONFIGS: [String: StateConfig] = [
    // ---- No income tax ----
    "TX": StateConfig(code: .TX, name: "Texas", hasIncomeTax: false, note: NO_TAX_NOTE),
    "FL": StateConfig(code: .FL, name: "Florida", hasIncomeTax: false, note: NO_TAX_NOTE),
    "TN": StateConfig(code: .TN, name: "Tennessee", hasIncomeTax: false, note: NO_TAX_NOTE),
    "WA": StateConfig(
        code: .WA,
        name: "Washington",
        hasIncomeTax: false,
        note: "No state income tax on wages. (Washington has a separate 7% excise on large long-term capital gains, not modeled here.)"
    ),

    // ---- Flat rate ----
    "PA": StateConfig(
        code: .PA,
        name: "Pennsylvania",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.0307)),
        taxesSocialSecurity: false,
        excludesRetirement: true,
        note: "Flat 3.07%. Retirement income and Social Security aren't taxed; PA's class-of-income rules are approximated from federal AGI."
    ),
    "IL": StateConfig(
        code: .IL,
        name: "Illinois",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.0495)),
        personalExemption: 2_775,
        dependentExemption: 2_775,
        excludesRetirement: true,
        note: "Flat 4.95%; retirement income and Social Security excluded."
    ),
    "MI": StateConfig(
        code: .MI,
        name: "Michigan",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.0425)),
        personalExemption: 5_600,
        dependentExemption: 5_600,
        note: "Flat 4.25%. Social Security excluded; age-based retirement subtractions are not modeled."
    ),
    "NC": StateConfig(
        code: .NC,
        name: "North Carolina",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.045)),
        standardDeduction: std(12_750, 25_500, 19_125),
        note: "Flat 4.5%. Social Security excluded."
    ),
    "AZ": StateConfig(
        code: .AZ,
        name: "Arizona",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.025)),
        standardDeduction: std(14_600, 29_200, 21_900),
        note: "Flat 2.5% (standard deduction matches federal). Social Security excluded."
    ),
    "GA": StateConfig(
        code: .GA,
        name: "Georgia",
        hasIncomeTax: true,
        brackets: uniform(FLAT(0.0539)),
        standardDeduction: std(12_000, 24_000, 12_000),
        dependentExemption: 4_000,
        note: "Flat 5.39% (2024). Social Security excluded; the 62+ retirement exclusion isn't modeled."
    ),
    "OH": StateConfig(
        code: .OH,
        name: "Ohio",
        hasIncomeTax: true,
        brackets: uniform([
            StateBracket(rate: 0, min: 0, max: 26_050),
            StateBracket(rate: 0.0275, min: 26_050, max: 100_000),
            StateBracket(rate: 0.035, min: 100_000, max: .infinity),
        ]),
        personalExemption: 2_400,
        dependentExemption: 2_400,
        note: "2024 brackets (0% up to $26,050, then 2.75%/3.5%). Social Security excluded."
    ),

    // ---- Progressive ----
    "VA": StateConfig(
        code: .VA,
        name: "Virginia",
        hasIncomeTax: true,
        brackets: uniform([
            StateBracket(rate: 0.02, min: 0, max: 3_000),
            StateBracket(rate: 0.03, min: 3_000, max: 5_000),
            StateBracket(rate: 0.05, min: 5_000, max: 17_000),
            StateBracket(rate: 0.0575, min: 17_000, max: .infinity),
        ]),
        standardDeduction: std(8_500, 17_000, 8_500),
        personalExemption: 930,
        dependentExemption: 930,
        note: "Social Security excluded; the age deduction isn't modeled."
    ),
    "CA": StateConfig(
        code: .CA,
        name: "California",
        hasIncomeTax: true,
        brackets: byStatus(
            single: [
                StateBracket(rate: 0.01, min: 0, max: 10_412),
                StateBracket(rate: 0.02, min: 10_412, max: 24_684),
                StateBracket(rate: 0.04, min: 24_684, max: 38_959),
                StateBracket(rate: 0.06, min: 38_959, max: 54_081),
                StateBracket(rate: 0.08, min: 54_081, max: 68_350),
                StateBracket(rate: 0.093, min: 68_350, max: 349_137),
                StateBracket(rate: 0.103, min: 349_137, max: 418_961),
                StateBracket(rate: 0.113, min: 418_961, max: 698_271),
                StateBracket(rate: 0.123, min: 698_271, max: .infinity),
            ],
            mfj: [
                StateBracket(rate: 0.01, min: 0, max: 20_824),
                StateBracket(rate: 0.02, min: 20_824, max: 49_368),
                StateBracket(rate: 0.04, min: 49_368, max: 77_918),
                StateBracket(rate: 0.06, min: 77_918, max: 108_162),
                StateBracket(rate: 0.08, min: 108_162, max: 136_700),
                StateBracket(rate: 0.093, min: 136_700, max: 698_274),
                StateBracket(rate: 0.103, min: 698_274, max: 837_922),
                StateBracket(rate: 0.113, min: 837_922, max: 1_396_542),
                StateBracket(rate: 0.123, min: 1_396_542, max: .infinity),
            ],
            hoh: [
                StateBracket(rate: 0.01, min: 0, max: 20_839),
                StateBracket(rate: 0.02, min: 20_839, max: 49_371),
                StateBracket(rate: 0.04, min: 49_371, max: 63_644),
                StateBracket(rate: 0.06, min: 63_644, max: 78_765),
                StateBracket(rate: 0.08, min: 78_765, max: 93_037),
                StateBracket(rate: 0.093, min: 93_037, max: 474_824),
                StateBracket(rate: 0.103, min: 474_824, max: 569_790),
                StateBracket(rate: 0.113, min: 569_790, max: 949_649),
                StateBracket(rate: 0.123, min: 949_649, max: .infinity),
            ]
        ),
        standardDeduction: std(5_540, 11_080, 11_080),
        exemptionCredit: 149,
        dependentExemptionCredit: 461,
        note: "Social Security excluded. The 1% mental-health surcharge over $1M isn't modeled."
    ),
    "NY": StateConfig(
        code: .NY,
        name: "New York",
        hasIncomeTax: true,
        brackets: byStatus(
            single: [
                StateBracket(rate: 0.04, min: 0, max: 8_500),
                StateBracket(rate: 0.045, min: 8_500, max: 11_700),
                StateBracket(rate: 0.0525, min: 11_700, max: 13_900),
                StateBracket(rate: 0.055, min: 13_900, max: 80_650),
                StateBracket(rate: 0.06, min: 80_650, max: 215_400),
                StateBracket(rate: 0.0685, min: 215_400, max: 1_077_550),
                StateBracket(rate: 0.0965, min: 1_077_550, max: 5_000_000),
                StateBracket(rate: 0.103, min: 5_000_000, max: 25_000_000),
                StateBracket(rate: 0.109, min: 25_000_000, max: .infinity),
            ],
            mfj: [
                StateBracket(rate: 0.04, min: 0, max: 17_150),
                StateBracket(rate: 0.045, min: 17_150, max: 23_600),
                StateBracket(rate: 0.0525, min: 23_600, max: 27_900),
                StateBracket(rate: 0.055, min: 27_900, max: 161_550),
                StateBracket(rate: 0.06, min: 161_550, max: 323_200),
                StateBracket(rate: 0.0685, min: 323_200, max: 2_155_350),
                StateBracket(rate: 0.0965, min: 2_155_350, max: 5_000_000),
                StateBracket(rate: 0.103, min: 5_000_000, max: 25_000_000),
                StateBracket(rate: 0.109, min: 25_000_000, max: .infinity),
            ],
            hoh: [
                StateBracket(rate: 0.04, min: 0, max: 12_800),
                StateBracket(rate: 0.045, min: 12_800, max: 17_650),
                StateBracket(rate: 0.0525, min: 17_650, max: 20_900),
                StateBracket(rate: 0.055, min: 20_900, max: 107_650),
                StateBracket(rate: 0.06, min: 107_650, max: 269_300),
                StateBracket(rate: 0.0685, min: 269_300, max: 1_616_450),
                StateBracket(rate: 0.0965, min: 1_616_450, max: 5_000_000),
                StateBracket(rate: 0.103, min: 5_000_000, max: 25_000_000),
                StateBracket(rate: 0.109, min: 25_000_000, max: .infinity),
            ]
        ),
        standardDeduction: std(8_000, 16_050, 11_200),
        dependentExemption: 1_000,
        note: "Social Security excluded; pension exclusion and tax-benefit recapture aren't modeled."
    ),
    "NJ": StateConfig(
        code: .NJ,
        name: "New Jersey",
        hasIncomeTax: true,
        brackets: byStatus(
            single: [
                StateBracket(rate: 0.014, min: 0, max: 20_000),
                StateBracket(rate: 0.0175, min: 20_000, max: 35_000),
                StateBracket(rate: 0.035, min: 35_000, max: 40_000),
                StateBracket(rate: 0.05525, min: 40_000, max: 75_000),
                StateBracket(rate: 0.0637, min: 75_000, max: 500_000),
                StateBracket(rate: 0.0897, min: 500_000, max: 1_000_000),
                StateBracket(rate: 0.1075, min: 1_000_000, max: .infinity),
            ],
            mfj: [
                StateBracket(rate: 0.014, min: 0, max: 20_000),
                StateBracket(rate: 0.0175, min: 20_000, max: 50_000),
                StateBracket(rate: 0.0245, min: 50_000, max: 70_000),
                StateBracket(rate: 0.035, min: 70_000, max: 80_000),
                StateBracket(rate: 0.05525, min: 80_000, max: 150_000),
                StateBracket(rate: 0.0637, min: 150_000, max: 500_000),
                StateBracket(rate: 0.0897, min: 500_000, max: 1_000_000),
                StateBracket(rate: 0.1075, min: 1_000_000, max: .infinity),
            ],
            hoh: [
                StateBracket(rate: 0.014, min: 0, max: 20_000),
                StateBracket(rate: 0.0175, min: 20_000, max: 50_000),
                StateBracket(rate: 0.0245, min: 50_000, max: 70_000),
                StateBracket(rate: 0.035, min: 70_000, max: 80_000),
                StateBracket(rate: 0.05525, min: 80_000, max: 150_000),
                StateBracket(rate: 0.0637, min: 150_000, max: 500_000),
                StateBracket(rate: 0.0897, min: 500_000, max: 1_000_000),
                StateBracket(rate: 0.1075, min: 1_000_000, max: .infinity),
            ]
        ),
        personalExemption: 1_000,
        dependentExemption: 1_500,
        note: "No standard deduction. Social Security excluded; the retirement-income exclusion isn't modeled."
    ),
]

// MARK: - index.ts

private func bracketTax(_ amount: Double, _ brackets: [StateBracket]) -> Double {
    if amount <= 0 { return 0 }
    var tax: Double = 0
    for b in brackets {
        if amount > b.min { tax += (Swift.min(amount, b.max) - b.min) * b.rate }
    }
    return tax
}

private func isMarried(_ s: FilingStatus) -> Bool {
    return s == .mfj || s == .qss
}

private func computeFromConfig(_ cfg: StateConfig, _ input: StateInput) -> StateResult {
    // TS spreads `...base` into the result; `base` = { code, name, withheld }.
    let baseCode = cfg.code
    let baseName = cfg.name
    let baseWithheld = dollar(input.stateWithholding)

    if !cfg.hasIncomeTax || cfg.brackets == nil {
        return StateResult(
            code: baseCode,
            name: baseName,
            hasIncomeTax: false,
            supported: true,
            stateAgi: 0,
            taxableIncome: 0,
            tax: 0,
            withheld: baseWithheld,
            refundOrOwed: dollar(input.stateWithholding),
            note: cfg.note
        )
    }

    let persons: Double = 1 + (isMarried(input.filingStatus) ? 1 : 0)

    var stateAgi = input.federalAgi
    if !(cfg.taxesSocialSecurity ?? false) { stateAgi -= input.taxableSocialSecurity }
    if cfg.excludesRetirement ?? false { stateAgi -= input.retirementDistributions }
    stateAgi = nonNeg(stateAgi)

    let standardDeduction: Double = cfg.standardDeduction != nil
        ? (cfg.standardDeduction![input.filingStatus] ?? 0)
        : 0
    let exemptions =
        (cfg.personalExemption ?? 0) * persons + (cfg.dependentExemption ?? 0) * input.dependents
    let taxableIncome = nonNeg(stateAgi - standardDeduction - exemptions)

    var tax = bracketTax(taxableIncome, cfg.brackets![input.filingStatus] ?? [])
    // Exemption credits (e.g. California) reduce tax directly.
    let credits =
        (cfg.exemptionCredit ?? 0) * persons + (cfg.dependentExemptionCredit ?? 0) * input.dependents
    tax = nonNeg(dollar(tax) - credits)

    return StateResult(
        code: baseCode,
        name: baseName,
        hasIncomeTax: true,
        supported: true,
        stateAgi: dollar(stateAgi),
        taxableIncome: dollar(taxableIncome),
        tax: dollar(tax),
        withheld: baseWithheld,
        refundOrOwed: dollar(input.stateWithholding - tax),
        note: cfg.note
    )
}

/// Compute the state result, or nil when no state of residence is set.
public func computeStateTax(_ input: StateInput) -> StateResult? {
    guard let code = input.code else { return nil }
    guard let cfg = STATE_CONFIGS[code.rawValue] else {
        return StateResult(
            code: code,
            name: code.rawValue,
            hasIncomeTax: true,
            supported: false,
            stateAgi: 0,
            taxableIncome: 0,
            tax: 0,
            withheld: dollar(input.stateWithholding),
            refundOrOwed: dollar(input.stateWithholding),
            note: "State tax for this state isn't estimated yet."
        )
    }
    return computeFromConfig(cfg, input)
}

/// One entry in the supported-states list (the supported dropdown).
public struct SupportedState: Equatable {
    public let code: StateCode
    public let name: String
    public let hasIncomeTax: Bool

    public init(code: StateCode, name: String, hasIncomeTax: Bool) {
        self.code = code
        self.name = name
        self.hasIncomeTax = hasIncomeTax
    }
}

/// The set of state codes the engine has data for (the supported dropdown).
/// TS: `Object.values(STATE_CONFIGS).map(...)`.
public let SUPPORTED_STATES: [SupportedState] =
    STATE_CONFIGS.values.map {
        SupportedState(code: $0.code, name: $0.name, hasIncomeTax: $0.hasIncomeTax)
    }
