/**
 * Capital gains & losses — Schedule D / Form 8949.
 *
 * Nets short-term and long-term transactions (plus long-term capital gain
 * distributions from 1099-DIV box 2a and any prior-year carryovers), applies the
 * $3,000 ($1,500 MFS) annual loss-deduction limit, and computes:
 *  - includedInIncome: the amount that flows to Form 1040 (a gain, or the
 *    allowed loss as a negative).
 *  - preferentialLTCG: "net capital gain" (net LT gain reduced by net ST loss),
 *    the amount eligible for 0/15/20% rates.
 *  - carryover: short- and long-term loss carried to next year.
 *
 * Carryover character follows the Schedule D Capital Loss Carryover Worksheet
 * (the allowed loss is applied to short-term first, then long-term).
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/capitalGains.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same constants, same formulas, same rounding, same conditionals and order of
 * operations. TS `number` -> Swift `Double`.
 */

import Foundation

public struct CapitalGainsResult: Equatable {
    public var netShortTerm: Double
    public var netLongTerm: Double
    public var totalNet: Double
    public var includedInIncome: Double
    public var preferentialLTCG: Double
    public var allowedLoss: Double
    public var carryoverShort: Double
    public var carryoverLong: Double

    public init(
        netShortTerm: Double,
        netLongTerm: Double,
        totalNet: Double,
        includedInIncome: Double,
        preferentialLTCG: Double,
        allowedLoss: Double,
        carryoverShort: Double,
        carryoverLong: Double
    ) {
        self.netShortTerm = netShortTerm
        self.netLongTerm = netLongTerm
        self.totalNet = totalNet
        self.includedInIncome = includedInIncome
        self.preferentialLTCG = preferentialLTCG
        self.allowedLoss = allowedLoss
        self.carryoverShort = carryoverShort
        self.carryoverLong = carryoverLong
    }
}

private let EMPTY: CapitalGainsResult = CapitalGainsResult(
    netShortTerm: 0,
    netLongTerm: 0,
    totalNet: 0,
    includedInIncome: 0,
    preferentialLTCG: 0,
    allowedLoss: 0,
    carryoverShort: 0,
    carryoverLong: 0
)

public func computeCapitalGains(_ r: TaxReturn2024) -> CapitalGainsResult {
    let f = r.income.flags
    if !f.hasCapitalGains && !f.hasDividends { return EMPTY }

    let transactions = f.hasCapitalGains ? r.income.f1099B : []
    var st: Double = 0
    var lt: Double = 0
    for t in transactions {
        // A wash-sale adjustment adds a disallowed loss back (reduces the loss).
        let gain = t.proceeds - t.costBasis + (t.washSaleAdjustment ?? 0)
        if t.longTerm { lt += gain }
        else { st += gain }
    }

    // Long-term capital gain distributions (1099-DIV box 2a) flow to Schedule D.
    if f.hasDividends {
        lt += sumBy(r.income.f1099Div, { d in d.box2aCapitalGainDistributions })
    }

    // Prior-year carryovers (stored as positive loss amounts) reduce this year.
    if f.hasCapitalGains {
        st -= r.income.capitalLossCarryoverShort
        lt -= r.income.capitalLossCarryoverLong
    }

    let netShortTerm = st
    let netLongTerm = lt
    let totalNet = netShortTerm + netLongTerm

    if totalNet >= 0 {
        // Net gain — "net capital gain" is the long-term portion not offset by ST loss.
        let preferentialLTCG = netLongTerm > 0 ? Swift.min(netLongTerm, totalNet) : 0
        var result = EMPTY
        result.netShortTerm = netShortTerm
        result.netLongTerm = netLongTerm
        result.totalNet = totalNet
        result.includedInIncome = totalNet
        result.preferentialLTCG = preferentialLTCG
        return result
    }

    // Net loss — limited deduction this year, remainder carries over.
    let limit = CAPITAL_LOSS_LIMIT_2024[r.filingStatus]!
    let allowedLoss = Swift.min(limit, Swift.abs(totalNet))

    // Carryover character (allowed loss applied to short-term first).
    var carryoverShort: Double = 0
    var carryoverLong: Double = 0
    var remainingAllowed = allowedLoss
    if netShortTerm < 0 {
        let stLoss = -netShortTerm
        let ltGain = Swift.max(0, netLongTerm)
        carryoverShort = Swift.max(0, stLoss - ltGain - allowedLoss)
        let usedAgainstSt = Swift.min(allowedLoss, Swift.max(0, stLoss - ltGain))
        remainingAllowed = allowedLoss - usedAgainstSt
    }
    if netLongTerm < 0 {
        let ltLoss = -netLongTerm
        let stGain = Swift.max(0, netShortTerm)
        carryoverLong = Swift.max(0, ltLoss - stGain - remainingAllowed)
    }

    return CapitalGainsResult(
        netShortTerm: netShortTerm,
        netLongTerm: netLongTerm,
        totalNet: totalNet,
        includedInIncome: -allowedLoss,
        preferentialLTCG: 0,
        allowedLoss: allowedLoss,
        carryoverShort: carryoverShort,
        carryoverLong: carryoverLong
    )
}
