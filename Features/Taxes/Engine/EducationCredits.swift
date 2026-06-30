/**
 * Education credits — Form 8863.
 *
 * AOTC: 100% of the first $2,000 + 25% of the next $2,000 (max $2,500) per
 * eligible student, 40% refundable. Lifetime Learning Credit: 20% of up to
 * $10,000 of expenses (aggregate, max $2,000), nonrefundable. Both phase out by
 * MAGI; MFS cannot claim either. A student claimed for AOTC isn't also counted
 * for LLC.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/educationCredits.ts.
 * Foundation-only — no SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the
 * TypeScript: same exported names, same constants, same formulas, same rounding,
 * same conditionals and order of operations. TS `number` -> Swift `Double`.
 */

import Foundation

public struct EducationResult: Equatable {
    public var nonrefundable: Double
    public var refundable: Double

    public init(nonrefundable: Double, refundable: Double) {
        self.nonrefundable = nonrefundable
        self.refundable = refundable
    }
}

public func computeEducationCredits(_ r: TaxReturn2024, _ magi: Double) -> EducationResult {
    if !r.credits.hasEducationExpenses || r.filingStatus == .mfs {
        return EducationResult(nonrefundable: 0, refundable: 0)
    }

    let phase = EDUCATION_CREDITS_2024.phaseout[r.filingStatus]!
    let factor =
        magi <= phase.start ? 1 : (magi >= phase.end ? 0 : (phase.end - magi) / (phase.end - phase.start))
    if factor <= 0 { return EducationResult(nonrefundable: 0, refundable: 0) }

    let a = EDUCATION_CREDITS_2024.aotc
    var aotc: Double = 0
    var llcExpenses: Double = 0
    for s in r.credits.students {
        let aotcEligible = s.aotcEligible && s.priorAotcYears < a.maxPriorYears && !s.felonyDrugConviction
        if aotcEligible {
            let first = Swift.min(s.qualifiedExpenses, a.firstTier)
            let second = Swift.min(Swift.max(0, s.qualifiedExpenses - first), a.secondTier) * a.secondTierRate
            aotc += Swift.min(first + second, a.max)
        } else {
            llcExpenses += Swift.max(0, s.qualifiedExpenses)
        }
    }

    let llc = Swift.min(
        Swift.min(llcExpenses, EDUCATION_CREDITS_2024.llc.expenseCap) * EDUCATION_CREDITS_2024.llc.rate,
        EDUCATION_CREDITS_2024.llc.max
    )

    let aotcAfter = aotc * factor
    let llcAfter = llc * factor

    let refundable = dollar(aotcAfter * a.refundablePortion)
    let nonrefundable = dollar(aotcAfter * (1 - a.refundablePortion) + llcAfter)
    return EducationResult(nonrefundable: nonrefundable, refundable: refundable)
}
