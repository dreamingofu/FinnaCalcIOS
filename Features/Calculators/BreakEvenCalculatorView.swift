//
//  BreakEvenCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/break-even-calculator/page.tsx` — standard
//  CVP break-even analysis with a target net-profit-margin solve, seasonality
//  adjustment, and a margin-of-safety figure. Same formulas, rounding (Math.ceil
//  on unit counts), validation strings, defaults, placeholders, and labels.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum BreakEvenCalc {
    struct Output {
        let breakEvenUnits: Double          // Math.ceil
        let breakEvenRevenue: Double
        let contributionMargin: Double
        let contributionMarginRatio: Double
        let unitsForTargetProfit: Double?   // Math.ceil, nil when not achievable
        let targetProfitRevenue: Double
        let seasonalBreakEven: Double        // Math.ceil
        let seasonalTargetUnits: Double?     // Math.ceil, nil when not achievable
        let marginOfSafety: Double
        let adjustedCMValid: Bool
    }

    enum Result {
        case error(String)
        case success(Output)
    }

    static func calculate(fixedCosts: Double,
                          variableCostPerUnit: Double,
                          pricePerUnit: Double,
                          seasonalityFactor: Double,
                          targetProfitMargin: Double) -> Result {
        let fixed = fixedCosts
        let variableCost = variableCostPerUnit
        let price = pricePerUnit
        let seasonality = seasonalityFactor
        let targetMargin = targetProfitMargin

        if price <= variableCost {
            return .error("Selling price must be greater than variable cost per unit.")
        }
        if targetMargin >= 100 {
            return .error("Target profit margin must be less than 100%.")
        }

        let contributionMargin = price - variableCost
        let contributionMarginRatio = (contributionMargin / price) * 100

        // Standard CVP break-even
        let breakEvenUnits = fixed / contributionMargin
        let breakEvenRevenue = breakEvenUnits * price

        // Units for target net profit margin on revenue (standard accounting definition)
        // Profit = (price - vc) * units - fixed = price * units * (margin / 100)
        // => units * (price - vc - price * margin/100) = fixed
        // => units * (price * (1 - margin/100) - vc) = fixed
        let adjustedCM = price * (1 - targetMargin / 100) - variableCost
        var unitsForTargetProfit = 0.0
        var targetProfitRevenueAmount = 0.0
        if adjustedCM > 0 {
            unitsForTargetProfit = fixed / adjustedCM
            targetProfitRevenueAmount = unitsForTargetProfit * price
        }

        // Seasonality adjustments
        let seasonalFactor = 1 + seasonality / 100
        let seasonalBreakEven = breakEvenUnits * seasonalFactor
        let seasonalTargetUnits = unitsForTargetProfit * seasonalFactor

        // Margin of safety = how much above break-even the target is, as % of target
        let marginOfSafety = unitsForTargetProfit > 0
            ? ((unitsForTargetProfit - breakEvenUnits) / unitsForTargetProfit) * 100
            : 0

        return .success(Output(
            breakEvenUnits: breakEvenUnits.rounded(.up),
            breakEvenRevenue: breakEvenRevenue,
            contributionMargin: contributionMargin,
            contributionMarginRatio: contributionMarginRatio,
            unitsForTargetProfit: unitsForTargetProfit > 0 ? unitsForTargetProfit.rounded(.up) : nil,
            targetProfitRevenue: targetProfitRevenueAmount,
            seasonalBreakEven: seasonalBreakEven.rounded(.up),
            seasonalTargetUnits: unitsForTargetProfit > 0 ? seasonalTargetUnits.rounded(.up) : nil,
            marginOfSafety: marginOfSafety,
            adjustedCMValid: adjustedCM > 0
        ))
    }
}

// MARK: - View

struct BreakEvenCalculatorView: View {
    @State private var fixedCosts = ""
    @State private var variableCostPerUnit = ""
    @State private var pricePerUnit = ""
    @State private var salesMix = "single"
    @State private var seasonalityFactor = "0"
    @State private var targetProfitMargin = "20"

    @State private var result: BreakEvenCalc.Result?

    // "services" for a service business, otherwise "units" (web `unitLabel`).
    private var unitLabel: String { salesMix == "service" ? "services" : "units" }
    // Singular noun used in the per-unit field labels (web `Service`/`Unit`).
    private var unitNoun: String { salesMix == "service" ? "Service" : "Unit" }

