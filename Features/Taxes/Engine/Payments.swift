/**
 * Payments.swift
 *
 * Total federal payments (Form 1040 lines 25–26) — withholding from all forms
 * plus estimated payments. Refundable credits (EITC/ACTC/etc.) are added by the
 * orchestrator into total payments per the 1040 ordering.
 *
 * Pure-Swift port of
 * components/tax-engine/engine/pipeline/payments.ts. Foundation-only —
 * no SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the TypeScript: same exported
 * names, same constants, same formulas, same rounding, same conditionals and
 * order of operations. TS `number` -> Swift `Double`.
 */

import Foundation

public struct PaymentsResult: Equatable {
    public var withholding: Double
    public var estimatedPayments: Double
    /// Withholding + estimated (excludes refundable credits).
    public var total: Double

    public init(withholding: Double, estimatedPayments: Double, total: Double) {
        self.withholding = withholding
        self.estimatedPayments = estimatedPayments
        self.total = total
    }
}

public func computeWithholdingAndPayments(_ r: TaxReturn2024) -> PaymentsResult {
    let f = r.income.flags
    let w2Withholding = f.hasW2 ? sumBy(r.income.w2, { w in w.box2FederalWithholding }) : 0
    let intWithholding = f.hasInterest
        ? sumBy(r.income.f1099Int, { i in i.box4FederalWithholding })
        : 0
    let divWithholding = f.hasDividends
        ? sumBy(r.income.f1099Div, { d in d.box4FederalWithholding })
        : 0
    let retirementWithholding = f.hasRetirementDistributions
        ? sumBy(r.income.f1099R, { x in x.box4FederalWithholding })
        : 0
    let unemploymentWithholding = f.hasUnemployment
        ? sumBy(r.income.f1099G, { g in g.box4FederalWithholding })
        : 0
    let ssaWithholding = f.hasSocialSecurity
        ? sumBy(r.income.f1099Ssa, { s in s.federalWithholding })
        : 0

    let withholding =
        w2Withholding +
        intWithholding +
        divWithholding +
        retirementWithholding +
        unemploymentWithholding +
        ssaWithholding +
        r.payments.additionalWithholding

    let estimatedPayments = r.payments.estimatedPayments
    return PaymentsResult(
        withholding: withholding,
        estimatedPayments: estimatedPayments,
        total: withholding + estimatedPayments
    )
}
