/**
 * Qualified Business Income deduction — §199A (Forms 8995 / 8995-A).
 *
 * Below the taxable-income threshold: simply 20% of QBI, capped at 20% of
 * (taxable income − net capital gain). Above the threshold an SSTB is phased out
 * over the next $50k ($100k MFJ); for a non-SSTB the W-2 wage / UBIA limit
 * applies — we don't track business W-2 wages, so the orchestrator flags this for
 * high earners rather than silently over-deducting.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/qbi.ts. Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same formulas,
 * same conditionals and order of operations. TS `number` -> Swift `Double`,
 * TS exported functions -> Swift top-level functions, TS interfaces -> structs.
 */
import Foundation

public struct QbiResult: Equatable {
    public var deduction: Double
    /// True when a non-SSTB filer is over the threshold and the (untracked) W-2/UBIA limit could reduce the deduction.
    public var wageLimitMayApply: Bool

    public init(deduction: Double, wageLimitMayApply: Bool) {
        self.deduction = deduction
        self.wageLimitMayApply = wageLimitMayApply
    }
}

/// Parameters for `computeQbiDeduction`. TS: inline object literal parameter.
public struct ComputeQbiDeductionParams {
    public var qbiIncome: Double
    public var taxableIncomeBeforeQbi: Double
    public var netCapitalGain: Double
    public var isSSTB: Bool
    public var status: FilingStatus

    public init(
        qbiIncome: Double,
        taxableIncomeBeforeQbi: Double,
        netCapitalGain: Double,
        isSSTB: Bool,
        status: FilingStatus
    ) {
        self.qbiIncome = qbiIncome
        self.taxableIncomeBeforeQbi = taxableIncomeBeforeQbi
        self.netCapitalGain = netCapitalGain
        self.isSSTB = isSSTB
        self.status = status
    }
}

public func computeQbiDeduction(_ params: ComputeQbiDeductionParams) -> QbiResult {
    let qbiIncome = params.qbiIncome
    let taxableIncomeBeforeQbi = params.taxableIncomeBeforeQbi
    let netCapitalGain = params.netCapitalGain
    let isSSTB = params.isSSTB
    let status = params.status

    if qbiIncome <= 0 { return QbiResult(deduction: 0, wageLimitMayApply: false) }

    let overallLimit = QBI_2024.rate * Swift.max(0, taxableIncomeBeforeQbi - netCapitalGain)
    let threshold = QBI_2024.threshold[status]!
    let range = QBI_2024.phaseInRange[status]!

    // Below threshold: simple 20%, capped by the overall taxable-income limit.
    if taxableIncomeBeforeQbi <= threshold {
        return QbiResult(
            deduction: Swift.min(QBI_2024.rate * qbiIncome, overallLimit),
            wageLimitMayApply: false
        )
    }

    let over = taxableIncomeBeforeQbi - threshold

    if isSSTB {
        // Fully phased out at threshold + range.
        if over >= range { return QbiResult(deduction: 0, wageLimitMayApply: false) }
        let applicablePct = 1 - over / range
        let deduction = Swift.min(QBI_2024.rate * qbiIncome * applicablePct, overallLimit)
        return QbiResult(deduction: deduction, wageLimitMayApply: false)
    }

    // Non-SSTB above threshold: the W-2/UBIA limit governs but isn't tracked here.
    return QbiResult(
        deduction: Swift.min(QBI_2024.rate * qbiIncome, overallLimit),
        wageLimitMayApply: true
    )
}
