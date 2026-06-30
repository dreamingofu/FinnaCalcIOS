/**
 * TaxConstants.swift
 *
 * 2024 tax constants — single source of truth.
 *
 * Pure-Swift port of components/tax-engine/engine/constants (all *.ts files).
 * Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same numeric
 * literals, same bracket tables. TS `number` -> Swift `Double`,
 * TS `Record<FilingStatus, T>` -> Swift `[FilingStatus: T]`, TS object literals
 * -> Swift structs / nested constants.
 *
 * MASTER SOURCES (Tax Year 2024, returns filed in 2025):
 *  - Rev. Proc. 2023-34 — annual inflation adjustments (brackets, standard
 *    deduction, cap-gain breakpoints, student loan / educator phaseouts, etc.)
 *  - 2024 Form 1040 and Instructions; Tax Rate Schedules; Tax Table.
 *  - Schedule 8812 (2024) — Child Tax Credit / ACTC.
 *  - Schedule SE / Form 8959 / Form 8960 (2024) — SE tax, Add'l Medicare, NIIT.
 *  - Social Security Administration — 2024 wage base ($168,600).
 *
 * RULE: no calculation module may contain a numeric tax literal. Every IRS value
 * lives here, annotated with its source, so accuracy is auditable in one place.
 */

import Foundation

// MARK: - brackets2024.ts

/// A 2024 ordinary-income tax bracket. Each bracket is [min, max) of TAXABLE income at `rate`.
public struct Bracket: Equatable {
    /// Marginal rate as a decimal (0.22 = 22%).
    public let rate: Double
    /// Lower bound of taxable income for this bracket (inclusive).
    public let min: Double
    /// Upper bound of taxable income for this bracket (exclusive); Infinity for the top.
    public let max: Double

    public init(rate: Double, min: Double, max: Double) {
        self.rate = rate
        self.min = min
        self.max = max
    }
}

private let SINGLE: [Bracket] = [
    Bracket(rate: 0.1, min: 0, max: 11_600),
    Bracket(rate: 0.12, min: 11_600, max: 47_150),
    Bracket(rate: 0.22, min: 47_150, max: 100_525),
    Bracket(rate: 0.24, min: 100_525, max: 191_950),
    Bracket(rate: 0.32, min: 191_950, max: 243_725),
    Bracket(rate: 0.35, min: 243_725, max: 609_350),
    Bracket(rate: 0.37, min: 609_350, max: .infinity),
]

private let MFJ: [Bracket] = [
    Bracket(rate: 0.1, min: 0, max: 23_200),
    Bracket(rate: 0.12, min: 23_200, max: 94_300),
    Bracket(rate: 0.22, min: 94_300, max: 201_050),
    Bracket(rate: 0.24, min: 201_050, max: 383_900),
    Bracket(rate: 0.32, min: 383_900, max: 487_450),
    Bracket(rate: 0.35, min: 487_450, max: 731_200),
    Bracket(rate: 0.37, min: 731_200, max: .infinity),
]

private let MFS: [Bracket] = [
    Bracket(rate: 0.1, min: 0, max: 11_600),
    Bracket(rate: 0.12, min: 11_600, max: 47_150),
    Bracket(rate: 0.22, min: 47_150, max: 100_525),
    Bracket(rate: 0.24, min: 100_525, max: 191_950),
    Bracket(rate: 0.32, min: 191_950, max: 243_725),
    Bracket(rate: 0.35, min: 243_725, max: 365_600),
    Bracket(rate: 0.37, min: 365_600, max: .infinity),
]

private let HOH: [Bracket] = [
    Bracket(rate: 0.1, min: 0, max: 16_550),
    Bracket(rate: 0.12, min: 16_550, max: 63_100),
    Bracket(rate: 0.22, min: 63_100, max: 100_500),
    Bracket(rate: 0.24, min: 100_500, max: 191_950),
    Bracket(rate: 0.32, min: 191_950, max: 243_700),
    Bracket(rate: 0.35, min: 243_700, max: 609_350),
    Bracket(rate: 0.37, min: 609_350, max: .infinity),
]

