/**
 * Earned Income Tax Credit — Schedule EIC (refundable).
 *
 * The credit is figured from BOTH earned income and AGI; if AGI exceeds the
 * phase-out threshold, the smaller of the two results is used. Disqualifiers:
 * investment income over $11,600; MFS who did not live apart from their spouse;
 * and (childless only) being outside the 25–64 age band.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/eitc.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding, same conditionals and order of
 * operations. TS `number` -> Swift `Double`, TS optional -> Swift `Optional`.
 */

import Foundation

/// Credit amount at a given income level for a bracket (piecewise-linear formula).
private func eitcAtIncome(_ income: Double, _ bracketIndex: Int, _ status: FilingStatus) -> Double {
    if income <= 0 { return 0 }
    let b = EITC_2024[bracketIndex]
    let threshold = status == .mfj ? b.phaseoutThresholdMfj : b.phaseoutThreshold
    let phaseIn = Swift.min(b.maxCredit, b.phaseInRate * income)
    if income <= threshold { return phaseIn }
    return Swift.max(0, b.maxCredit - b.phaseoutRate * (income - threshold))
}

public struct EitcResult: Equatable {
    public var credit: Double
    public var eligible: Bool
    public var disqualReason: String?

    public init(credit: Double, eligible: Bool, disqualReason: String? = nil) {
        self.credit = credit
        self.eligible = eligible
        self.disqualReason = disqualReason
    }
}

/// Parameters for `computeEitc`. Mirrors the TS inline object literal.
public struct ComputeEitcParams {
    public var r: TaxReturn2024
    public var earnedIncome: Double
    public var agi: Double
    public var investmentIncome: Double
    public var taxpayerAge: Double?

    public init(
        r: TaxReturn2024,
        earnedIncome: Double,
        agi: Double,
        investmentIncome: Double,
        taxpayerAge: Double? = nil
    ) {
        self.r = r
        self.earnedIncome = earnedIncome
        self.agi = agi
        self.investmentIncome = investmentIncome
        self.taxpayerAge = taxpayerAge
    }
}

public func computeEitc(_ params: ComputeEitcParams) -> EitcResult {
    let r = params.r
    let earnedIncome = params.earnedIncome
    let agi = params.agi
    let investmentIncome = params.investmentIncome
    let taxpayerAge = params.taxpayerAge
    let status = r.filingStatus

    // MFS is eligible only if the taxpayer lived apart from their spouse.
    if status == .mfs && !r.livedApartFromSpouse {
        return EitcResult(credit: 0, eligible: false, disqualReason: "MFS filers must have lived apart from their spouse.")
    }
    if investmentIncome > EITC_INVESTMENT_INCOME_LIMIT_2024 {
        return EitcResult(
            credit: 0,
            eligible: false,
            disqualReason: "Investment income over $\(eitcLocaleString(EITC_INVESTMENT_INCOME_LIMIT_2024)) disqualifies the EITC."
        )
    }
    if earnedIncome <= 0 { return EitcResult(credit: 0, eligible: false) }

    let qualifyingChildren = r.dependents.filter { $0.qualifiesForEITC }.count
    let bracketIndex = Swift.min(qualifyingChildren, 3)

    // Childless filers must be 25–64; only enforced when age is known.
    if bracketIndex == 0,
       let taxpayerAge = taxpayerAge,
       (taxpayerAge < EITC_CHILDLESS_AGE.min || taxpayerAge >= EITC_CHILDLESS_AGE.maxExclusive) {
        return EitcResult(credit: 0, eligible: false, disqualReason: "Childless EITC requires age 25–64.")
    }

    let threshold = status == .mfj
        ? EITC_2024[bracketIndex].phaseoutThresholdMfj
        : EITC_2024[bracketIndex].phaseoutThreshold

    let byEarned = eitcAtIncome(earnedIncome, bracketIndex, status)
    let credit = agi <= threshold ? byEarned : Swift.min(byEarned, eitcAtIncome(agi, bracketIndex, status))

    return EitcResult(credit: dollar(credit), eligible: credit > 0)
}

/// Mirrors JS `Number.toLocaleString()` for the integer-valued constants used
/// in the EITC disqualification message (e.g. `11600` -> `"11,600"`).
private func eitcLocaleString(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = 3
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
}