    // Capitalize first letter (web `cap`).
    private func cap(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    var body: some View {
        CalculatorScaffold(
            icon: "chart.line.uptrend.xyaxis",
            title: "Break-Even Point Calculator",
            description: "Calculate how many \(unitLabel) you need to sell to break even and hit profit targets",
            calculateTitle: "Calculate Break-Even Point",
            onCalculate: calculate
        ) {
            CalcGrid {
                fixedCostsField
                variableCostField
                priceField
                businessTypePicker
                targetMarginField
                seasonalityField
            }
        } results: {
            resultView
        }
    }

    // MARK: Inputs

    private var fixedCostsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CalcField(label: "Fixed Costs per Month ($)", placeholder: "10000", text: $fixedCosts)
            Text("Rent, salaries, insurance, etc.")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private var variableCostField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CalcField(label: "Variable Cost per \(unitNoun) ($)", placeholder: "25", text: $variableCostPerUnit)
            Text("Materials, direct labor per unit")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private var priceField: some View {
        CalcField(label: "Selling Price per \(unitNoun) ($)", placeholder: "50", text: $pricePerUnit)
    }

    private var businessTypePicker: some View {
        CalcPicker(label: "Business Type", selection: $salesMix, options: [
            ("single", "Single Product"),
            ("multiple", "Multiple Products"),
            ("service", "Service Business"),
        ])
    }

    private var targetMarginField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CalcField(label: "Target Net Profit Margin (%)", placeholder: "20", text: $targetProfitMargin)
            Text("% of revenue you want as net profit")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private var seasonalityField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CalcField(label: "Seasonality Adjustment (%)", placeholder: "0", text: $seasonalityFactor)
            Text("+ for peak season, − for off-season")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
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
                successView(r)
            }
        }
    }

    @ViewBuilder
    private func successView(_ r: BreakEvenCalc.Output) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break-Even Analysis")
                .font(Theme.sans(18, weight: .semibold))
                .foregroundStyle(Theme.foreground)

            CalcGrid {
                CalcResult(
                    label: "Break-Even \(cap(unitLabel))",
                    value: "\(CalcFormat.int(r.breakEvenUnits)) \(unitLabel)",
                    color: Theme.positive,
                    emphasized: true
                )
                CalcResult(
                    label: "Break-Even Revenue",
                    value: "$" + CalcFormat.int(r.breakEvenRevenue),
                    color: Theme.primary
                )
                CalcResult(
                    label: "Contribution Margin / unit",
                    value: "$" + CalcFormat.fixed(r.contributionMargin, 2)
                )
                CalcResult(
                    label: "Contribution Margin Ratio",
                    value: CalcFormat.fixed(r.contributionMarginRatio, 1) + "%"
                )

                if r.adjustedCMValid, let units = r.unitsForTargetProfit {
                    CalcResult(
                        label: "\(cap(unitLabel)) for \(targetProfitMargin)% Net Margin",
                        value: "\(CalcFormat.int(units)) \(unitLabel)",
                        color: Theme.positive
                    )
                    CalcResult(
                        label: "Revenue for Target Margin",
                        value: "$" + CalcFormat.int(r.targetProfitRevenue),
                        color: Theme.positive
                    )
                    CalcResult(
                        label: "Margin of Safety",
                        value: CalcFormat.fixed(r.marginOfSafety, 1) + "%",
                        color: Theme.negative
                    )
                }

                if seasonalityFactor.calcValue != 0 {
                    CalcResult(
                        label: "Seasonal Break-Even",
                        value: "\(CalcFormat.int(r.seasonalBreakEven)) \(unitLabel)"
                    )
                    if let seasonalTarget = r.seasonalTargetUnits {
                        CalcResult(
                            label: "Seasonal Target \(cap(unitLabel))",
                            value: "\(CalcFormat.int(seasonalTarget)) \(unitLabel)"
                        )
                    }
                }
            }

            summaryText(r)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func summaryText(_ r: BreakEvenCalc.Output) -> some View {
        let serviceOrUnit = salesMix == "service" ? "service" : "unit"
        let base = "You need to sell \(CalcFormat.int(r.breakEvenUnits)) \(unitLabel) to cover all fixed costs. "
            + "Each \(serviceOrUnit) contributes $\(CalcFormat.fixed(r.contributionMargin, 2)) toward fixed costs "
            + "(\(CalcFormat.fixed(r.contributionMarginRatio, 1))% of price)."
        let tail: String = {
            if r.adjustedCMValid, let units = r.unitsForTargetProfit {
                return " To achieve a \(targetProfitMargin)% net profit margin, sell \(CalcFormat.int(units)) \(unitLabel)."
            } else {
                return " Target margin is unachievable at this price and cost structure — reduce costs or raise price."
            }
        }()

        Text(base + tail)
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundStyle(Theme.foreground.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.muted.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func calculate() {
        result = BreakEvenCalc.calculate(
            fixedCosts: fixedCosts.calcValue,
            variableCostPerUnit: variableCostPerUnit.calcValue,
            pricePerUnit: pricePerUnit.calcValue,
            seasonalityFactor: seasonalityFactor.calcValue,
            targetProfitMargin: targetProfitMargin.calcValue
        )
    }
}

#Preview {
    NavigationStack { BreakEvenCalculatorView() }
}
