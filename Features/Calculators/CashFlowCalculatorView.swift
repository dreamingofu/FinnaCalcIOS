//
//  CashFlowCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/cash-flow-calculator/page.tsx` — projects
//  business cash flow month-by-month with separate revenue and expense growth
//  rates, surfacing the final balance, totals, net cash flow, a cash-runway
//  warning, and a per-month breakdown. Formulas/rounding ported 1:1.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum CashFlowCalc {
    struct MonthRow: Identifiable {
        let month: Int
        let revenue: Double
        let expenses: Double
        let netCashFlow: Double
        let cumulativeCash: Double
        var id: Int { month }
    }

    struct Result {
        let projections: [MonthRow]
        let totalRevenue: Double
        let totalExpenses: Double
        let finalCash: Double
        let netCashFlow: Double
        let breakEvenMonth: Int?
        let negativeMonths: Int
    }

    /// `Number.parseInt(x) || 0` — leading integer, else 0. Used for `months`.
    static func parseInt(_ s: String) -> Int {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        var digits = ""
        var started = false
        for (i, ch) in trimmed.enumerated() {
            if ch == "-" && i == 0 { digits.append(ch); continue }
            if ch.isNumber { digits.append(ch); started = true }
            else { break }
        }
        _ = started
        return Int(digits) ?? 0
    }

    static func compute(
        monthlyRevenue: Double,
        monthlyExpenses: Double,
        startingCash: Double,
        revenueGrowthRate: Double,
        expenseGrowthRate: Double,
        monthsRaw: Int
    ) -> Result {
        let revenue = monthlyRevenue
        let expenses = monthlyExpenses
        let cash = startingCash
        let revGrowth = revenueGrowthRate
        let expGrowth = expenseGrowthRate
        // Math.min(Math.max(parseInt(months) || 12, 1), 60)
        let parsed = monthsRaw == 0 ? 12 : monthsRaw
        let period = min(max(parsed, 1), 60)

        var projections: [MonthRow] = []
        var currentCash = cash
        var currentRevenue = revenue
        var currentExpenses = expenses
        var breakEvenMonth: Int? = nil

        for month in 1...period {
            let netCashFlow = currentRevenue - currentExpenses
            currentCash += netCashFlow

            // breakEvenMonth === null && currentCash >= 0 &&
            //   (month === 1 ? cash < 0 : prev.cumulativeCash < 0)
            if breakEvenMonth == nil && currentCash >= 0 {
                let priorWasNegative: Bool
                if month == 1 {
                    priorWasNegative = cash < 0
                } else {
                    priorWasNegative = (projections.last?.cumulativeCash ?? 0) < 0
                }
                if priorWasNegative {
                    breakEvenMonth = month
                }
            }

            projections.append(MonthRow(
                month: month,
                // JS Math.round rounds half toward +∞ (floor(x+0.5)); Swift's
                // .rounded() rounds half away from zero, which differs for
                // negative .5 values (e.g. net/cumulative cash).
                revenue: (currentRevenue + 0.5).rounded(.down),
                expenses: (currentExpenses + 0.5).rounded(.down),
                netCashFlow: (netCashFlow + 0.5).rounded(.down),
                cumulativeCash: (currentCash + 0.5).rounded(.down)
            ))

            currentRevenue = currentRevenue * (1 + revGrowth / 100)
            currentExpenses = currentExpenses * (1 + expGrowth / 100)
        }

        let totalRevenue = projections.reduce(0) { $0 + $1.revenue }
        let totalExpenses = projections.reduce(0) { $0 + $1.expenses }
        let finalCash = projections.last?.cumulativeCash ?? 0
        let negativeMonths = projections.filter { $0.cumulativeCash < 0 }.count

        return Result(
            projections: projections,
            totalRevenue: totalRevenue,
            totalExpenses: totalExpenses,
            finalCash: finalCash,
            netCashFlow: totalRevenue - totalExpenses,
            breakEvenMonth: breakEvenMonth,
            negativeMonths: negativeMonths
        )
    }

    /// Web `fmtK` — `$X.Xk` for |n| >= 1000, else grouped dollars.
    static func fmtK(_ n: Double) -> String {
        if abs(n) >= 1000 {
            let sign = n < 0 ? "-" : ""
            return "\(sign)$\(CalcFormat.fixed(abs(n) / 1000, 1))k"
        } else {
            let prefix = n < 0 ? "-$" : "$"
            return "\(prefix)\(CalcFormat.int(abs(n)))"
        }
    }
}

// MARK: - View

struct CashFlowCalculatorView: View {
    @State private var monthlyRevenue = ""
    @State private var monthlyExpenses = ""
    @State private var startingCash = ""
    @State private var revenueGrowthRate = "5"
    @State private var expenseGrowthRate = "2"
    @State private var months = "12"

