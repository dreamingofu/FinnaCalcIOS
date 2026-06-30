/**
 * QualifiedDivCapGain.swift
 *
 * Qualified Dividends and Capital Gain Tax Worksheet (Form 1040 line 16).
 *
 * Preferential income (qualified dividends + net long-term capital gain) is
 * STACKED ON TOP of ordinary-rate income and taxed at 0/15/20% using the 2024
 * breakpoints. Ordinary income is taxed first at regular rates. The final result
 * is floored at the all-ordinary tax (the worksheet's safety check), so electing
 * preferential treatment never costs more than ordinary rates.
 *
 * (28% collectibles gain and unrecaptured §1250 gain route to the Schedule D Tax
 * Worksheet — not yet modeled; the simpler worksheet is exact when those are zero.)
 *
 * Pure-Swift port of
 * components/tax-engine/engine/pipeline/qualifiedDivCapGain.ts. Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same constants,
 * same formulas, same rounding, same order of operations. TS `number` -> Swift
 * `Double`.
 */

import Foundation

public struct QualDivResult: Equatable {
    public var tax: Double
    public var preferentialIncome: Double
    public var amountAt0: Double
    public var amountAt15: Double
    public var amountAt20: Double

    public init(
        tax: Double,
        preferentialIncome: Double,
        amountAt0: Double,
        amountAt15: Double,
        amountAt20: Double
    ) {
        self.tax = tax
        self.preferentialIncome = preferentialIncome
        self.amountAt0 = amountAt0
        self.amountAt15 = amountAt15
        self.amountAt20 = amountAt20
    }
}

/// Return value of `preferentialStackTax` — TS inline object literal
/// `{ tax; amountAt0; amountAt15; amountAt20 }`.
public struct PreferentialStackResult: Equatable {
    public var tax: Double
    public var amountAt0: Double
    public var amountAt15: Double
    public var amountAt20: Double

    public init(tax: Double, amountAt0: Double, amountAt15: Double, amountAt20: Double) {
        self.tax = tax
        self.amountAt0 = amountAt0
        self.amountAt15 = amountAt15
        self.amountAt20 = amountAt20
    }
}

/**
 * The 0/15/20% tax on `preferential` income stacked on top of `ordinaryBelow`.
 * Shared by the regular worksheet and the AMT computation (AMT uses the same
 * preferential capital-gains rates).
 */
public func preferentialStackTax(
    _ ordinaryBelow: Double,
    _ preferential: Double,
    _ status: FilingStatus
) -> PreferentialStackResult {
    let breakpoints = CAP_GAIN_BREAKPOINTS_2024[status]!
    let zeroRateMax = breakpoints.zeroRateMax
    let fifteenRateMax = breakpoints.fifteenRateMax
    let top = ordinaryBelow + preferential
    let amountAt0 = Swift.max(0, Swift.min(top, zeroRateMax) - ordinaryBelow)
    let amountAt15 = Swift.max(
        0,
        Swift.min(top, fifteenRateMax) - Swift.max(ordinaryBelow, zeroRateMax)
    )
    let amountAt20 = Swift.max(0, top - Swift.max(ordinaryBelow, fifteenRateMax))
    return PreferentialStackResult(
        tax: amountAt15 * 0.15 + amountAt20 * 0.2,
        amountAt0: amountAt0,
        amountAt15: amountAt15,
        amountAt20: amountAt20
    )
}

/**
 * - Parameter taxableIncome:  Form 1040 line 15 (total taxable income).
 * - Parameter qualifiedDividends:  Qualified dividends (1099-DIV box 1b).
 * - Parameter netCapitalGain:  Net capital gain eligible for preferential rates.
 */
public func computeQualifiedDivCapGainTax(
    _ taxableIncome: Double,
    _ qualifiedDividends: Double,
    _ netCapitalGain: Double,
    _ status: FilingStatus
) -> QualDivResult {
    let ti = Swift.max(0, taxableIncome)
    let preferential = Swift.max(0, Swift.min(qualifiedDividends + netCapitalGain, ti))
    let ordinary = Swift.max(0, ti - preferential)

    let stack = preferentialStackTax(ordinary, preferential, status)
    let preferentialTax = stack.tax
    let amountAt0 = stack.amountAt0
    let amountAt15 = stack.amountAt15
    let amountAt20 = stack.amountAt20

    let ordinaryTax = computeRegularTax(ordinary, status).tax
    let stacked = ordinaryTax + preferentialTax

    // Safety floor: never more than taxing everything at ordinary rates.
    let allOrdinary = computeRegularTax(ti, status).tax
    let tax = dollar(Swift.min(stacked, allOrdinary))

    return QualDivResult(
        tax: tax,
        preferentialIncome: preferential,
        amountAt0: amountAt0,
        amountAt15: amountAt15,
        amountAt20: amountAt20
    )
}