public let ORDINARY_BRACKETS_2024: [FilingStatus: [Bracket]] = [
    .single: SINGLE,
    .mfj: MFJ,
    .qss: MFJ, // QSS uses the MFJ schedule
    .mfs: MFS,
    .hoh: HOH,
]

/// 2024 long-term capital gains / qualified dividends rate breakpoints.
/// Values are the TAXABLE-income thresholds where the 0%->15% and 15%->20% rates begin.
public struct CapGainBreakpoints: Equatable {
    /// At/below this taxable income, preferential rate is 0%.
    public let zeroRateMax: Double
    /// Above `zeroRateMax` up to this amount, preferential rate is 15%; above is 20%.
    public let fifteenRateMax: Double

    public init(zeroRateMax: Double, fifteenRateMax: Double) {
        self.zeroRateMax = zeroRateMax
        self.fifteenRateMax = fifteenRateMax
    }
}

public let CAP_GAIN_BREAKPOINTS_2024: [FilingStatus: CapGainBreakpoints] = [
    .single: CapGainBreakpoints(zeroRateMax: 47_025, fifteenRateMax: 518_900),
    .mfj: CapGainBreakpoints(zeroRateMax: 94_050, fifteenRateMax: 583_750),
    .qss: CapGainBreakpoints(zeroRateMax: 94_050, fifteenRateMax: 583_750),
    .mfs: CapGainBreakpoints(zeroRateMax: 47_025, fifteenRateMax: 291_850),
    .hoh: CapGainBreakpoints(zeroRateMax: 63_000, fifteenRateMax: 551_350),
]

// MARK: - standardDeductions2024.ts

/// Base standard deduction by filing status.
public let STANDARD_DEDUCTION_2024: [FilingStatus: Double] = [
    .single: 14_600,
    .mfj: 29_200,
    .qss: 29_200,
    .mfs: 14_600,
    .hoh: 21_900,
]

/// Additional standard deduction per "box" checked (age 65+ and/or blind).
/// Unmarried (single, HOH) get the larger amount; married statuses the smaller.
public struct AdditionalStdDeduction2024 {
    public let unmarried: Double // single, hoh
    public let married: Double // mfj, mfs, qss
}
public let ADDITIONAL_STD_DEDUCTION_2024 = AdditionalStdDeduction2024(
    unmarried: 1_950,
    married: 1_550
)

/// Dependent standard deduction floor and earned-income bump (2024).
public struct DependentStdDeduction2024 {
    /// Minimum standard deduction for someone claimed as a dependent.
    public let floor: Double
    /// Earned income plus this amount (capped at the regular standard deduction).
    public let earnedIncomeBump: Double
}
public let DEPENDENT_STD_DEDUCTION_2024 = DependentStdDeduction2024(
    floor: 1_300,
    earnedIncomeBump: 450
)

/// Returns true if the filing status uses the "married" additional-amount.
public func isMarriedStatus(_ status: FilingStatus) -> Bool {
    return status == .mfj || status == .mfs || status == .qss
}

// MARK: - ctc2024.ts

public struct Ctc2024 {
    /// Maximum Child Tax Credit per qualifying child (under 17).
    public let perChild: Double
    /// Credit for Other Dependents (non-CTC dependents).
    public let perOtherDependent: Double
    /// Maximum REFUNDABLE Additional CTC per qualifying child (2024).
    public let refundableCapPerChild: Double
    /// Earned income above this amount counts toward the 15% ACTC formula.
    public let earnedIncomeThreshold: Double
    /// Refundable ACTC accrues at 15% of earned income over the threshold.
    public let earnedIncomeRate: Double
    /// Phaseout: credit drops $50 for each $1,000 (or fraction) of MAGI over the threshold.
    public let phaseoutPer1000: Double
    public let phaseoutIncrement: Double
}
public let CTC_2024 = Ctc2024(
    perChild: 2_000,
    perOtherDependent: 500,
    refundableCapPerChild: 1_700,
    earnedIncomeThreshold: 2_500,
    earnedIncomeRate: 0.15,
    phaseoutPer1000: 50,
    phaseoutIncrement: 1_000
)