    @State private var result: CashFlowCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "chart.line.uptrend.xyaxis",
            title: "Cash Flow Projector",
            description: "Project business cash flow with separate revenue and expense growth rates",
            calculateTitle: "Calculate Cash Flow Projection",
            onCalculate: calculate
        ) {
            inputs
        } results: {
            resultView
        }
    }

    // MARK: Inputs

    private var inputs: some View {
        CalcGrid {
            CalcField(label: "Starting Monthly Revenue ($)", placeholder: "25000", text: $monthlyRevenue)
            CalcField(label: "Starting Monthly Expenses ($)", placeholder: "20000", text: $monthlyExpenses)
            CalcField(label: "Starting Cash Balance ($)", placeholder: "50000", text: $startingCash)
            CalcField(label: "Projection Period (months)", placeholder: "12", text: $months)
            VStack(alignment: .leading, spacing: 4) {
                CalcField(label: "Monthly Revenue Growth (%)", placeholder: "5", text: $revenueGrowthRate)
                Text("Month-over-month revenue growth rate")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            VStack(alignment: .leading, spacing: 4) {
                CalcField(label: "Monthly Expense Growth (%)", placeholder: "2", text: $expenseGrowthRate)
                Text("Month-over-month expense growth rate")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cash Flow Projection")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.foreground)

                CalcGrid {
                    CalcResult(
                        label: "Final Cash Balance",
                        value: "$" + CalcFormat.int(result.finalCash),
                        color: result.finalCash >= 0 ? Theme.positive : Theme.negative,
                        emphasized: true
                    )
                    CalcResult(
                        label: "Total Revenue",
                        value: "$" + CalcFormat.int(result.totalRevenue),
                        color: Theme.primary
                    )
                    CalcResult(
                        label: "Net Cash Flow",
                        value: "$" + CalcFormat.int(result.netCashFlow),
                        color: result.netCashFlow >= 0 ? Theme.positive : Theme.negative
                    )
                }

                if result.negativeMonths > 0 {
                    warningBox(result)
                }

                breakdown(result)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func warningBox(_ result: CashFlowCalc.Result) -> some View {
        let monthWord = result.negativeMonths != 1 ? "months" : "month"
        var message = "\u{26A0} Cash runway warning: \(result.negativeMonths) \(monthWord) with negative cumulative cash balance."
        if let breakEven = result.breakEvenMonth {
            message += " Cash turns positive in Month \(breakEven)."
        }
        return Text(message)
            .font(.system(size: Theme.FontSize.sm))
            .foregroundColor(Theme.warningText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.warningBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.warningBorder, lineWidth: 1)
            )
    }

    private func breakdown(_ result: CashFlowCalc.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.foreground)

            // Header row
            HStack(spacing: 8) {
                breakdownCell("Month", weight: .medium, color: Theme.mutedForeground)
                breakdownCell("Revenue", weight: .medium, color: Theme.mutedForeground)
                breakdownCell("Expenses", weight: .medium, color: Theme.mutedForeground)
                breakdownCell("Cash Balance", weight: .medium, color: Theme.mutedForeground)
            }
            .font(.system(size: Theme.FontSize.xs))

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(result.projections) { row in
                        let rowNegative = row.cumulativeCash < 0
                        let baseColor = rowNegative ? Theme.negative : Theme.foreground
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                breakdownCell("Month \(row.month)", color: baseColor)
                                breakdownCell(CashFlowCalc.fmtK(row.revenue), color: baseColor)
                                breakdownCell(CashFlowCalc.fmtK(row.expenses), color: baseColor)
                                breakdownCell(
                                    CashFlowCalc.fmtK(row.cumulativeCash),
                                    weight: .medium,
                                    color: rowNegative ? Theme.negative : Theme.positive
                                )
                            }
                            .font(.system(size: Theme.FontSize.sm))
                            Divider().background(Theme.border)
                        }
                    }
                }
            }
            .frame(maxHeight: 288)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func breakdownCell(_ text: String, weight: Font.Weight = .regular, color: Color) -> some View {
        Text(text)
            .fontWeight(weight)
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func calculate() {
        result = CashFlowCalc.compute(
            monthlyRevenue: monthlyRevenue.calcValue,
            monthlyExpenses: monthlyExpenses.calcValue,
            startingCash: startingCash.calcValue,
            revenueGrowthRate: revenueGrowthRate.calcValue,
            expenseGrowthRate: expenseGrowthRate.calcValue,
            monthsRaw: CashFlowCalc.parseInt(months)
        )
    }
}

// MARK: - Warning palette (web yellow-50 / yellow-200 / yellow-800)

private extension Theme {
    static let warningBackground = Color(FCColorToken(light: (54.9, 96.7, 88), dark: (60, 90, 8)))
    static let warningBorder     = Color(FCColorToken(light: (52.8, 98.3, 76.9), dark: (48, 70, 24)))
    static let warningText       = Color(FCColorToken(light: (28.4, 72.5, 33.5), dark: (50, 97, 70)))
}

#Preview {
    NavigationStack { CashFlowCalculatorView() }
}
