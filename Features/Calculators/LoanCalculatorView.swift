//
//  LoanCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/loan-calculator/page.tsx` — four modes
//  (Payment, True APR, Loan Amount, Remaining), same formulas including the
//  Newton-Raphson APR solver (US Regulation Z). This is the exemplar the other
//  Phase 3 calculators follow.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum LoanCalc {
    /// True APR via Newton-Raphson — US Regulation Z method.
    static func computeAPR(principal: Double, interest: Double, fees: Double, termYears: Double) -> Double {
        let n = (termYears * 12).rounded()
        if n <= 0 || principal <= 0 { return 0 }
        let pmt = (principal + interest) / n
        let net = principal - fees
        if net <= 0 || pmt <= 0 { return 0 }

        var m = 0.005
        for _ in 0..<300 {
            let f = pow(1 + m, -n)
            let pv = pmt * (1 - f) / m
            let dpv = pmt * (n * f * m / ((1 + m) * m) - (1 - f)) / (m * m)
            let dm = -(pv - net) / dpv
            m += dm
            if !m.isFinite || m <= 0 { return 0 }
            if abs(dm) < 1e-10 { break }
        }
        return m * 12 * 100
    }

    enum Result {
        case error(String)
        case payment(basePayment: Double, totalPayment: Double, totalInterest: Double, principal: Double)
        case apr(apr: Double, totalCost: Double)
        case loanAmount(maxLoan: Double, payment: Double)
        case remaining(remainingBalance: Double, remainingPayments: Double, monthlyPayment: Double, totalPaid: Double)
    }

    static func payment(loanAmount: Double, downPayment: Double, interestRate: Double, loanTermMonths: Double, frequency: String) -> Result {
        let principal = loanAmount - downPayment
        let annualRate = interestRate / 100
        let termMonths = loanTermMonths

        let periods: Double
        let termPeriods: Double
        switch frequency {
        case "biweekly":  periods = 26; termPeriods = (termMonths * 26 / 12).rounded()
        case "weekly":    periods = 52; termPeriods = (termMonths * 52 / 12).rounded()
        case "quarterly": periods = 4;  termPeriods = (termMonths * 4 / 12).rounded()
        case "annually":  periods = 1;  termPeriods = (termMonths / 12).rounded()
        default:          periods = 12; termPeriods = termMonths // monthly
        }
        let rate = annualRate / periods

        if principal < 0 || termPeriods <= 0 {
            return .error("Please enter valid positive numbers for Loan Amount and Term.")
        }

        var basePayment: Double
        if rate == 0 {
            basePayment = termPeriods > 0 ? principal / termPeriods : 0
        } else {
            basePayment = (principal * rate * pow(1 + rate, termPeriods)) / (pow(1 + rate, termPeriods) - 1)
        }
        if !basePayment.isFinite { basePayment = 0 }

        return .payment(
            basePayment: basePayment,
            totalPayment: basePayment * termPeriods,
            totalInterest: basePayment * termPeriods - principal,
            principal: principal
        )
    }

    static func apr(loanAmount: Double, totalInterest: Double, fees: Double, termYears: Double) -> Result {
        if loanAmount <= 0 || termYears <= 0 { return .error("Please enter valid positive numbers") }
        let apr = computeAPR(principal: loanAmount, interest: totalInterest, fees: fees, termYears: termYears)
        return .apr(apr: apr, totalCost: totalInterest + fees)
    }

    static func loanAmount(monthlyPayment: Double, annualRate: Double, termMonths: Double) -> Result {
        let payment = monthlyPayment
        let rate = annualRate / 100 / 12
        let term = termMonths
        if payment <= 0 || term <= 0 { return .error("Please enter valid positive numbers") }
        let maxLoan = rate == 0 ? payment * term : payment * ((1 - pow(1 + rate, -term)) / rate)
        return .loanAmount(maxLoan: maxLoan, payment: payment)
    }

    static func remaining(originalAmount: Double, annualRate: Double, termMonths: Double, paymentsMade: Double) -> Result {
        let principal = originalAmount
        let rate = annualRate / 100 / 12
        let term = termMonths
        let payments = paymentsMade
        if principal <= 0 || term <= 0 || payments < 0 { return .error("Please enter valid positive numbers") }

        let pmt = rate == 0 ? principal / term : (principal * rate * pow(1 + rate, term)) / (pow(1 + rate, term) - 1)
        let balance = rate == 0
            ? principal - pmt * payments
            : principal * pow(1 + rate, payments) - pmt * ((pow(1 + rate, payments) - 1) / rate)

        return .remaining(
            remainingBalance: max(0, balance),
            remainingPayments: max(0, term - payments),
            monthlyPayment: pmt,
            totalPaid: pmt * payments
        )
    }
}