/// MAGI phaseout threshold where CTC/ODC begins to reduce.
public let CTC_PHASEOUT_THRESHOLD_2024: [FilingStatus: Double] = [
    .single: 200_000,
    .hoh: 200_000,
    .mfs: 200_000,
    .qss: 200_000,
    .mfj: 400_000,
]

// MARK: - filingThresholds2024.ts

/// Self-employment tax (Schedule SE). Source: 2024 Schedule SE; SSA wage base.
public struct SeTax2024 {
    /// Net earnings multiplier (Schedule SE line 4a): 92.35%.
    public let netEarningsFactor: Double
    /// Social Security portion rate (12.4%).
    public let socialSecurityRate: Double
    /// Medicare portion rate (2.9%).
    public let medicareRate: Double
    /// 2024 Social Security wage base (max earnings subject to the 12.4%).
    public let socialSecurityWageBase: Double
    /// Deductible fraction of SE tax (above-the-line).
    public let deductibleFraction: Double
}
public let SE_TAX_2024 = SeTax2024(
    netEarningsFactor: 0.9235,
    socialSecurityRate: 0.124,
    medicareRate: 0.029,
    socialSecurityWageBase: 168_600,
    deductibleFraction: 0.5
)

/// Additional Medicare Tax (Form 8959). Source: IRC §3101(b)(2); Form 8959 (2024).
public struct AdditionalMedicare2024 {
    public let rate: Double
    public let thresholds: [FilingStatus: Double]
}
public let ADDITIONAL_MEDICARE_2024 = AdditionalMedicare2024(
    rate: 0.009,
    thresholds: [
        .single: 200_000,
        .hoh: 200_000,
        .qss: 200_000,
        .mfj: 250_000,
        .mfs: 125_000,
    ]
)

/// Net Investment Income Tax (Form 8960). Source: IRC §1411; Form 8960 (2024).
public struct Niit2024 {
    public let rate: Double
    public let thresholds: [FilingStatus: Double]
}
public let NIIT_2024 = Niit2024(
    rate: 0.038,
    thresholds: [
        .single: 200_000,
        .hoh: 200_000,
        .qss: 250_000,
        .mfj: 250_000,
        .mfs: 125_000,
    ]
)

/// Annual capital loss deduction limit (Schedule D). Source: IRC §1211(b).
public let CAPITAL_LOSS_LIMIT_2024: [FilingStatus: Double] = [
    .single: 3_000,
    .mfj: 3_000,
    .qss: 3_000,
    .hoh: 3_000,
    .mfs: 1_500,
]

/// Medical expense AGI floor for itemized deductions. Source: IRC §213(a).
public let MEDICAL_AGI_FLOOR_2024: Double = 0.075

/// SALT (state & local tax) deduction cap. Source: IRC §164(b)(6).
public struct SaltCap2024 {
    public let standard: Double
    public let mfs: Double
}
public let SALT_CAP_2024 = SaltCap2024(standard: 10_000, mfs: 5_000)

/// Charitable AGI limits. Source: IRC §170(b).
public struct CharitableLimits2024 {
    public let cashPctOfAgi: Double
    public let nonCashPctOfAgi: Double
}
public let CHARITABLE_LIMITS_2024 = CharitableLimits2024(
    cashPctOfAgi: 0.6,
    nonCashPctOfAgi: 0.3
)

