/**
 * TaxCalculator.swift
 *
 * calculateFederalTax — the pure orchestrator.
 *
 * Runs the ordered IRS computation pipeline and assembles a fully traced
 * TaxCalculationResult. No side effects, no I/O — deterministic output.
 *
 * Pure-Swift port of components/tax-engine/engine/calculator.ts. Foundation-only
 * — no SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the TypeScript: same order
 * of operations, the Social-Security ↔ IRA fixed-point loop, the credit
 * ordering, the trace lines, warnings, and audit flags. TS `number` -> Swift
 * `Double`; TS `Record<string, number>` -> `[String: Double]`; the inline
 * `magi` object literal -> `MagiBreakdown`.
 *
 * Calls the already-ported pipeline modules by their exact Swift signatures
 * (several TS functions that took an inline object param are Swift functions
 * taking a param struct: TaxableSocialSecurityParams, ComputeQbiDeductionParams,
 * ComputeAmtParams, ComputeEitcParams, StateInput).
 */

import Foundation

/// Age at the end of 2024 (for the childless-EITC age test). nil if no DOB.
/// TS: `ageAtEndOf2024(dob: string): number | undefined`.
private func ageAtEndOf2024(_ dob: String) -> Double? {
    if dob.isEmpty { return nil }
    // TS: `new Date(dob)`; `Number.isNaN(d.getTime())` → undefined; else `2024 - d.getUTCFullYear()`.
    guard let year = jsDateUTCFullYear(dob) else { return nil }
    return 2024 - year
}

/// The UTC full year of a JS-parsed ISO date string, or nil when unparseable
/// (mirrors `Number.isNaN(new Date(dob).getTime())`). JS treats a date-only
/// "YYYY-MM-DD" as UTC midnight, so the UTC year equals the leading year.
private func jsDateUTCFullYear(_ s: String) -> Double? {
    if s.isEmpty { return nil }
    let isoFull = ISO8601DateFormatter()
    isoFull.timeZone = TimeZone(identifier: "UTC")
    isoFull.formatOptions = [.withInternetDateTime]
    if let d = isoFull.date(from: s) {
        return jsUTCYear(of: d)
    }
    let dateOnly = ISO8601DateFormatter()
    dateOnly.timeZone = TimeZone(identifier: "UTC")
    dateOnly.formatOptions = [.withFullDate]
    if let d = dateOnly.date(from: s) {
        return jsUTCYear(of: d)
    }
    return nil
}

private func jsUTCYear(of date: Date) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return Double(cal.component(.year, from: date))
}

