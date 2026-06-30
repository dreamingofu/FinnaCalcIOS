/**
 * PremiumTaxCredit.swift
 *
 * Premium Tax Credit reconciliation — Form 8962 (simplified).
 *
 * Compares the allowed PTC against advance payments. A net positive is a
 * refundable credit; a net negative is excess advance PTC that must be repaid.
 * NOTE: the income-based repayment limitation (which caps the repayment for
 * filers under 400% of the federal poverty line) is NOT modeled — the
 * orchestrator surfaces a warning so the figure is treated as an estimate.
 *
 * Pure-Swift port of
 * components/tax-engine/engine/pipeline/premiumTaxCredit.ts. Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same formulas,
 * same rounding. TS `number` -> Swift `Double`.
 */

import Foundation

public struct PtcResult: Equatable {
    public var netRefundable: Double
    public var repayment: Double

    public init(netRefundable: Double, repayment: Double) {
        self.netRefundable = netRefundable
        self.repayment = repayment
    }
}

public func computePremiumTaxCredit(_ r: TaxReturn2024) -> PtcResult {
    if !r.credits.hasMarketplaceCoverage { return PtcResult(netRefundable: 0, repayment: 0) }
    let net = r.credits.premiumTaxCreditAllowed - r.credits.advancePremiumTaxCredit
    if net >= 0 { return PtcResult(netRefundable: dollar(net), repayment: 0) }
    return PtcResult(netRefundable: 0, repayment: dollar(-net))
}
