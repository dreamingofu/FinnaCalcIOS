/**
 * Child Tax Credit, Credit for Other Dependents, and the refundable Additional
 * Child Tax Credit — Schedule 8812 (2024).
 *
 * Flow:
 *  1. Tentative credit = $2,000 × qualifying children + $500 × other dependents.
 *  2. MAGI phaseout: −$50 per $1,000 (or fraction) over the threshold.
 *  3. Nonrefundable part = min(credit after phaseout, tax available).
 *  4. ACTC (refundable) = min(leftover credit, $1,700 × qualifying children,
 *     15% × (earned income − $2,500)). ODC is never refundable.
 *
 * The 3-or-more-children Social-Security-tax alternative for ACTC is added in
 * Phase 3; the 15% earned-income method governs the common case.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/childTaxCredit.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding. TS `number` -> Swift `Double`.
 */
import Foundation

public struct ChildTaxCreditResult: Equatable {
    public var qualifyingChildren: Double
    public var otherDependents: Double
    public var tentativeCredit: Double
    public var creditAfterPhaseout: Double
    /// Nonrefundable CTC/ODC actually applied against tax.
    public var nonrefundable: Double
    /// Refundable Additional Child Tax Credit.
    public var additionalChildTaxCredit: Double

    public init(
        qualifyingChildren: Double,
        otherDependents: Double,
        tentativeCredit: Double,
        creditAfterPhaseout: Double,
        nonrefundable: Double,
        additionalChildTaxCredit: Double
    ) {
        self.qualifyingChildren = qualifyingChildren
        self.otherDependents = otherDependents
        self.tentativeCredit = tentativeCredit
        self.creditAfterPhaseout = creditAfterPhaseout
        self.nonrefundable = nonrefundable
        self.additionalChildTaxCredit = additionalChildTaxCredit
    }
}

public func computeChildTaxCredit(
    _ r: TaxReturn2024,
    _ magi: Double,
    _ taxAvailable: Double,
    _ earnedIncome: Double
) -> ChildTaxCreditResult {
    let qualifyingChildren = Double(r.dependents.filter { $0.qualifiesForCTC }.count)
    let otherDependents = Double(r.dependents.filter { $0.qualifiesForODC }.count)

    let tentativeCredit =
        qualifyingChildren * CTC_2024.perChild + otherDependents * CTC_2024.perOtherDependent

    // MAGI phaseout — excess rounded UP to the next $1,000 before applying $50.
    let threshold = CTC_PHASEOUT_THRESHOLD_2024[r.filingStatus]!
    var creditAfterPhaseout = tentativeCredit
    if magi > threshold {
        let steps = Foundation.ceil((magi - threshold) / CTC_2024.phaseoutIncrement)
        creditAfterPhaseout = nonNeg(tentativeCredit - steps * CTC_2024.phaseoutPer1000)
    }

    // Nonrefundable part limited to tax available.
    let nonrefundable = Swift.min(creditAfterPhaseout, nonNeg(taxAvailable))

    // Refundable ACTC on the leftover (qualifying children only).
    let leftover = nonNeg(creditAfterPhaseout - nonrefundable)
    let refundableCap = qualifyingChildren * CTC_2024.refundableCapPerChild
    let earnedFormula = nonNeg(
        (earnedIncome - CTC_2024.earnedIncomeThreshold) * CTC_2024.earnedIncomeRate
    )
    let additionalChildTaxCredit = Swift.min(leftover, Swift.min(refundableCap, earnedFormula))

    return ChildTaxCreditResult(
        qualifyingChildren: qualifyingChildren,
        otherDependents: otherDependents,
        tentativeCredit: tentativeCredit,
        creditAfterPhaseout: creditAfterPhaseout,
        nonrefundable: nonrefundable,
        additionalChildTaxCredit: additionalChildTaxCredit
    )
}
