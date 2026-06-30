//
//  ProfitMarginCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/profit-margin-calculator/page.tsx` —
//  computes gross, operating (EBIT), pre-tax (EBT), and net profit margins from a
//  simple income statement, plus a full income-statement breakdown and static
//  industry benchmarks. Built on the shared CalcSupport toolkit.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum ProfitMarginCalc {
    struct Output {
        let totalRevenue: Double
        let grossProfit: Double
        let operatingIncome: Double
        let ebt: Double
        let netProfit: Double
        let grossMargin: Double
        let operatingMargin: Double
        let ebtMargin: Double
        let netMargin: Double
        let cogs: Double
        let opex: Double
        let interest: Double
        let taxes: Double
    }

    enum Result {
        case error(String)
        case success(Output)
    }

    static func calculate(revenue: Double, costOfGoodsSold: Double, operatingExpenses: Double,
                          interestExpenses: Double, taxExpenses: Double) -> Result {
        let totalRevenue = revenue
        let cogs = costOfGoodsSold
        let opex = operatingExpenses
        let interest = interestExpenses
        let taxes = taxExpenses

        if totalRevenue <= 0 {
            return .error("Revenue must be greater than 0.")
        }

        let grossProfit = totalRevenue - cogs
        let operatingIncome = grossProfit - opex
        let ebt = operatingIncome - interest
        let netProfit = ebt - taxes

        return .success(Output(
            totalRevenue: totalRevenue,
            grossProfit: grossProfit,
            operatingIncome: operatingIncome,
            ebt: ebt,
            netProfit: netProfit,
            grossMargin: (grossProfit / totalRevenue) * 100,
            operatingMargin: (operatingIncome / totalRevenue) * 100,
            ebtMargin: (ebt / totalRevenue) * 100,
            netMargin: (netProfit / totalRevenue) * 100,
            cogs: cogs,
            opex: opex,
            interest: interest,
            taxes: taxes
        ))
    }

    // MARK: Web formatting helpers

    /// `n.toFixed(2)%`
    static func pct(_ n: Double) -> String { CalcFormat.fixed(n, 2) + "%" }

    /// `$` + `toLocaleString({ min: 0, max: 0 })`
    static func dollar(_ n: Double) -> String { "$" + CalcFormat.int(n) }

    /// `n >= 0 ? green : red`
    static func color(_ n: Double) -> Color { n >= 0 ? Theme.positive : Theme.negative }
}

// MARK: - View

struct ProfitMarginCalculatorView: View {
    @State private var revenue = ""
    @State private var costOfGoodsSold = ""
    @State private var operatingExpenses = ""
    @State private var interestExpenses = ""
    @State private var taxExpenses = ""

    @State private var result: ProfitMarginCalc.Result?

    private struct Benchmark: Identifiable {
        let name: String
        let gross: String
        let net: String
        var id: String { name }
    }

    private let benchmarks: [Benchmark] = [
        Benchmark(name: "Retail", gross: "20–50%", net: "2–6%"),
        Benchmark(name: "Software / SaaS", gross: "70–90%", net: "15–25%"),
        Benchmark(name: "Restaurant", gross: "60–70%", net: "3–7%"),
        Benchmark(name: "Manufacturing", gross: "25–40%", net: "5–10%"),
        Benchmark(name: "Consulting", gross: "60–75%", net: "15–25%"),
        Benchmark(name: "E-commerce", gross: "30–50%", net: "3–8%"),
    ]

    var body: some View {
        CalculatorScaffold(
            icon: "chart.line.uptrend.xyaxis",
            title: "Profit Margin Calculator",
            description: "Calculate gross, operating, EBT, and net profit margins with a full income statement breakdown",
            calculateTitle: "Calculate Profit Margins",
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
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Total Revenue ($)", placeholder: "100000", text: $revenue)
                hint("Total sales revenue for the period")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Cost of Goods Sold (COGS) ($)", placeholder: "60000", text: $costOfGoodsSold)
                hint("Direct costs to produce goods/services")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Operating Expenses ($)", placeholder: "20000", text: $operatingExpenses)
                hint("Rent, salaries, marketing, G&A")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Interest Expenses ($)", placeholder: "2000", text: $interestExpenses)
                hint("Loan interest and financing costs")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Income Tax Expense ($)", placeholder: "3000", text: $taxExpenses)
                hint("Actual taxes paid this period")
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.xs))
            .foregroundStyle(Theme.mutedForeground)
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            switch result {
            case .error(let message):
                CalcErrorText(text: message)
            case .success(let r):
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profit Margin Analysis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.foreground)

