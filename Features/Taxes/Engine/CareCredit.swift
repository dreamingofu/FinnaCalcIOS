/**
 * CareCredit.swift
 *
 * Child & Dependent Care Credit — Form 2441 (nonrefundable).
 *
 * Eligible expenses are limited to $3,000 (one qualifying person) or $6,000 (two
 * or more), reduced by any employer dependent-care benefits, and capped at the
 * taxpayer's (and spouse's, if MFJ) earned income. The credit rate runs from 35%
 * (AGI ≤ $15,000) down to 20% (AGI > $43,000). MFS who lived with their spouse
 * cannot claim it.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/careCredit.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported name,
 * same constants, same formulas, same rounding, same conditionals and order of
 * operations. TS `number` -> Swift `Double`.
 */

import Foundation

public func computeCareCredit(_ r: TaxReturn2024, _ agi: Double) -> Double {
    if !r.credits.hasCareExpenses { return 0 }
    if r.filingStatus == .mfs && !r.livedApartFromSpouse { return 0 }

    let qualifyingPersons = r.dependents.filter { $0.qualifiesForCareCredit }.count
    if qualifyingPersons == 0 { return 0 }

    let cap =
        qualifyingPersons == 1
            ? CARE_CREDIT_2024.expenseCapOnePerson
            : CARE_CREDIT_2024.expenseCapTwoPlus
    let care = r.credits.care
    let effectiveCap = Swift.max(0, cap - Swift.max(0, care.employerBenefits))

    let earnedLimit =
        r.filingStatus == .mfj
            ? Swift.min(care.taxpayerEarnedIncome, care.spouseEarnedIncome)
            : care.taxpayerEarnedIncome

    let eligible = Swift.min(Swift.min(Swift.max(0, care.expenses), effectiveCap), earnedLimit)
    if eligible <= 0 { return 0 }

    var rate: Double = CARE_CREDIT_2024.maxRate
    if agi > CARE_CREDIT_2024.fullRateAgiCeiling {
        let steps = Foundation.ceil(
            (agi - CARE_CREDIT_2024.fullRateAgiCeiling) / CARE_CREDIT_2024.rateStepIncome
        )
        rate = Swift.max(CARE_CREDIT_2024.minRate, CARE_CREDIT_2024.maxRate - steps * CARE_CREDIT_2024.rateStep)
    }

    return dollar(eligible * rate)
}
