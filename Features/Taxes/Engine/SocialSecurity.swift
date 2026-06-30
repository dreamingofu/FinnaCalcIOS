/**
 * Taxable portion of Social Security benefits — IRS Social Security Benefits
 * Worksheet (closed form).
 *
 * Provisional ("combined") income = all other income + tax-exempt interest +
 * ½ of benefits − certain above-the-line adjustments (Schedule 1 lines 11–20,
 * 23, 25; NOTABLY excluding student loan interest, line 21). Then:
 *   - ≤ base1:        none taxable
 *   - base1..base2:   min(50% of excess over base1, 50% of benefits)
 *   - > base2:        min(85% of excess over base2 + tier1, 85% of benefits)
 * where tier1 = min(50% of benefits, 50% of (base2 − base1)).
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/socialSecurity.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported name,
 * same formulas, same conditionals and order of operations.
 * TS `number` -> Swift `Double`.
 */

import Foundation

/// Parameters for `computeTaxableSocialSecurity`.
/// TS: the inline params object literal.
public struct TaxableSocialSecurityParams {
    public var benefits: Double
    public var otherIncome: Double
    public var taxExemptInterest: Double
    /// Schedule 1 lines 11–20, 23, 25 (excludes student loan interest).
    public var adjustmentsForProvisional: Double
    public var status: FilingStatus
    public var livedApartFromSpouse: Bool

    public init(
        benefits: Double,
        otherIncome: Double,
        taxExemptInterest: Double,
        adjustmentsForProvisional: Double,
        status: FilingStatus,
        livedApartFromSpouse: Bool
    ) {
        self.benefits = benefits
        self.otherIncome = otherIncome
        self.taxExemptInterest = taxExemptInterest
        self.adjustmentsForProvisional = adjustmentsForProvisional
        self.status = status
        self.livedApartFromSpouse = livedApartFromSpouse
    }
}

public func computeTaxableSocialSecurity(_ params: TaxableSocialSecurityParams) -> Double {
    let benefits = params.benefits
    let otherIncome = params.otherIncome
    let taxExemptInterest = params.taxExemptInterest
    let adjustmentsForProvisional = params.adjustmentsForProvisional
    let status = params.status
    if benefits <= 0 { return 0 }

    let half = SS_TAXABILITY_2024.firstTierRate * benefits
    let provisional =
        otherIncome + taxExemptInterest + half - adjustmentsForProvisional
    let bases = ssBaseAmounts(status, params.livedApartFromSpouse)
    let base1 = bases.base1
    let base2 = bases.base2

    if provisional <= base1 { return 0 }

    if provisional <= base2 {
        return Swift.min(
            SS_TAXABILITY_2024.firstTierRate * (provisional - base1),
            half
        )
    }

    let tier1 = Swift.min(half, SS_TAXABILITY_2024.firstTierRate * (base2 - base1))
    return Swift.min(
        SS_TAXABILITY_2024.maxInclusionRate * (provisional - base2) + tier1,
        SS_TAXABILITY_2024.maxInclusionRate * benefits
    )
}