// MARK: - View

struct LoanCalculatorView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case payment, apr, loanAmount, remaining
        var id: String { rawValue }
        var tab: String {
            switch self {
            case .payment: return "Payment"
            case .apr: return "True APR"
            case .loanAmount: return "Loan Amount"
            case .remaining: return "Remaining"
            }
        }
        var calculateTitle: String {
            switch self {
            case .payment: return "Calculate Payment"
            case .apr: return "Calculate True APR"
            case .loanAmount: return "Calculate Loan Amount"
            case .remaining: return "Calculate Remaining Balance"
            }
        }
    }

    @State private var mode: Mode = .payment

    // Payment
    @State private var loanType = "personal"
    @State private var loanAmount = ""
    @State private var interestRate = ""
    @State private var loanTerm = ""
    @State private var paymentFrequency = "monthly"
    @State private var downPayment = ""

    // APR
    @State private var loanAmountAPR = ""
    @State private var totalInterestInput = ""
    @State private var fees = ""
    @State private var termAPR = ""

    // Loan amount
    @State private var monthlyPayment = ""
    @State private var rateForAmount = ""
    @State private var termForAmount = ""

    // Remaining
    @State private var originalAmount = ""
    @State private var originalRate = ""
    @State private var originalTerm = ""
    @State private var paymentsMade = ""

    @State private var result: LoanCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "banknote",
            title: "Loan Calculator",
            description: "Calculate payments, true APR (IRR method), loan amounts, and remaining balances",
            calculateTitle: mode.calculateTitle,
            onCalculate: calculate
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.tab).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _ in result = nil }

                switch mode {
                case .payment: paymentInputs
                case .apr: aprInputs
                case .loanAmount: loanAmountInputs
                case .remaining: remainingInputs
                }
            }
        } results: {
            resultView
        }
    }

    // MARK: Inputs

    private var paymentInputs: some View {
        CalcGrid {
            CalcPicker(label: "Loan Type", selection: $loanType, options: [
                ("personal", "Personal Loan"), ("business", "Business Loan"),
                ("auto", "Auto Loan"), ("mortgage", "Mortgage"), ("student", "Student Loan"),
            ])
            CalcField(label: "Loan Amount ($)", placeholder: "50000", text: $loanAmount)
            CalcField(label: "Annual Interest Rate (%)", placeholder: "5.5", text: $interestRate)
            CalcField(label: "Loan Term (months)", placeholder: "60", text: $loanTerm)
            CalcPicker(label: "Payment Frequency", selection: $paymentFrequency, options: [
                ("monthly", "Monthly (12/year)"), ("biweekly", "Bi-weekly (26/year)"),
                ("weekly", "Weekly (52/year)"), ("quarterly", "Quarterly (4/year)"),
                ("annually", "Annually (1/year)"),
            ])
            CalcField(label: "Down Payment ($)", placeholder: "0", text: $downPayment)
        }
    }

    private var aprInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcGrid {
                CalcField(label: "Loan Amount ($)", placeholder: "50000", text: $loanAmountAPR)
                CalcField(label: "Total Interest Paid ($)", placeholder: "5000", text: $totalInterestInput)
                CalcField(label: "Total Upfront Fees ($)", placeholder: "500", text: $fees)
                CalcField(label: "Loan Term (years)", placeholder: "5", text: $termAPR)
            }
            Text("APR computed using Newton-Raphson IRR to match US Regulation Z — more accurate than the simple average-cost method.")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private var loanAmountInputs: some View {
        CalcGrid {
            CalcField(label: "Monthly Payment ($)", placeholder: "500", text: $monthlyPayment)
            CalcField(label: "Annual Interest Rate (%)", placeholder: "5.5", text: $rateForAmount)
            CalcField(label: "Loan Term (months)", placeholder: "60", text: $termForAmount)
        }
    }

    private var remainingInputs: some View {
        CalcGrid {
            CalcField(label: "Original Loan Amount ($)", placeholder: "50000", text: $originalAmount)
            CalcField(label: "Annual Interest Rate (%)", placeholder: "5.5", text: $originalRate)
            CalcField(label: "Original Term (months)", placeholder: "60", text: $originalTerm)
            CalcField(label: "Payments Made", placeholder: "12", text: $paymentsMade)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            switch result {
            case .error(let message):
                CalcErrorText(text: message)
            case let .payment(basePayment, totalPayment, totalInterest, principal):
                CalcResultsSection {
                    CalcResult(label: "Payment per Period", value: CalcFormat.currency(basePayment), color: Theme.positive, emphasized: true)
                    CalcResult(label: "Total Amount Paid", value: CalcFormat.currency(totalPayment))
                    CalcResult(label: "Total Interest Cost", value: CalcFormat.currency(totalInterest), color: Theme.negative)
                    CalcResult(label: "Principal Financed", value: "$" + CalcFormat.locale(principal))
                }
            case let .apr(apr, totalCost):
                CalcResultsSection {
                    CalcResult(label: "True APR (incl. fees)", value: CalcFormat.fixed(apr, 3) + "%", color: Theme.positive, emphasized: true)
                    CalcResult(label: "Total Loan Cost", value: "$" + CalcFormat.locale(totalCost), color: Theme.negative)
                }
            case let .loanAmount(maxLoan, payment):
                CalcResultsSection {
                    CalcResult(label: "Maximum Loan Amount", value: CalcFormat.currency(maxLoan), color: Theme.positive, emphasized: true)
                    CalcResult(label: "Monthly Payment", value: "$" + CalcFormat.locale(payment))
                }
            case let .remaining(remainingBalance, remainingPayments, monthlyPayment, totalPaid):
                CalcResultsSection {
                    CalcResult(label: "Remaining Balance", value: CalcFormat.currency(remainingBalance), color: Theme.positive, emphasized: true)
                    CalcResult(label: "Payments Remaining", value: CalcFormat.raw(remainingPayments))
                    CalcResult(label: "Total Paid So Far", value: CalcFormat.currency(totalPaid))
                    CalcResult(label: "Monthly Payment", value: CalcFormat.currency(monthlyPayment))
                }
            }
        }
    }

    private func calculate() {
        switch mode {
        case .payment:
            result = LoanCalc.payment(loanAmount: loanAmount.calcValue, downPayment: downPayment.calcValue,
                                      interestRate: interestRate.calcValue, loanTermMonths: loanTerm.calcValue,
                                      frequency: paymentFrequency)
        case .apr:
            result = LoanCalc.apr(loanAmount: loanAmountAPR.calcValue, totalInterest: totalInterestInput.calcValue,
                                  fees: fees.calcValue, termYears: termAPR.calcValue)
        case .loanAmount:
            result = LoanCalc.loanAmount(monthlyPayment: monthlyPayment.calcValue, annualRate: rateForAmount.calcValue,
                                         termMonths: termForAmount.calcValue)
        case .remaining:
            result = LoanCalc.remaining(originalAmount: originalAmount.calcValue, annualRate: originalRate.calcValue,
                                        termMonths: originalTerm.calcValue, paymentsMade: paymentsMade.calcValue)
        }
    }
}

#Preview {
    NavigationStack { LoanCalculatorView() }
}
