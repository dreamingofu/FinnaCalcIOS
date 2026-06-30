/**
 * Self-employment tax — Schedule SE.
 *
 * Net earnings = net SE profit × 92.35%. If under $400, no SE tax. The 12.4%
 * Social Security portion applies up to the wage base, REDUCED by W-2 Social
 * Security wages already taxed (so a high W-2 earner with a side business doesn't
 * pay SS tax twice). The 2.9% Medicare portion has no cap. Computed per person.
 * Half of the total SE tax is deductible above the line (Schedule 1 line 15).
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/scheduleSE.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding, same order of operations.
 * TS `number` -> Swift `Double`, TS `Record<Owner, number>` -> Swift
 * `[Owner: Double]`, TS interface -> Swift struct.
 */
import Foundation

public struct SeTaxResult: Equatable {
    public var seTax: Double
    public var deduction: Double
    /// Net SE earnings (after the 92.35% factor) — used by QBI later.
    public var netEarnings: Double

    public init(seTax: Double, deduction: Double, netEarnings: Double) {
        self.seTax = seTax
        self.deduction = deduction
        self.netEarnings = netEarnings
    }
}

/// TS: `type Owner = "taxpayer" | "spouse"`.
public enum Owner: String, Codable, Equatable, CaseIterable {
    case taxpayer
    case spouse
}

public func computeSelfEmploymentTax(
    _ netSeByOwner: [Owner: Double],
    _ w2SsWagesByOwner: [Owner: Double]
) -> SeTaxResult {
    var seTax: Double = 0
    var netEarnings: Double = 0

    for owner in [Owner.taxpayer, Owner.spouse] {
        let net = netSeByOwner[owner] ?? 0
        if net <= 0 { continue }
        let earnings = net * SE_TAX_2024.netEarningsFactor
        if earnings < 400 { continue }
        netEarnings += earnings

        let ssWageRemaining = Swift.max(
            0,
            SE_TAX_2024.socialSecurityWageBase - (w2SsWagesByOwner[owner] ?? 0)
        )
        let ssBase = Swift.min(earnings, ssWageRemaining)
        let ssPortion = ssBase * SE_TAX_2024.socialSecurityRate
        let medicarePortion = earnings * SE_TAX_2024.medicareRate
        seTax += ssPortion + medicarePortion
    }

    return SeTaxResult(
        seTax: seTax,
        deduction: seTax * SE_TAX_2024.deductibleFraction,
        netEarnings: netEarnings
    )
}
