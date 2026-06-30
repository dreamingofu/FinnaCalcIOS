/**
 * Amt.swift
 *
 * Alternative Minimum Tax — Form 6251 (simplified).
 *
 * AMTI = taxable income (after QBI) + add-backs (the SALT itemized deduction, or
 * the standard deduction if not itemizing). The AMT exemption phases out at 25%
 * of AMTI over the threshold. The tentative minimum tax applies 26%/28% to the
 * ordinary portion of the base and the regular 0/15/20% rates to preferential
 * income. AMT = max(0, TMT − regular tax).
 *
 * Other AMT preferences (ISO exercise, depletion, private-activity bond interest)
 * are not tracked; this captures the common SALT/standard-deduction driver.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/amt.ts. Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same constants,
 * same formulas, same rounding, same conditionals and order of operations.
 * TS `number` -> Swift `Double`; TS interface -> Swift struct.
 *
 * Dependencies (ported elsewhere, same names):
 *   - AMT_2024 (TaxConstants.swift)
 *   - preferentialStackTax(_:_:_:) (qualifiedDivCapGain port) — returns a value
 *     with a `.tax` property
 *   - dollar(_:) (TaxRound.swift)
 */

import Foundation

/// TS: `export interface AmtResult`.
public struct AmtResult: Equatable {
    public var amt: Double
    public var tentativeMinimumTax: Double
    public var amti: Double
    public var exemption: Double

    public init(
        amt: Double,
        tentativeMinimumTax: Double,
        amti: Double,
        exemption: Double
    ) {
        self.amt = amt
        self.tentativeMinimumTax = tentativeMinimumTax
        self.amti = amti
        self.exemption = exemption
    }
}

/// Parameters for `computeAmt`. TS: the inline object-literal parameter
/// `{ taxableIncome; addBacks; preferentialIncome; regularTax; status }`.
public struct ComputeAmtParams {
    public var taxableIncome: Double
    public var addBacks: Double
    public var preferentialIncome: Double
    public var regularTax: Double
    public var status: FilingStatus

    public init(
        taxableIncome: Double,
        addBacks: Double,
        preferentialIncome: Double,
        regularTax: Double,
        status: FilingStatus
    ) {
        self.taxableIncome = taxableIncome
        self.addBacks = addBacks
        self.preferentialIncome = preferentialIncome
        self.regularTax = regularTax
        self.status = status
    }
}

/// TS: `export function computeAmt(params: {...}): AmtResult`.
public func computeAmt(_ params: ComputeAmtParams) -> AmtResult {
    let taxableIncome = params.taxableIncome
    let addBacks = params.addBacks
    let preferentialIncome = params.preferentialIncome
    let regularTax = params.regularTax
    let status = params.status

    let amti = Swift.max(0, taxableIncome + addBacks)

    let fullExemption = AMT_2024.exemption[status]!
    let phaseStart = AMT_2024.exemptionPhaseoutThreshold[status]!
    let exemption =
        amti > phaseStart
            ? Swift.max(0, fullExemption - AMT_2024.exemptionPhaseoutRate * (amti - phaseStart))
            : fullExemption

    let base = Swift.max(0, amti - exemption)
    let pref = Swift.max(0, Swift.min(preferentialIncome, base))
    let ordinaryBase = base - pref

    let bk = status == .mfs ? AMT_2024.rate28ThresholdMfs : AMT_2024.rate28Threshold
    let ordinaryTmt =
        ordinaryBase <= bk
            ? ordinaryBase * AMT_2024.lowRate
            : bk * AMT_2024.lowRate + (ordinaryBase - bk) * AMT_2024.highRate
    let prefTmt = preferentialStackTax(ordinaryBase, pref, status).tax

    let tentativeMinimumTax = dollar(ordinaryTmt + prefTmt)
    return AmtResult(
        amt: Swift.max(0, tentativeMinimumTax - regularTax),
        tentativeMinimumTax: tentativeMinimumTax,
        amti: amti,
        exemption: exemption
    )
}
