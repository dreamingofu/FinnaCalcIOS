/**
 * DeductionCompare.swift
 *
 * Standard vs itemized deduction (Form 1040 line 12; Schedule A).
 *
 * Computes the full standard deduction (base + age-65/blind additions, with the
 * dependent cap) and a Schedule A itemized total (medical 7.5% floor, SALT cap,
 * mortgage interest, charitable AGI limits), then picks the larger — unless the
 * return forces itemizing (e.g. an MFS spouse who itemized).
 *
 * Pure-Swift port of
 * components/tax-engine/engine/pipeline/deductionCompare.ts. Foundation-only —
 * no SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the TypeScript: same exported
 * names, same constants, same formulas, same rounding, same conditionals and
 * order of operations. TS `number` -> Swift `Double`.
 *
 * Depends on `computeRegularTax` (regularTax.ts port) and `nonNeg` (round.ts
 * port).
 */

import Foundation

/** For TY2024, a person is treated as 65+ if born before January 2, 1960. */
public func isConsidered65For2024(_ dateOfBirth: String) -> Bool {
    if dateOfBirth.isEmpty { return false }
    // TS: `new Date(dateOfBirth)` — parse the ISO date string.
    let dob = parseJsDate(dateOfBirth)
    guard let dob = dob else { return false } // Number.isNaN(dob.getTime())
    // Born on or before 1960-01-01 → considered 65 by year-end 2024.
    // TS compares against new Date("1960-01-01T00:00:00Z").getTime().
    let cutoff = parseJsDate("1960-01-01T00:00:00Z")!
    return dob.timeIntervalSince1970 <= cutoff.timeIntervalSince1970
}

/// Parse a date string the way JS `new Date(...)` does for the inputs this
/// module sees (ISO 8601: "YYYY-MM-DD" interpreted as UTC midnight, or a full
/// "YYYY-MM-DDTHH:mm:ssZ" timestamp). Returns nil when the string is not a
/// valid date (mirrors `Number.isNaN(dob.getTime())`).
private func parseJsDate(_ s: String) -> Date? {
    // Full ISO 8601 timestamp (e.g. "1960-01-01T00:00:00Z").
    let isoFull = ISO8601DateFormatter()
    isoFull.formatOptions = [.withInternetDateTime]
    if let d = isoFull.date(from: s) { return d }

    // Date-only "YYYY-MM-DD" — JS treats this as UTC midnight.
    let dateOnly = DateFormatter()
    dateOnly.locale = Locale(identifier: "en_US_POSIX")
    dateOnly.timeZone = TimeZone(identifier: "UTC")
    dateOnly.dateFormat = "yyyy-MM-dd"
    if let d = dateOnly.date(from: s) { return d }

    return nil
}

/** Count the age-65/blind "boxes" that drive the additional standard deduction. */
private func countAdditionalBoxes(_ r: TaxReturn2024) -> Double {
    var boxes: Double = 0
    if isConsidered65For2024(r.taxpayer.dateOfBirth) { boxes += 1 }
    if r.taxpayer.blind { boxes += 1 }
    // Spouse's boxes count for MFJ / QSS (and MFS only in narrow cases not modeled here).
    if (r.filingStatus == .mfj || r.filingStatus == .qss), let spouse = r.spouse {
        if isConsidered65For2024(spouse.dateOfBirth) { boxes += 1 }
        if spouse.blind { boxes += 1 }
    }
    return boxes
}

public func computeStandardDeduction(_ r: TaxReturn2024, _ earnedIncome: Double) -> Double {
    let status = r.filingStatus
    let base = STANDARD_DEDUCTION_2024[status]!
    let additionalPerBox = isMarriedStatus(status)
        ? ADDITIONAL_STD_DEDUCTION_2024.married
        : ADDITIONAL_STD_DEDUCTION_2024.unmarried
    let additional = countAdditionalBoxes(r) * additionalPerBox

    // Dependent standard-deduction cap: limited to the greater of $1,300 or
    // (earned income + $450), but never more than the regular base.
    var baseDeduction = base
    if r.taxpayer.claimedAsDependentByAnother {
        let limited = Swift.max(
            DEPENDENT_STD_DEDUCTION_2024.floor,
            earnedIncome + DEPENDENT_STD_DEDUCTION_2024.earnedIncomeBump
        )
        baseDeduction = Swift.min(base, limited)
    }

    return baseDeduction + additional
}