/// Mortgage acquisition-debt limits for interest deductibility. Source: IRC §163(h)(3).
public struct MortgageDebtLimit2024 {
    /// Loans after 12/15/2017.
    public let postDec2017: Double
    public let postDec2017Mfs: Double
    /// Grandfathered loans on/before 12/15/2017.
    public let grandfathered: Double
    public let grandfatheredMfs: Double
}
public let MORTGAGE_DEBT_LIMIT_2024 = MortgageDebtLimit2024(
    postDec2017: 750_000,
    postDec2017Mfs: 375_000,
    grandfathered: 1_000_000,
    grandfatheredMfs: 500_000
)

/// A MAGI phaseout start/end range.
public struct PhaseoutRange: Equatable {
    public let start: Double
    public let end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}

/// Student loan interest deduction. Source: IRC §221; Rev. Proc. 2023-34 §2.21.
public struct StudentLoanInterest2024 {
    public let maxDeduction: Double
    public let phaseout: [FilingStatus: PhaseoutRange]
}
public let STUDENT_LOAN_INTEREST_2024 = StudentLoanInterest2024(
    maxDeduction: 2_500,
    phaseout: [
        .single: PhaseoutRange(start: 80_000, end: 95_000),
        .hoh: PhaseoutRange(start: 80_000, end: 95_000),
        .qss: PhaseoutRange(start: 80_000, end: 95_000),
        .mfj: PhaseoutRange(start: 165_000, end: 195_000),
        // MFS cannot claim the student loan interest deduction.
        .mfs: PhaseoutRange(start: 0, end: 0),
    ]
)

/// Educator expense above-the-line deduction. Source: IRC §62(a)(2)(D); Rev. Proc. 2023-34.
public struct EducatorExpense2024 {
    public let perEducator: Double
}
public let EDUCATOR_EXPENSE_2024 = EducatorExpense2024(perEducator: 300)

/// Additional tax on early retirement distributions. Source: IRC §72(t); Form 5329.
public struct EarlyWithdrawalPenalty2024 {
    public let rate: Double
    /// Box 7 codes that mean "early distribution, no known exception applies".
    public let earlyNoExceptionCodes: [String]
}
public let EARLY_WITHDRAWAL_PENALTY_2024 = EarlyWithdrawalPenalty2024(
    rate: 0.1,
    earlyNoExceptionCodes: ["1", "J", "S"]
)

// MARK: - socialSecurity2024.ts

public struct SsTaxability2024 {
    public let maxInclusionRate: Double
    public let firstTierRate: Double
}
public let SS_TAXABILITY_2024 = SsTaxability2024(
    maxInclusionRate: 0.85,
    firstTierRate: 0.5
)

/// Result of `ssBaseAmounts` — worksheet base amounts.
public struct SsBaseAmounts: Equatable {
    public let base1: Double
    public let base2: Double

    public init(base1: Double, base2: Double) {
        self.base1 = base1
        self.base2 = base2
    }
}

/**
 * Base amounts (worksheet lines 8 and 11):
 *  - base1: below this, no benefits are taxable.
 *  - base2: above this, the 85% tier applies.
 * MFS taxpayers who lived WITH their spouse use $0/$0 (almost always 85% taxable).
 */
public func ssBaseAmounts(
    _ status: FilingStatus,
    _ livedApartFromSpouse: Bool
) -> SsBaseAmounts {
    if status == .mfj { return SsBaseAmounts(base1: 32_000, base2: 44_000) }
    if status == .mfs && !livedApartFromSpouse { return SsBaseAmounts(base1: 0, base2: 0) }
    // single, hoh, qss, and mfs-who-lived-apart-all-year
    return SsBaseAmounts(base1: 25_000, base2: 34_000)
}

// MARK: - retirement2024.ts

/// Traditional IRA contribution limits and deduction phaseouts.
public struct Ira2024 {
    public let contributionLimit: Double
    /// Age 50+ catch-up brings the limit to $8,000.
    public let contributionLimitAge50: Double
    /// MAGI phaseout ranges.
    public let phaseout: Ira2024Phaseout
    /// Special floor: a non-zero phased-out deduction is at least $200, rounded up to $10.
    public let minPhasedDeduction: Double
    public let roundUpTo: Double
}

