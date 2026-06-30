/**
 * Regular income tax (Form 1040 line 16, ordinary-income path).
 *
 * For taxable income under $100,000 the IRS REQUIRES the Tax Table, which taxes
 * the midpoint of a $50 bucket — this differs from the straight bracket formula
 * by a few dollars. At/above $100,000 the Tax Computation Worksheet applies the
 * rate schedule directly. Both are implemented here.
 *
 * (Qualified dividends / long-term capital gains use a separate worksheet added
 * in Phase 2; this module is the ordinary-income computation.)
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/regularTax.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding, same order of operations.
 * TS `number` -> Swift `Double`. TS exported functions -> Swift top-level
 * functions with identical names. TS interfaces -> Swift structs.
 */
import Foundation

/** Tax from the rate schedule (exact, in cents) on a positive amount. */
public func bracketTax(_ amount: Double, _ status: FilingStatus) -> Double {
    if amount <= 0 { return 0 }
    var tax: Double = 0
    for b in ORDINARY_BRACKETS_2024[status]! {
        if amount > b.min {
            let upper = Swift.min(amount, b.max)
            tax += (upper - b.min) * b.rate
        }
    }
    return tax
}

/** The marginal rate that applies at a given taxable income. */
public func marginalRate(_ taxableIncome: Double, _ status: FilingStatus) -> Double {
    var rate: Double = 0
    for b in ORDINARY_BRACKETS_2024[status]! {
        if taxableIncome > b.min { rate = b.rate }
    }
    return rate
}

/**
 * The IRS Tax Table taxes the midpoint of a $50 bucket. Below $50 the table uses
 * irregular small rows: $0–5, $5–15, $15–25, $25–50. Returns the income amount
 * the bracket formula should be applied to.
 */
private func taxTableBasis(_ ti: Double) -> Double {
    if ti < 5 { return 2.5 }
    if ti < 15 { return 10 }
    if ti < 25 { return 20 }
    if ti < 50 { return 37.5 }
    return Foundation.floor(ti / 50) * 50 + 25
}

public struct RegularTaxResult: Equatable {
    public var tax: Double
    public var usedTaxTable: Bool
    public var marginalRate: Double

    public init(tax: Double, usedTaxTable: Bool, marginalRate: Double) {
        self.tax = tax
        self.usedTaxTable = usedTaxTable
        self.marginalRate = marginalRate
    }
}

/** Compute regular tax on ordinary taxable income (Tax Table vs Computation Worksheet). */
public func computeRegularTax(
    _ taxableIncome: Double,
    _ status: FilingStatus
) -> RegularTaxResult {
    let ti = taxableIncome > 0 ? taxableIncome : 0
    let mr = marginalRate(ti, status)
    if ti < 100_000 {
        return RegularTaxResult(
            tax: dollar(bracketTax(taxTableBasis(ti), status)),
            usedTaxTable: true,
            marginalRate: mr
        )
    }
    return RegularTaxResult(tax: dollar(bracketTax(ti, status)), usedTaxTable: false, marginalRate: mr)
}