public func computeItemizedDeduction(_ r: TaxReturn2024, _ agi: Double) -> Double {
    let it = r.itemized
    let status = r.filingStatus

    let medical = nonNeg(it.medicalExpenses - agi * MEDICAL_AGI_FLOOR_2024)

    let saltRaw =
        it.stateLocalIncomeOrSalesTax + it.realEstateTaxes + it.personalPropertyTaxes
    let saltCap = status == .mfs ? SALT_CAP_2024.mfs : SALT_CAP_2024.standard
    let salt = Swift.min(saltRaw, saltCap)

    // Mortgage interest: limited to the acquisition-debt cap. When the loan
    // balance exceeds the limit, only the proportional share of interest is
    // deductible ($750k for loans after 12/15/2017, $1M grandfathered; halved MFS).
    let mortgageLimit = it.mortgageAfterDec2017
        ? (status == .mfs
            ? MORTGAGE_DEBT_LIMIT_2024.postDec2017Mfs
            : MORTGAGE_DEBT_LIMIT_2024.postDec2017)
        : (status == .mfs
            ? MORTGAGE_DEBT_LIMIT_2024.grandfatheredMfs
            : MORTGAGE_DEBT_LIMIT_2024.grandfathered)
    let mortgage =
        it.mortgageBalance > mortgageLimit
            ? nonNeg(it.mortgageInterest) * (mortgageLimit / it.mortgageBalance)
            : nonNeg(it.mortgageInterest)

    let charitableCash = Swift.min(it.charitableCash, agi * CHARITABLE_LIMITS_2024.cashPctOfAgi)
    let charitableNonCash = Swift.min(
        it.charitableNonCash,
        agi * CHARITABLE_LIMITS_2024.nonCashPctOfAgi
    )

    let casualty = nonNeg(it.casualtyLosses)

    return medical + salt + mortgage + charitableCash + charitableNonCash + casualty
}

/// TS: `interface DeductionResult`.
public struct DeductionResult: Equatable {
    public var standard: Double
    public var itemized: Double
    public var used: DeductionUsed // TS: "standard" | "itemized"
    public var amount: Double
    /** Federal tax saved by the chosen deduction vs the alternative (estimate). */
    public var itemizedSavings: Double

    public init(
        standard: Double,
        itemized: Double,
        used: DeductionUsed,
        amount: Double,
        itemizedSavings: Double
    ) {
        self.standard = standard
        self.itemized = itemized
        self.used = used
        self.amount = amount
        self.itemizedSavings = itemizedSavings
    }
}

public func computeDeduction(
    _ r: TaxReturn2024,
    _ agi: Double,
    _ earnedIncome: Double
) -> DeductionResult {
    let status: FilingStatus = r.filingStatus
    let standard = computeStandardDeduction(r, earnedIncome)
    let itemized = computeItemizedDeduction(r, agi)

    let useItemized = r.forceItemize || itemized > standard
    let used: DeductionUsed = useItemized ? .itemized : .standard
    let amount = used == .itemized ? itemized : standard

    // Estimate the tax difference between the two deductions (ignoring QBI /
    // preferential rates, which Phase 1 doesn't apply) for the optimizer display.
    let taxStandard = computeRegularTax(nonNeg(agi - standard), status).tax
    let taxItemized = computeRegularTax(nonNeg(agi - itemized), status).tax
    let itemizedSavings = nonNeg(taxStandard - taxItemized)

    return DeductionResult(
        standard: standard,
        itemized: itemized,
        used: used,
        amount: amount,
        itemizedSavings: itemizedSavings
    )
}
