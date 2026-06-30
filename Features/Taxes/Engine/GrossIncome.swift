/**
 * Gross income aggregation — the ordinary-rate income reported directly on the
 * front of Form 1040 (lines 1–9): wages, taxable interest, ordinary dividends
 * (which include the qualified subset for income purposes), unemployment, and
 * other income. Schedule C/E/SE, capital gains, and taxable Social Security are
 * added by the orchestrator. Also surfaces qualified dividends and tax-exempt
 * interest for the tax and Social Security worksheets.
 *
 * The engine only reads a source when its interview flag is set, so hidden /
 * irrelevant income never affects the result.
 *
 * Pure-Swift port of components/tax-engine/engine/pipeline/grossIncome.ts.
 * Foundation-only. Faithful 1:1 mirror of the TypeScript: same exported names,
 * same formulas, same order of operations. TS `number` -> Swift `Double`.
 */

import Foundation

public struct GrossIncomeResult: Equatable {
    public var wages: Double
    public var taxableInterest: Double
    public var taxExemptInterest: Double
    public var ordinaryDividends: Double
    public var qualifiedDividends: Double
    public var unemployment: Double
    /// Taxable amount of pension/IRA/retirement distributions (1099-R box 2a).
    public var retirementDistributions: Double
    public var otherIncome: Double
    /// Wages + interest + ordinary dividends + retirement + unemployment + other (no Sch C/D/E/SS).
    public var ordinaryTotal: Double
    /// Earned income from wages (for CTC/ACTC and the dependent standard deduction).
    public var wageEarnedIncome: Double

    public init(
        wages: Double,
        taxableInterest: Double,
        taxExemptInterest: Double,
        ordinaryDividends: Double,
        qualifiedDividends: Double,
        unemployment: Double,
        retirementDistributions: Double,
        otherIncome: Double,
        ordinaryTotal: Double,
        wageEarnedIncome: Double
    ) {
        self.wages = wages
        self.taxableInterest = taxableInterest
        self.taxExemptInterest = taxExemptInterest
        self.ordinaryDividends = ordinaryDividends
        self.qualifiedDividends = qualifiedDividends
        self.unemployment = unemployment
        self.retirementDistributions = retirementDistributions
        self.otherIncome = otherIncome
        self.ordinaryTotal = ordinaryTotal
        self.wageEarnedIncome = wageEarnedIncome
    }
}

public func computeGrossIncome(_ r: TaxReturn2024) -> GrossIncomeResult {
    let f = r.income.flags

    let wages = f.hasW2 ? sumBy(r.income.w2, { w in w.box1Wages }) : 0
    let taxableInterest = f.hasInterest
        ? sumBy(r.income.f1099Int, { i in i.box1Interest + i.box3UsTreasuryInterest })
        : 0
    let taxExemptInterest = f.hasInterest
        ? sumBy(r.income.f1099Int, { i in i.box8TaxExemptInterest })
        : 0
    let ordinaryDividends = f.hasDividends
        ? sumBy(r.income.f1099Div, { d in d.box1aOrdinaryDividends })
        : 0
    let qualifiedDividends = f.hasDividends
        ? sumBy(r.income.f1099Div, { d in d.box1bQualifiedDividends })
        : 0
    let unemployment = f.hasUnemployment
        ? sumBy(r.income.f1099G, { g in g.box1Unemployment })
        : 0
    let retirementDistributions = f.hasRetirementDistributions
        ? sumBy(r.income.f1099R, { x in x.box2aTaxableAmount })
        : 0
    let otherIncome = f.hasOtherIncome ? r.income.otherIncome : 0

    let ordinaryTotal =
        wages +
        taxableInterest +
        ordinaryDividends +
        retirementDistributions +
        unemployment +
        otherIncome

    return GrossIncomeResult(
        wages: wages,
        taxableInterest: taxableInterest,
        taxExemptInterest: taxExemptInterest,
        ordinaryDividends: ordinaryDividends,
        qualifiedDividends: qualifiedDividends,
        unemployment: unemployment,
        retirementDistributions: retirementDistributions,
        otherIncome: otherIncome,
        ordinaryTotal: ordinaryTotal,
        wageEarnedIncome: wages
    )
}
