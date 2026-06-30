//
//  ROICalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/roi-calculator/page.tsx`. Computes simple
//  ROI / CAGR, real (inflation-adjusted) ROI via the Fisher equation, dividend
//  income, and after-tax returns. Built from the shared CalcSupport toolkit so
//  it matches the other Phase 3 calculators.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum ROICalc {
    struct Output {
        let totalReturn: Double
        let simpleROI: Double
        let cagr: Double
        let displayedROI: Double
        let initial: Double
        let final: Double
        let time: Double
        let dividendIncome: Double
        let afterTaxReturn: Double
        let realROI: Double
        let realValue: Double
        let totalTaxes: Double
    }

    enum Result {
        case error(String)
        case success(Output)
    }

    static func calculate(
        initialInvestment: String,
        finalValue: String,
        timeHorizon: String,
        calculationType: String,
        dividendYield: String,
        inflationRate: String,
        taxRate: String
    ) -> Result {
        let initial = Double(initialInvestment.trimmingCharacters(in: .whitespaces)) ?? 0
        let final = Double(finalValue.trimmingCharacters(in: .whitespaces)) ?? 0
        // `Number.parseFloat(timeHorizon) || 1` — empty/invalid defaults to 1.
        let timeParsed = Double(timeHorizon.trimmingCharacters(in: .whitespaces)) ?? 0
        let time = timeParsed != 0 ? timeParsed : 1
        let dividend = Double(dividendYield.trimmingCharacters(in: .whitespaces)) ?? 0
        let inflation = Double(inflationRate.trimmingCharacters(in: .whitespaces)) ?? 0
        let tax = Double(taxRate.trimmingCharacters(in: .whitespaces)) ?? 0

        if initial <= 0 {
            return .error("Initial investment must be greater than 0")
        }

        let totalReturn = final - initial
        let simpleROI = (totalReturn / initial) * 100

        // CAGR — correct annualized ROI
        let cagr = time > 0 ? (pow(final / initial, 1 / time) - 1) * 100 : simpleROI

        let displayedROI = calculationType == "annualized" ? cagr : simpleROI

        // Dividend income
        let annualDividendIncome = initial * (dividend / 100)
        let totalDividendIncome = annualDividendIncome * time

        // After-tax returns
        let capitalGainsTax = totalReturn > 0 ? totalReturn * (tax / 100) : 0
        let dividendTax = totalDividendIncome * (tax / 100)
        let afterTaxReturn = totalReturn + totalDividendIncome - capitalGainsTax - dividendTax

        // Fisher equation for real ROI (inflation-adjusted) — more accurate than simple subtraction
        let realROI = ((1 + cagr / 100) / (1 + inflation / 100) - 1) * 100
        let realValue = initial * pow(1 + realROI / 100, time)

        return .success(Output(
            totalReturn: totalReturn,
            simpleROI: simpleROI,
            cagr: cagr,
            displayedROI: displayedROI,
            initial: initial,
            final: final,
            time: time,
            dividendIncome: totalDividendIncome,
            afterTaxReturn: afterTaxReturn,
            realROI: realROI,
            realValue: realValue,
            totalTaxes: capitalGainsTax + dividendTax
        ))
    }
}

// MARK: - View

struct ROICalculatorView: View {
    @State private var calculationType = "annualized"
    @State private var investmentType = "stocks"
    @State private var initialInvestment = ""
    @State private var finalValue = ""
    @State private var timeHorizon = ""
    @State private var dividendYield = "0"
    @State private var inflationRate = "3.0"
    @State private var taxRate = "20"

    @State private var result: ROICalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "chart.pie",
            title: "Return on Investment (ROI) Calculator",
            description: "Calculate the return on your investments and business projects",
            calculateTitle: "Calculate ROI",
            onCalculate: calculate
        ) {
            CalcGrid {
                CalcPicker(label: "Calculation Type", selection: $calculationType, options: [
                    ("simple", "Simple ROI (total %)"),
                    ("annualized", "Annualized ROI / CAGR"),
                ])
                CalcPicker(label: "Investment Type", selection: $investmentType, options: [
                    ("stocks", "Stocks / ETFs"),
                    ("realestate", "Real Estate"),
                    ("business", "Business Investment"),
                    ("bonds", "Bonds"),
                    ("crypto", "Cryptocurrency"),
                    ("other", "Other"),
                ])
                CalcField(label: "Initial Investment ($)", placeholder: "10000", text: $initialInvestment)
                CalcField(label: "Final Value ($)", placeholder: "15000", text: $finalValue)
                CalcField(label: "Time Period (years)", placeholder: "5", text: $timeHorizon)
                CalcField(label: "Annual Dividend / Income Yield (%)", placeholder: "2.0", text: $dividendYield)
                CalcField(label: "Expected Inflation Rate (%)", placeholder: "3.0", text: $inflationRate)
                CalcField(label: "Tax Rate on Gains (%)", placeholder: "20", text: $taxRate)
            }
        } results: {
            resultView
        }
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
                    Text("ROI Analysis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CalcGrid {
                        CalcResult(
                            label: calculationType == "annualized" ? "CAGR (Annualized ROI)" : "Simple ROI (Total)",
                            value: CalcFormat.fixed(r.displayedROI, 2) + "%",
                            color: r.displayedROI >= 0 ? Theme.positive : Theme.negative,
                            emphasized: true
                        )
                        CalcResult(
                            label: "Total Return",
                            value: "$" + CalcFormat.int(r.totalReturn),
                            color: r.totalReturn >= 0 ? Theme.positive : Theme.negative
                        )
                        CalcResult(
                            label: "Real ROI (inflation-adjusted, Fisher eq.)",
                            value: CalcFormat.fixed(r.realROI, 2) + "%",
                            color: r.realROI >= 0 ? Theme.primary : Theme.negative
                        )
                        CalcResult(
                            label: "After-Tax Return",
                            value: CalcFormat.currency(r.afterTaxReturn),
                            color: r.afterTaxReturn >= 0 ? Theme.primary : Theme.negative
                        )
                    }

                    fullSummary(r)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func fullSummary(_ r: ROICalc.Output) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Summary")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundStyle(Theme.foreground)

            VStack(spacing: 8) {
                summaryRow("Initial Investment", "$" + CalcFormat.locale(r.initial))
                summaryRow("Final Value", "$" + CalcFormat.locale(r.final))
                summaryRow("Dividend Income", CalcFormat.currency(r.dividendIncome))
                summaryRow("Total Taxes", CalcFormat.currency(r.totalTaxes), valueColor: Theme.negative)
                summaryRow("Real Value (today's $)", CalcFormat.currency(r.realValue))
                summaryRow("Investment Period", "\(jsNumber(r.time)) yr\(r.time != 1 ? "s" : "")")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func summaryRow(_ label: String, _ value: String, valueColor: Color = Theme.foreground) -> some View {
        HStack {
            Text(label)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
            Spacer()
            Text(value)
                .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    /// Mirrors JS `${number}` string coercion: integers render without a
    /// decimal point, non-integers keep their fractional digits.
    private func jsNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        var s = String(value)
        if s.hasSuffix(".0") { s.removeLast(2) }
        return s
    }

    private func calculate() {
        result = ROICalc.calculate(
            initialInvestment: initialInvestment,
            finalValue: finalValue,
            timeHorizon: timeHorizon,
            calculationType: calculationType,
            dividendYield: dividendYield,
            inflationRate: inflationRate,
            taxRate: taxRate
        )
    }
}

#Preview {
    NavigationStack { ROICalculatorView() }
}
