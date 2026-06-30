/**
 * Additional Medicare Tax — 0.9% on Medicare wages + SE earnings over the
 * filing-status threshold (Form 8959). The threshold is applied to wages first,
 * then the remainder to self-employment earnings.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/additionalMedicare.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported name,
 * same constants, same formulas, same order of operations. TS `number` ->
 * Swift `Double`.
 */

import Foundation

public func computeAdditionalMedicareTax(
    _ medicareWages: Double,
    _ seNetEarnings: Double,
    _ status: FilingStatus
) -> Double {
    let threshold = ADDITIONAL_MEDICARE_2024.thresholds[status]!
    let rate = ADDITIONAL_MEDICARE_2024.rate
    let onWages = Swift.max(0, medicareWages - threshold) * rate
    let remainingThreshold = Swift.max(0, threshold - medicareWages)
    let onSe = Swift.max(0, Swift.max(0, seNetEarnings) - remainingThreshold) * rate
    return onWages + onSe
}