public struct Ira2024Phaseout {
    public let coveredSingleHoh: PhaseoutRange
    public let coveredMfj: PhaseoutRange
    /// Contributor NOT covered, but spouse IS covered (MFJ).
    public let spouseCoveredMfj: PhaseoutRange
    public let coveredMfs: PhaseoutRange
}

public let IRA_2024 = Ira2024(
    contributionLimit: 7_000,
    contributionLimitAge50: 8_000,
    phaseout: Ira2024Phaseout(
        coveredSingleHoh: PhaseoutRange(start: 77_000, end: 87_000),
        coveredMfj: PhaseoutRange(start: 123_000, end: 143_000),
        spouseCoveredMfj: PhaseoutRange(start: 230_000, end: 240_000),
        coveredMfs: PhaseoutRange(start: 0, end: 10_000)
    ),
    minPhasedDeduction: 200,
    roundUpTo: 10
)

/// HSA contribution limits (Form 8889).
public struct Hsa2024 {
    public let selfOnly: Double
    public let family: Double
    /// Age 55+ catch-up.
    public let catchUp: Double
    public let catchUpAge: Double
}
public let HSA_2024 = Hsa2024(
    selfOnly: 4_150,
    family: 8_300,
    catchUp: 1_000,
    catchUpAge: 55
)

// MARK: - eitc2024.ts

/// One EITC bracket (piecewise-linear phase-in / plateau / phase-out).
public struct EitcBracket: Equatable {
    /// Earned income at which the maximum credit is reached (phase-in ceiling).
    public let earnedIncomeAmount: Double
    public let maxCredit: Double
    public let phaseInRate: Double
    public let phaseoutRate: Double
    /// Phase-out start (AGI/earned income) for non-MFJ filers.
    public let phaseoutThreshold: Double
    /// Phase-out start for MFJ filers.
    public let phaseoutThresholdMfj: Double

    public init(
        earnedIncomeAmount: Double,
        maxCredit: Double,
        phaseInRate: Double,
        phaseoutRate: Double,
        phaseoutThreshold: Double,
        phaseoutThresholdMfj: Double
    ) {
        self.earnedIncomeAmount = earnedIncomeAmount
        self.maxCredit = maxCredit
        self.phaseInRate = phaseInRate
        self.phaseoutRate = phaseoutRate
        self.phaseoutThreshold = phaseoutThreshold
        self.phaseoutThresholdMfj = phaseoutThresholdMfj
    }
}

/// Indexed by number of qualifying children (0, 1, 2, 3 = "3 or more").
public let EITC_2024: [EitcBracket] = [
    EitcBracket(
        earnedIncomeAmount: 8_260,
        maxCredit: 632,
        phaseInRate: 0.0765,
        phaseoutRate: 0.0765,
        phaseoutThreshold: 10_330,
        phaseoutThresholdMfj: 17_250
    ),
    EitcBracket(
        earnedIncomeAmount: 12_390,
        maxCredit: 4_213,
        phaseInRate: 0.34,
        phaseoutRate: 0.1598,
        phaseoutThreshold: 22_720,
        phaseoutThresholdMfj: 29_640
    ),
    EitcBracket(
        earnedIncomeAmount: 17_400,
        maxCredit: 6_960,
        phaseInRate: 0.4,
        phaseoutRate: 0.2106,
        phaseoutThreshold: 22_720,
        phaseoutThresholdMfj: 29_640
    ),
    EitcBracket(
        earnedIncomeAmount: 17_400,
        maxCredit: 7_830,
        phaseInRate: 0.45,
        phaseoutRate: 0.2106,
        phaseoutThreshold: 22_720,
        phaseoutThresholdMfj: 29_640
    ),
]

/// Disqualifying investment income limit (2024).
public let EITC_INVESTMENT_INCOME_LIMIT_2024: Double = 11_600