                    marginGrid(r)
                    incomeStatement(r)
                    industryBenchmarks
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // The four margin headlines. Gross is the big text-3xl figure; the rest text-2xl.
    private func marginGrid(_ r: ProfitMarginCalc.Output) -> some View {
        CalcGrid {
            marginCell(
                label: "Gross Profit Margin",
                margin: r.grossMargin,
                emphasized: true,
                sublabel: "\(ProfitMarginCalc.dollar(r.grossProfit)) gross profit"
            )
            marginCell(
                label: "Operating Margin (EBIT)",
                margin: r.operatingMargin,
                sublabel: ProfitMarginCalc.dollar(r.operatingIncome)
            )
            marginCell(
                label: "Pre-Tax Margin (EBT)",
                margin: r.ebtMargin,
                sublabel: ProfitMarginCalc.dollar(r.ebt)
            )
            marginCell(
                label: "Net Profit Margin",
                margin: r.netMargin,
                sublabel: ProfitMarginCalc.dollar(r.netProfit)
            )
        }
    }

    // A margin figure (color-coded percentage) plus a muted dollar sub-line.
    private func marginCell(label: String, margin: Double, emphasized: Bool = false, sublabel: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CalcResult(
                label: label,
                value: ProfitMarginCalc.pct(margin),
                color: ProfitMarginCalc.color(margin),
                emphasized: emphasized
            )
            Text(sublabel)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Full income statement breakdown (web `bg-muted/40` block) with conditional rows.
    private func incomeStatement(_ r: ProfitMarginCalc.Output) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income Statement")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundStyle(Theme.foreground)

            VStack(spacing: 8) {
                statementRow(label: "Revenue",
                             value: ProfitMarginCalc.dollar(r.totalRevenue),
                             valueWeight: .semibold)
                statementRow(label: "− COGS",
                             value: "(\(ProfitMarginCalc.dollar(r.cogs)))",
                             muted: true)
                statementRow(label: "Gross Profit",
                             value: ProfitMarginCalc.dollar(r.grossProfit),
                             labelWeight: .medium,
                             valueWeight: .semibold,
                             valueColor: ProfitMarginCalc.color(r.grossProfit),
                             topBorder: true)
                statementRow(label: "− Operating Expenses",
                             value: "(\(ProfitMarginCalc.dollar(r.opex)))",
                             muted: true)
                statementRow(label: "Operating Income (EBIT)",
                             value: ProfitMarginCalc.dollar(r.operatingIncome),
                             labelWeight: .medium,
                             valueWeight: .semibold,
                             valueColor: ProfitMarginCalc.color(r.operatingIncome),
                             topBorder: true)
                if r.interest > 0 {
                    statementRow(label: "− Interest Expenses",
                                 value: "(\(ProfitMarginCalc.dollar(r.interest)))",
                                 muted: true)
                }
                if r.interest > 0 || r.taxes > 0 {
                    statementRow(label: "Pre-Tax Income (EBT)",
                                 value: ProfitMarginCalc.dollar(r.ebt),
                                 labelWeight: .medium,
                                 valueWeight: .semibold,
                                 valueColor: ProfitMarginCalc.color(r.ebt),
                                 topBorder: true)
                }
                if r.taxes > 0 {
                    statementRow(label: "− Income Tax",
                                 value: "(\(ProfitMarginCalc.dollar(r.taxes)))",
                                 muted: true)
                }
                statementRow(label: "Net Profit",
                             value: ProfitMarginCalc.dollar(r.netProfit),
                             labelWeight: .semibold,
                             valueWeight: .bold,
                             valueColor: ProfitMarginCalc.color(r.netProfit),
                             topBorder: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func statementRow(label: String,
                              value: String,
                              labelWeight: Font.Weight = .regular,
                              valueWeight: Font.Weight = .regular,
                              valueColor: Color? = nil,
                              muted: Bool = false,
                              topBorder: Bool = false) -> some View {
        VStack(spacing: 0) {
            if topBorder {
                Divider().overlay(Theme.border)
                    .padding(.bottom, 4)
            }
            HStack {
                Text(label)
                    .font(.system(size: Theme.FontSize.sm, weight: labelWeight))
                    .foregroundStyle(muted ? Theme.mutedForeground : Theme.foreground)
                Spacer()
                Text(value)
                    .font(.system(size: Theme.FontSize.sm, weight: valueWeight))
                    .foregroundStyle(valueColor ?? (muted ? Theme.mutedForeground : Theme.foreground))
            }
        }
    }

    // Static industry benchmarks (web `grid grid-cols-3`).
    private var industryBenchmarks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Industry Benchmarks")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundStyle(Theme.foreground)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: 3),
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(benchmarks) { b in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name)
                            .font(.system(size: Theme.FontSize.sm, weight: .medium))
                            .foregroundStyle(Theme.foreground)
                        Text("Gross: \(b.gross)")
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundStyle(Theme.mutedForeground)
                        Text("Net: \(b.net)")
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func calculate() {
        result = ProfitMarginCalc.calculate(
            revenue: revenue.calcValue,
            costOfGoodsSold: costOfGoodsSold.calcValue,
            operatingExpenses: operatingExpenses.calcValue,
            interestExpenses: interestExpenses.calcValue,
            taxExpenses: taxExpenses.calcValue
        )
    }
}

#Preview {
    NavigationStack { ProfitMarginCalculatorView() }
}
