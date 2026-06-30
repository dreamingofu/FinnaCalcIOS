/**
 * Niit.swift
 *
 * Net Investment Income Tax — 3.8% on the lesser of net investment income or the
 * amount of MAGI over the filing-status threshold (Form 8960).
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/niit.ts. Foundation-only —
 * no SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the TypeScript: same exported
 * name, same formula, same constants. TS `number` -> Swift `Double`.
 */

import Foundation

public func computeNiit(
    _ netInvestmentIncome: Double,
    _ magi: Double,
    _ status: FilingStatus
) -> Double {
    let threshold = NIIT_2024.thresholds[status]!
    let base = Swift.min(Swift.max(0, netInvestmentIncome), Swift.max(0, magi - threshold))
    return base * NIIT_2024.rate
}