/// Age bounds for the childless EITC (at least 25, under 65).
public struct EitcChildlessAge {
    public let min: Double
    public let maxExclusive: Double
}
public let EITC_CHILDLESS_AGE = EitcChildlessAge(min: 25, maxExclusive: 65)

// MARK: - qbi2024.ts

public struct Qbi2024 {
    public let rate: Double
    /// Taxable-income threshold where the SSTB/W-2 limitations begin to phase in.
    public let threshold: [FilingStatus: Double]
    /// Phase-in range above the threshold (fully limited at threshold + range).
    public let phaseInRange: [FilingStatus: Double]
}
public let QBI_2024 = Qbi2024(
    rate: 0.2,
    threshold: [
        .single: 191_950,
        .hoh: 191_950,
        .mfs: 191_950,
        .qss: 191_950,
        .mfj: 383_900,
    ],
    phaseInRange: [
        .single: 50_000,
        .hoh: 50_000,
        .mfs: 50_000,
        .qss: 50_000,
        .mfj: 100_000,
    ]
)

// MARK: - amt2024.ts

/// Alternative Minimum Tax — 2024 (Form 6251). Source: Rev. Proc. 2023-34 §2.11; IRC §55.
public struct Amt2024 {
    public let exemption: [FilingStatus: Double]
    /// Exemption phases out at 25¢ per $1 of AMTI over this threshold.
    public let exemptionPhaseoutThreshold: [FilingStatus: Double]
    public let exemptionPhaseoutRate: Double
    /// AMT is 26% up to this AMT base, 28% above (halved for MFS).
    public let rate28Threshold: Double
    public let rate28ThresholdMfs: Double
    public let lowRate: Double
    public let highRate: Double
}
public let AMT_2024 = Amt2024(
    exemption: [
        .single: 85_700,
        .hoh: 85_700,
        .mfj: 133_300,
        .qss: 133_300,
        .mfs: 66_650,
    ],
    exemptionPhaseoutThreshold: [
        .single: 609_350,
        .hoh: 609_350,
        .mfs: 609_350,
        .mfj: 1_218_700,
        .qss: 1_218_700,
    ],
    exemptionPhaseoutRate: 0.25,
    rate28Threshold: 232_600,
    rate28ThresholdMfs: 116_300,
    lowRate: 0.26,
    highRate: 0.28
)

// MARK: - credits2024.ts

/// Child & Dependent Care Credit (Form 2441) — not inflation-indexed.
public struct CareCredit2024 {
    public let expenseCapOnePerson: Double
    public let expenseCapTwoPlus: Double
    public let maxRate: Double
    public let minRate: Double
    /// AGI at/below which the 35% rate applies.
    public let fullRateAgiCeiling: Double
    /// Rate drops 1% per $2,000 of AGI over the ceiling, to a 20% floor.
    public let rateStepIncome: Double
    public let rateStep: Double
}
public let CARE_CREDIT_2024 = CareCredit2024(
    expenseCapOnePerson: 3_000,
    expenseCapTwoPlus: 6_000,
    maxRate: 0.35,
    minRate: 0.2,
    fullRateAgiCeiling: 15_000,
    rateStepIncome: 2_000,
    rateStep: 0.01
)

/// AOTC sub-config of EDUCATION_CREDITS_2024.
public struct EducationCreditsAotc {
    /// 100% of the first $2,000 + 25% of the next $2,000 = $2,500 max.
    public let firstTier: Double
    public let secondTier: Double
    public let secondTierRate: Double
    public let max: Double
    public let refundablePortion: Double
    public let maxPriorYears: Double
}

/// LLC sub-config of EDUCATION_CREDITS_2024.
public struct EducationCreditsLlc {
    /// 20% of up to $10,000 of expenses (aggregate), max $2,000.
    public let rate: Double
    public let expenseCap: Double
    public let max: Double
}