public func calculateFederalTax(_ r: TaxReturn2024) -> TaxCalculationResult {
    var warnings: [Warning] = []
    var auditFlags: [AuditFlag] = []
    var trace: [LineTrace] = []
    func line(_ id: String, _ label: String, _ formRef: String, _ amount: Double) {
        trace.append(LineTrace(id: id, label: label, formRef: formRef, amount: amount))
    }

    // ---- 1. Schedule C → net SE profit per owner ----
    let schedC = computeScheduleC(r)

    // ---- 2. Schedule SE → SE tax + 50% deduction (coordinated with W-2 SS wages) ----
    let w2SsWagesByOwner: [Owner: Double] = [
        .taxpayer: sumBy(
            r.income.w2.filter { $0.owner == .taxpayer },
            { $0.box3SsWages }
        ),
        .spouse: sumBy(
            r.income.w2.filter { $0.owner == .spouse },
            { $0.box3SsWages }
        ),
    ]
    let netSeByOwner: [Owner: Double] = [
        .taxpayer: schedC.netByOwner.taxpayer,
        .spouse: schedC.netByOwner.spouse,
    ]
    let se = computeSelfEmploymentTax(netSeByOwner, w2SsWagesByOwner)
    let seTax = dollar(se.seTax)

    // ---- 3. Capital gains (Schedule D / 8949) ----
    let capGains = computeCapitalGains(r)

    // ---- 4. Schedule E (rental / royalty / passthrough) ----
    let scheduleENet = r.income.flags.hasRental
        ? sumBy(r.income.scheduleE, { $0.netIncome })
        : 0

    // ---- 5. Ordinary income components ----
    let gross = computeGrossIncome(r)

    // All income except Social Security (used by the SS worksheet and AGI).
    let otherIncomeNoSS =
        gross.ordinaryTotal + schedC.totalNet + capGains.includedInIncome + scheduleENet

    // ---- 6. Fixed (AGI-independent) above-the-line adjustments ----
    let educator = educatorDeduction(r)
    let hsa = hsaDeduction(r)
    let sep = Swift.min(
        Swift.max(0, r.adjustments.sepSimpleContribution),
        nonNeg(schedC.totalNet - se.deduction)
    )
    let seHealth = seHealthDeduction(r, schedC.totalNet, se.deduction, sep)
    let fixedAdjustments = educator + hsa + se.deduction + seHealth + sep

    // ---- 7. Resolve Social Security taxability ↔ IRA deduction (fixed-point loop) ----
    // Both depend on AGI (which includes taxable SS), so iterate to a stable point.
    let ssBenefits = r.income.flags.hasSocialSecurity
        ? sumBy(r.income.f1099Ssa, { $0.box5NetBenefits })
        : 0
    let age50 = isAge50For2024(r.taxpayer.dateOfBirth)
    var taxableSS: Double = 0
    var ira: Double = 0
    for _ in 0..<6 {
        // SS provisional income subtracts Schedule 1 lines 11–20, 23, 25 (incl. IRA,
        // excl. student loan), which here is fixedAdjustments + the current IRA estimate.
        let newSS = computeTaxableSocialSecurity(
            TaxableSocialSecurityParams(
                benefits: ssBenefits,
                otherIncome: otherIncomeNoSS,
                taxExemptInterest: gross.taxExemptInterest,
                adjustmentsForProvisional: fixedAdjustments + ira,
                status: r.filingStatus,
                livedApartFromSpouse: r.livedApartFromSpouse
            )
        )
        // IRA MAGI = AGI computed without the IRA (and student loan) deduction.
        let iraMagi = otherIncomeNoSS + newSS - fixedAdjustments
        let newIra = iraDeduction(
            r.adjustments.traditionalIraContribution,
            iraMagi,
            r.filingStatus,
            r.adjustments.coveredByWorkplacePlan,
            r.adjustments.spouseCoveredByWorkplacePlan,
            age50
        )
        let converged = Swift.abs(newSS - taxableSS) < 0.005 && Swift.abs(newIra - ira) < 0.005
        taxableSS = newSS
        ira = newIra
        if converged { break }
    }

    // ---- 8. Student loan interest (MAGI = AGI before this deduction) ----
    let studentLoanMagi = otherIncomeNoSS + taxableSS - (fixedAdjustments + ira)
    let studentLoan = studentLoanInterestDeduction(
        r.adjustments.studentLoanInterest,
        studentLoanMagi,
        r.filingStatus
    )

    // ---- 9. Totals → AGI ----
    let totalAdjustments = dollar(fixedAdjustments + ira + studentLoan)
    let totalIncome = dollar(otherIncomeNoSS + taxableSS)
    line("totalIncome", "Total income", "Form 1040, line 9", totalIncome)
    line("adjustments", "Adjustments to income", "Schedule 1, line 25", totalAdjustments)
    let agi = dollar(totalIncome - totalAdjustments)
    line("agi", "Adjusted gross income", "Form 1040, line 11", agi)

    // ---- 10. MAGI variants (Phase 2: approximated as AGI; refined as rules land) ----
    let magi = MagiBreakdown(niit: agi, ira: agi, studentLoan: agi, ptc: agi, ctc: agi, aotc: agi)

    // ---- 11. Deduction: standard vs itemized ----
    let wageEarnedIncome = gross.wageEarnedIncome
    let seEarnedIncome = nonNeg(schedC.totalNet - se.deduction)
    let earnedIncome = wageEarnedIncome + seEarnedIncome
    let deduction = computeDeduction(r, agi, earnedIncome)
    let deductionAmount = dollar(deduction.amount)
    line(
        "deduction",
        deduction.used == .itemized ? "Itemized deductions" : "Standard deduction",
        deduction.used == .itemized ? "Schedule A" : "Form 1040, line 12",
        deductionAmount
    )

    // ---- 12. QBI deduction (§199A) ----
    let preferentialLTCG = capGains.preferentialLTCG
    let qualifiedDividends = gross.qualifiedDividends
    let netCapitalGainPreferential = qualifiedDividends + preferentialLTCG
    let taxableIncomeBeforeQbi = nonNeg(agi - deductionAmount)
    let qbiIncome = nonNeg(schedC.totalNet - se.deduction - seHealth - sep)
    let isSSTB = r.income.scheduleC.contains { $0.isSSTB }
    let qbi = computeQbiDeduction(
        ComputeQbiDeductionParams(
            qbiIncome: qbiIncome,
            taxableIncomeBeforeQbi: taxableIncomeBeforeQbi,
            netCapitalGain: netCapitalGainPreferential,
            isSSTB: isSSTB,
            status: r.filingStatus
        )
    )
    let qbiDeduction = dollar(qbi.deduction)
    if qbiDeduction > 0 {
        line("qbi", "Qualified business income deduction", "Form 1040, line 13", qbiDeduction)
    }

    // ---- 13. Taxable income ----
    let taxableIncome = nonNeg(taxableIncomeBeforeQbi - qbiDeduction)
    line("taxableIncome", "Taxable income", "Form 1040, line 15", taxableIncome)

    // ---- 14. Regular tax: Qualified Div & Cap Gain Worksheet when preferential income exists ----
    let hasPreferential = qualifiedDividends > 0 || preferentialLTCG > 0
    let regularTax: Double
    var usedTaxTable = false
    var usedQualDivWorksheet = false
    var marginalRate: Double = 0
    if hasPreferential && taxableIncome > 0 {
        let qd = computeQualifiedDivCapGainTax(
            taxableIncome,
            qualifiedDividends,
            preferentialLTCG,
            r.filingStatus
        )
        regularTax = qd.tax
        usedQualDivWorksheet = true
        marginalRate = computeRegularTax(taxableIncome, r.filingStatus).marginalRate
    } else {
        let reg = computeRegularTax(taxableIncome, r.filingStatus)
        regularTax = reg.tax
        usedTaxTable = reg.usedTaxTable
        marginalRate = reg.marginalRate
    }
    line("regularTax", "Tax", "Form 1040, line 16", regularTax)

    // ---- 15. AMT (Form 6251) ----
    let saltRaw =
        r.itemized.stateLocalIncomeOrSalesTax +
        r.itemized.realEstateTaxes +
        r.itemized.personalPropertyTaxes
    let saltCap = r.filingStatus == .mfs ? SALT_CAP_2024.mfs : SALT_CAP_2024.standard
    let amtAddBacks =
        deduction.used == .itemized ? Swift.min(saltRaw, saltCap) : deductionAmount
    let amtResult = computeAmt(
        ComputeAmtParams(
            taxableIncome: taxableIncome,
            addBacks: amtAddBacks,
            preferentialIncome: netCapitalGainPreferential,
            regularTax: regularTax,
            status: r.filingStatus
        )
    )
    let amt = dollar(amtResult.amt)
    if amt > 0 { line("amt", "Alternative minimum tax", "Schedule 2, line 1", amt) }
    let taxBeforeCredits = regularTax + amt

    // ---- 16. Nonrefundable credits (Schedule 3 first, then CTC per the 8812 limit) ----
    var nonrefundableCredits: [String: Double] = [:]
    var remainingTax = taxBeforeCredits
    @discardableResult
    func applyCredit(_ key: String, _ label: String, _ formRef: String, _ amount: Double) -> Double {
        let used = Swift.min(dollar(amount), remainingTax)
        if used > 0 {
            nonrefundableCredits[key] = used
            remainingTax -= used
            line(key, label, formRef, used)
        }
        return used
    }

    applyCredit("foreignTaxCredit", "Foreign tax credit", "Schedule 3, line 1", computeForeignTaxCredit(r))
    applyCredit("childDependentCare", "Child & dependent care credit", "Schedule 3, line 6f", computeCareCredit(r, agi))
    let education = computeEducationCredits(r, magi.aotc)
    applyCredit("education", "Education credits", "Schedule 3, line 3", education.nonrefundable)
    applyCredit("saversCredit", "Retirement savings (Saver's) credit", "Schedule 3, line 4", computeSaversCredit(r, agi))
    applyCredit("cleanEnergy", "Residential clean energy credit", "Schedule 3, line 5a", computeCleanEnergyCredit(r))
    applyCredit("evCredit", "Clean vehicle credit", "Schedule 3, line 6f", computeEvCredit(r, agi))

    // CTC / ODC limited to tax remaining after the Schedule 3 credits (8812 limit worksheet).
    let ctc = computeChildTaxCredit(r, magi.ctc, remainingTax, earnedIncome)
    applyCredit(
        "childTaxCredit",
        "Child Tax Credit / Credit for Other Dependents",
        "Form 1040, line 19",
        ctc.nonrefundable
    )

    let totalNonrefundableCredits = nonrefundableCredits.values.reduce(0, +)
    let taxAfterNonrefundable = nonNeg(taxBeforeCredits - totalNonrefundableCredits)

    // ---- 17. Other taxes (Schedule 2 Part II) ----
    let medicareWages = sumBy(r.income.w2, { $0.box5MedicareWages })
    let additionalMedicareTax = dollar(
        computeAdditionalMedicareTax(medicareWages, se.netEarnings, r.filingStatus)
    )
    let netInvestmentIncome =
        gross.taxableInterest +
        gross.ordinaryDividends +
        nonNeg(capGains.includedInIncome) +
        nonNeg(scheduleENet)
    let niit = dollar(computeNiit(netInvestmentIncome, magi.niit, r.filingStatus))
    let ptc = computePremiumTaxCredit(r)
    // 10% additional tax on early retirement distributions (Form 5329).
    let earlyCodes: [String] = EARLY_WITHDRAWAL_PENALTY_2024.earlyNoExceptionCodes
    let earlyDistributions = r.income.flags.hasRetirementDistributions
        ? sumBy(
            r.income.f1099R.filter { earlyCodes.contains($0.box7DistributionCode) },
            { $0.box2aTaxableAmount }
        )
        : 0
    let earlyWithdrawalPenalty = dollar(earlyDistributions * EARLY_WITHDRAWAL_PENALTY_2024.rate)
    let otherTaxes = dollar(
        seTax + additionalMedicareTax + niit + ptc.repayment + earlyWithdrawalPenalty
    )
    if seTax > 0 { line("seTax", "Self-employment tax", "Schedule 2, line 4", seTax) }
    if additionalMedicareTax > 0 {
        line("addlMedicare", "Additional Medicare Tax", "Schedule 2, line 11", additionalMedicareTax)
    }
    if niit > 0 { line("niit", "Net investment income tax", "Schedule 2, line 12", niit) }
    if earlyWithdrawalPenalty > 0 {
        line("earlyWithdrawal", "Additional tax on early distributions", "Schedule 2, line 8", earlyWithdrawalPenalty)
    }
    if ptc.repayment > 0 {
        line("aptcRepayment", "Excess advance premium tax credit repayment", "Schedule 2, line 2", ptc.repayment)
    }
    let totalTax = dollar(taxAfterNonrefundable + otherTaxes)
    line("totalTax", "Total tax", "Form 1040, line 24", totalTax)

    // ---- 18. Refundable credits ----
    let investmentIncome =
        gross.taxableInterest +
        gross.taxExemptInterest +
        gross.ordinaryDividends +
        nonNeg(capGains.includedInIncome)
    let eitcResult = computeEitc(
        ComputeEitcParams(
            r: r,
            earnedIncome: earnedIncome,
            agi: agi,
            investmentIncome: investmentIncome,
            taxpayerAge: ageAtEndOf2024(r.taxpayer.dateOfBirth)
        )
    )
    let eitc = eitcResult.credit
    let actc = dollar(ctc.additionalChildTaxCredit)
    var refundableCredits: [String: Double] = [:]
    if eitc > 0 { refundableCredits["earnedIncomeCredit"] = eitc }
    if actc > 0 { refundableCredits["additionalChildTaxCredit"] = actc }
    if education.refundable > 0 { refundableCredits["refundableAotc"] = education.refundable }
    if ptc.netRefundable > 0 { refundableCredits["premiumTaxCredit"] = ptc.netRefundable }
    let totalRefundableCredits = eitc + actc + education.refundable + ptc.netRefundable
    if eitc > 0 { line("eitc", "Earned income credit", "Form 1040, line 27", eitc) }
    if actc > 0 { line("actc", "Additional Child Tax Credit", "Form 1040, line 28", actc) }
    if education.refundable > 0 {
        line("refundableAotc", "Refundable American Opportunity credit", "Form 1040, line 29", education.refundable)
    }

    // ---- 19. Payments + refund/owed ----
    let pay = computeWithholdingAndPayments(r)
    let totalPayments = dollar(pay.total + totalRefundableCredits)
    line("totalPayments", "Total payments", "Form 1040, line 33", totalPayments)
    let refundOrOwed = dollar(totalPayments - totalTax)
    let owes = refundOrOwed < 0
    line(
        owes ? "amountOwed" : "refund",
        owes ? "Amount you owe" : "Refund",
        owes ? "Form 1040, line 37" : "Form 1040, line 34",
        Swift.abs(refundOrOwed)
    )

    // ---- 20. Rates ----
    let marginalRatePct = marginalRate * 100
    let effectiveRate = totalIncome > 0 ? (totalTax / totalIncome) * 100 : 0

    // ---- 20b. State income tax ----
    let stateWithholding =
        sumBy(r.income.w2, { $0.box17StateWithholding }) + r.residency.stateWithholding
    let stateResult = computeStateTax(
        StateInput(
            code: r.residency.state,
            federalAgi: agi,
            taxableSocialSecurity: taxableSS,
            retirementDistributions: gross.retirementDistributions,
            filingStatus: r.filingStatus,
            dependents: Double(r.dependents.count),
            stateWithholding: stateWithholding,
            age65: (ageAtEndOf2024(r.taxpayer.dateOfBirth) ?? 0) >= 65
        )
    )
    if let stateResult = stateResult, stateResult.hasIncomeTax, stateResult.supported {
        line("stateTax", "\(stateResult.name) state income tax", "State return", stateResult.tax)
    }

    // ---- 21. Warnings for not-yet-modeled refinements ----
    if qbi.wageLimitMayApply {
        warnings.append(Warning(
            code: "QBI_WAGE_LIMIT",
            message:
                "Your taxable income is above the QBI threshold, where the W-2 wage / property (UBIA) limit can reduce the 20% deduction. We don't track business W-2 wages, so your QBI deduction may be overstated."
        ))
    }
    if r.credits.hasMarketplaceCoverage {
        warnings.append(Warning(
            code: "PTC_SIMPLIFIED",
            message:
                "Marketplace (ACA) premium tax credit is reconciled simply here; the income-based cap on repaying excess advance payments isn't modeled."
        ))
    }
    if let disqualReason = eitcResult.disqualReason {
        warnings.append(Warning(
            code: "EITC_INELIGIBLE",
            message: "Earned Income Credit not applied: \(disqualReason)"
        ))
    }

    // ---- 22. Audit / data-quality flags ----
    if r.income.flags.hasW2 && pay.withholding == 0 && gross.wages > 0 {
        auditFlags.append(AuditFlag(
            severity: .warn,
            message:
                "You have W-2 wages but no federal tax was withheld. Double-check box 2 of your W-2(s).",
            relatedLine: "totalPayments"
        ))
    }
    if owes && totalIncome > 0 && Swift.abs(refundOrOwed) > 0.1 * totalIncome {
        auditFlags.append(AuditFlag(
            severity: .info,
            message:
                "Your balance due is large relative to your income — consider adjusting withholding or making estimated payments next year.",
            relatedLine: "amountOwed"
        ))
    }
    if schedC.totalNet > 0 && se.deduction > 0 {
        auditFlags.append(AuditFlag(
            severity: .info,
            message: "Self-employment tax of \(jsRound(seTax)) applies; half of it (\(jsRound(se.deduction))) is deducted above the line.",
            relatedLine: "seTax"
        ))
    }
    // Underpayment (Form 2210) safe-harbor check — flag only (no penalty added to the bill).
    if owes && Swift.abs(refundOrOwed) >= 1_000 {
        let safeHarborCurrent = 0.9 * totalTax
        let priorYearTax = r.payments.priorYearTax
        let safeHarborPrior: Double =
            priorYearTax != nil
                ? ((r.payments.priorYearAgi ?? 0) > 150_000 ? 1.1 : 1.0) * priorYearTax!
                : Double.infinity
        let requiredAnnualPayment = Swift.min(safeHarborCurrent, safeHarborPrior)
        if pay.withholding < requiredAnnualPayment {
            auditFlags.append(AuditFlag(
                severity: .warn,
                message:
                    "You may owe an underpayment penalty (Form 2210) — too little was paid in during the year. Consider increasing withholding or making estimated payments.",
                relatedLine: "amountOwed"
            ))
        }
    }

    return TaxCalculationResult(
        filingStatus: r.filingStatus,
        totalIncome: totalIncome,
        totalAdjustments: totalAdjustments,
        agi: agi,
        magi: magi,
        standardDeduction: dollar(deduction.standard),
        itemizedDeduction: dollar(deduction.itemized),
        deductionUsed: deduction.used,
        deductionAmount: deductionAmount,
        itemizedSavings: dollar(deduction.itemizedSavings),
        qbiDeduction: qbiDeduction,
        taxableIncomeBeforeQbi: taxableIncomeBeforeQbi,
        taxableIncome: taxableIncome,
        regularTax: regularTax,
        usedTaxTable: usedTaxTable,
        usedQualDivWorksheet: usedQualDivWorksheet,
        amt: amt,
        additionalMedicareTax: additionalMedicareTax,
        niit: niit,
        seTax: seTax,
        nonrefundableCredits: nonrefundableCredits,
        totalNonrefundableCredits: totalNonrefundableCredits,
        refundableCredits: refundableCredits,
        totalRefundableCredits: totalRefundableCredits,
        otherTaxes: otherTaxes,
        totalTax: totalTax,
        totalPayments: totalPayments,
        refundOrOwed: refundOrOwed,
        owes: owes,
        underpaymentPenalty: 0,
        marginalRate: marginalRatePct,
        effectiveRate: effectiveRate,
        capitalLossCarryover: CapitalLossCarryover(
            shortTerm: dollar(capGains.carryoverShort),
            longTerm: dollar(capGains.carryoverLong)
        ),
        trace: trace,
        warnings: warnings,
        auditFlags: auditFlags,
        state: stateResult
    )
}

/// JS `Math.round` — half up (toward +Infinity). Used only for the integer
/// amounts interpolated into the SE-tax audit-flag message, matching the TS
/// `Math.round(...)` calls. Rendered without a decimal point (whole number).
private func jsRound(_ x: Double) -> String {
    let rounded = Foundation.floor(x + 0.5)
    return String(Int(rounded))
}
