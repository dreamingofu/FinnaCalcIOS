/**
 * Adjustments.swift
 *
 * Above-the-line adjustments (Schedule 1 Part II) → reduce income to AGI.
 *
 * Some adjustments are "fixed" (independent of AGI): educator, HSA, SE-tax 50%
 * deduction, self-employed health insurance, and SEP/SIMPLE. Two are MAGI-
 * dependent and therefore resolved inside the orchestrator's fixed-point loop
 * (because their MAGI includes taxable Social Security): the traditional IRA
 * deduction and the student loan interest deduction.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/adjustments.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding, same conditionals and order of
 * operations. TS `number` -> Swift `Double`.
 */

import Foundation

// MARK: - JS Date helpers (private)

/// Parse a date string the way JS `new Date(s)` does for the inputs used here
/// (ISO date-only "YYYY-MM-DD" strings → UTC midnight). Returns the epoch
/// milliseconds, or `nil` when the string is empty/unparseable (mirrors a JS
/// `Date` whose `getTime()` is `NaN`).
private func jsParseDateMs(_ s: String) -> Double? {
    if s.isEmpty { return nil }
    let formatter = ISO8601DateFormatter()
    // ISO date-only ("YYYY-MM-DD"): JS treats these as UTC midnight.
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.formatOptions = [.withFullDate]
    if let d = formatter.date(from: s) {
        return d.timeIntervalSince1970 * 1000
    }
    // Fall back to full ISO date-time forms (e.g. "1969-12-31T00:00:00Z").
    let dtFormatter = ISO8601DateFormatter()
    dtFormatter.timeZone = TimeZone(identifier: "UTC")
    dtFormatter.formatOptions = [.withInternetDateTime]
    if let d = dtFormatter.date(from: s) {
        return d.timeIntervalSince1970 * 1000
    }
    return nil
}

/// Epoch milliseconds for an ISO date-time literal that is known to be valid
/// (used for the fixed cutoff dates below). Mirrors `new Date(...).getTime()`.
private func jsDateMs(_ s: String) -> Double {
    return jsParseDateMs(s) ?? 0
}

/// Age 55+ at end of 2024 (HSA catch-up) → born on/before 1969-12-31.
private func isAge55For2024(_ dateOfBirth: String) -> Bool {
    if dateOfBirth.isEmpty { return false }
    guard let dob = jsParseDateMs(dateOfBirth) else { return false }
    return dob <= jsDateMs("1969-12-31T00:00:00Z")
}

/// Age 50+ at end of 2024 (IRA catch-up) → born on/before 1974-12-31.
public func isAge50For2024(_ dateOfBirth: String) -> Bool {
    if dateOfBirth.isEmpty { return false }
    guard let dob = jsParseDateMs(dateOfBirth) else { return false }
    return dob <= jsDateMs("1974-12-31T00:00:00Z")
}

// MARK: - Adjustments

/// Educator expense — capped at $300 (per-educator); MFJ-both is Phase-later.
public func educatorDeduction(_ r: TaxReturn2024) -> Double {
    return Swift.min(
        Swift.max(0, r.adjustments.educatorExpenses),
        EDUCATOR_EXPENSE_2024.perEducator
    )
}

/// HSA deduction (Form 8889) — capped by the coverage limit plus 55+ catch-up.
public func hsaDeduction(_ r: TaxReturn2024) -> Double {
    let cov = r.adjustments.hsaCoverage
    if cov == .none { return 0 }
    var limit = cov == .family ? HSA_2024.family : HSA_2024.selfOnly
    if isAge55For2024(r.taxpayer.dateOfBirth) { limit += HSA_2024.catchUp }
    return Swift.min(Swift.max(0, r.adjustments.hsaContribution), limit)
}

/// Self-employed health insurance — limited to available net SE profit.
public func seHealthDeduction(
    _ r: TaxReturn2024,
    _ totalNetSe: Double,
    _ seTaxDeduction: Double,
    _ sepContribution: Double
) -> Double {
    let ceiling = Swift.max(0, totalNetSe - seTaxDeduction - Swift.max(0, sepContribution))
    return Swift.min(Swift.max(0, r.adjustments.selfEmployedHealthInsurance), ceiling)
}

/**
 * Traditional IRA deduction with the 2024 MAGI phaseout. Only phases out if the
 * contributor is an active workplace-plan participant (or, for MFJ, the spouse is).
 * A non-zero phased deduction is rounded UP to $10 and floored at $200.
 */
public func iraDeduction(
    _ contribution: Double,
    _ magi: Double,
    _ status: FilingStatus,
    _ coveredByPlan: Bool,
    _ spouseCoveredByPlan: Bool,
    _ age50: Bool
) -> Double {
    let limit = age50 ? IRA_2024.contributionLimitAge50 : IRA_2024.contributionLimit
    let eligible = Swift.min(Swift.max(0, contribution), limit)
    if eligible <= 0 { return 0 }

    var range: PhaseoutRange? = nil
    if coveredByPlan {
        if status == .mfj || status == .qss { range = IRA_2024.phaseout.coveredMfj }
        else if status == .mfs { range = IRA_2024.phaseout.coveredMfs }
        else { range = IRA_2024.phaseout.coveredSingleHoh }
    } else if (status == .mfj || status == .qss) && spouseCoveredByPlan {
        range = IRA_2024.phaseout.spouseCoveredMfj
    } else if status == .mfs && spouseCoveredByPlan {
        range = IRA_2024.phaseout.coveredMfs
    }

    // No coverage that triggers a phaseout → fully deductible.
    guard let range = range else { return eligible }

    if magi <= range.start { return eligible }
    if magi >= range.end { return 0 }

    let ratio = (range.end - magi) / (range.end - range.start)
    var deduction = eligible * ratio
    deduction = Foundation.ceil(deduction / IRA_2024.roundUpTo) * IRA_2024.roundUpTo
    if deduction > 0 && deduction < IRA_2024.minPhasedDeduction {
        deduction = IRA_2024.minPhasedDeduction
    }
    return Swift.min(deduction, eligible)
}

/// Student loan interest deduction with the 2024 MAGI phaseout (MFS ineligible).
public func studentLoanInterestDeduction(
    _ paid: Double,
    _ magi: Double,
    _ status: FilingStatus
) -> Double {
    if status == .mfs { return 0 }
    let eligible = Swift.min(
        Swift.max(0, paid),
        STUDENT_LOAN_INTEREST_2024.maxDeduction
    )
    if eligible <= 0 { return 0 }
    guard let phaseout = STUDENT_LOAN_INTEREST_2024.phaseout[status] else { return eligible }
    let start = phaseout.start
    let end = phaseout.end
    if magi <= start { return eligible }
    if magi >= end { return 0 }
    return eligible - eligible * ((magi - start) / (end - start))
}