/// Education credits (Form 8863).
public struct EducationCredits2024 {
    public let aotc: EducationCreditsAotc
    public let llc: EducationCreditsLlc
    /// MAGI phaseout (same range for AOTC and LLC in 2024).
    public let phaseout: [FilingStatus: PhaseoutRange]
}
public let EDUCATION_CREDITS_2024 = EducationCredits2024(
    aotc: EducationCreditsAotc(
        firstTier: 2_000,
        secondTier: 2_000,
        secondTierRate: 0.25,
        max: 2_500,
        refundablePortion: 0.4,
        maxPriorYears: 4
    ),
    llc: EducationCreditsLlc(
        rate: 0.2,
        expenseCap: 10_000,
        max: 2_000
    ),
    phaseout: [
        .single: PhaseoutRange(start: 80_000, end: 90_000),
        .hoh: PhaseoutRange(start: 80_000, end: 90_000),
        .qss: PhaseoutRange(start: 80_000, end: 90_000),
        .mfj: PhaseoutRange(start: 160_000, end: 180_000),
        .mfs: PhaseoutRange(start: 0, end: 0), // MFS cannot claim education credits
    ]
)

/// One Saver's Credit rate tier.
public struct SaversCreditTier: Equatable {
    public let rate: Double
    public let agiCeiling: Double

    public init(rate: Double, agiCeiling: Double) {
        self.rate = rate
        self.agiCeiling = agiCeiling
    }
}

/// Retirement Savings Contributions Credit (Saver's Credit, Form 8880).
public struct SaversCredit2024 {
    public let contributionCap: Double // per person; $4,000 combined for MFJ
    /// AGI ceilings for the 50% / 20% / 10% rate tiers (above the last → 0%).
    public let tiers: [FilingStatus: [SaversCreditTier]]
}
public let SAVERS_CREDIT_2024 = SaversCredit2024(
    contributionCap: 2_000,
    tiers: [
        .single: [
            SaversCreditTier(rate: 0.5, agiCeiling: 23_000),
            SaversCreditTier(rate: 0.2, agiCeiling: 25_000),
            SaversCreditTier(rate: 0.1, agiCeiling: 38_250),
        ],
        .mfs: [
            SaversCreditTier(rate: 0.5, agiCeiling: 23_000),
            SaversCreditTier(rate: 0.2, agiCeiling: 25_000),
            SaversCreditTier(rate: 0.1, agiCeiling: 38_250),
        ],
        .qss: [
            SaversCreditTier(rate: 0.5, agiCeiling: 23_000),
            SaversCreditTier(rate: 0.2, agiCeiling: 25_000),
            SaversCreditTier(rate: 0.1, agiCeiling: 38_250),
        ],
        .hoh: [
            SaversCreditTier(rate: 0.5, agiCeiling: 34_500),
            SaversCreditTier(rate: 0.2, agiCeiling: 37_500),
            SaversCreditTier(rate: 0.1, agiCeiling: 57_375),
        ],
        .mfj: [
            SaversCreditTier(rate: 0.5, agiCeiling: 46_000),
            SaversCreditTier(rate: 0.2, agiCeiling: 50_000),
            SaversCreditTier(rate: 0.1, agiCeiling: 76_500),
        ],
    ]
)

/// Residential Clean Energy Credit (Form 5695) — 30% of qualified property cost.
public struct CleanEnergy2024 {
    public let rate: Double
}
public let CLEAN_ENERGY_2024 = CleanEnergy2024(rate: 0.3)

/// New Clean Vehicle Credit (Form 8936).
public struct EvCredit2024 {
    public let max: Double
    public let magiCap: [FilingStatus: Double]
}
public let EV_CREDIT_2024 = EvCredit2024(
    max: 7_500,
    magiCap: [
        .single: 150_000,
        .hoh: 225_000,
        .mfs: 150_000,
        .qss: 150_000,
        .mfj: 300_000,
    ]
)
