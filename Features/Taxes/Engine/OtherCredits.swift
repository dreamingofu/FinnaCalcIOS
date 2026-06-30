/**
 * OtherCredits.swift
 *
 * Smaller nonrefundable credits: Saver's Credit (8880), Residential Clean Energy
 * (5695), Clean Vehicle (8936), and Foreign Tax Credit (1116, simplified to the
 * direct credit). Each is limited to remaining tax by the orchestrator.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/otherCredits.ts.
 * Foundation-only — no SwiftUI/UIKit/Combine.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same constants,
 * same formulas, same rounding, same conditionals and order of operations.
 * TS `number` -> Swift `Double`.
 */

import Foundation

/// Retirement Savings Contributions Credit (Form 8880).
public func computeSaversCredit(_ r: TaxReturn2024, _ agi: Double) -> Double {
    if r.credits.isFullTimeStudent || r.taxpayer.claimedAsDependentByAnother { return 0 }
    let contribution = Swift.max(0, r.credits.retirementContributions)
    if contribution <= 0 { return 0 }

    let perPersonCap = SAVERS_CREDIT_2024.contributionCap
    let cap = r.filingStatus == .mfj ? perPersonCap * 2 : perPersonCap
    let eligible = Swift.min(contribution, cap)

    var rate: Double = 0
    for tier in SAVERS_CREDIT_2024.tiers[r.filingStatus] ?? [] {
        if agi <= tier.agiCeiling {
            rate = tier.rate
            break
        }
    }
    return dollar(eligible * rate)
}

/// Residential Clean Energy Credit (Form 5695) — 30% of qualified property cost.
public func computeCleanEnergyCredit(_ r: TaxReturn2024) -> Double {
    return dollar(Swift.max(0, r.credits.cleanEnergyCost) * CLEAN_ENERGY_2024.rate)
}

/// New Clean Vehicle Credit (Form 8936) — up to $7,500, subject to MAGI caps.
public func computeEvCredit(_ r: TaxReturn2024, _ magi: Double) -> Double {
    if magi > (EV_CREDIT_2024.magiCap[r.filingStatus] ?? 0) { return 0 }
    return Swift.min(Swift.max(0, r.credits.evCreditAmount), EV_CREDIT_2024.max)
}

/// Foreign Tax Credit (Form 1116) — simplified to the foreign tax paid.
public func computeForeignTaxCredit(_ r: TaxReturn2024) -> Double {
    return Swift.max(0, r.credits.foreignTaxPaid)
}
