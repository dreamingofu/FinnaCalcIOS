//
//  EmergencyFundCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/emergency-fund-calculator/page.tsx` —
//  computes an emergency-fund target (months-of-expenses or a flat dollar
//  amount), progress toward it, current coverage, and the time to reach the
//  goal with compound interest (solved from the FV-of-annuity formula).
//  Follows the LoanCalculatorView exemplar and builds the UI from CalcSupport.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum EmergencyFundCalc {

    struct Output {
        let targetAmount: Double
        let currentSavings: Double
        let stillNeeded: Double
        let percentComplete: Double
        let monthsOfExpensesCovered: Double
        let timeToGoal: Double
        let monthlyContribution: Double
        let projectedInterest: Double
        let targetMonths: Double
    }

    enum Result {
        case error(String)
        case success(Output)
    }

    /// Mirrors `calculateEmergencyFund()` in the web page exactly.
    static func calculate(
        monthlyExpenses: Double,
        currentSavings: Double,
        targetType: String,
        targetValue: Double,
        monthlySavings: Double,
        interestRate: Double
    ) -> Result {
        let expenses = monthlyExpenses
        let savings = currentSavings
        let value = targetValue
        let monthlyContribution = monthlySavings
        let rate = interestRate

        if expenses <= 0 {
            return .error("Monthly expenses must be greater than 0.")
        }

        let targetAmount = targetType == "months" ? expenses * value : value
        let stillNeeded = max(0, targetAmount - savings)
        let percentComplete = targetAmount > 0 ? min(100, (savings / targetAmount) * 100) : 0

        // Time to reach goal with compound interest (solve for n in FV-of-annuity)
        var timeToGoal: Double = 0
        var projectedInterest: Double = 0
        if stillNeeded > 0 && monthlyContribution > 0 {
            let monthlyRate = rate / 100 / 12
            if monthlyRate > 0 {
                // log(1 + stillNeeded * r / PMT) / log(1 + r)
                timeToGoal = log(1 + (stillNeeded * monthlyRate) / monthlyContribution) / log(1 + monthlyRate)
            } else {
                timeToGoal = stillNeeded / monthlyContribution
            }
            timeToGoal = timeToGoal.rounded(.up)
            // Interest earned = total FV minus total contributions
            // FV ≈ stillNeeded (by definition), total contributions = PMT * timeToGoal
            projectedInterest = max(0, stillNeeded - monthlyContribution * timeToGoal)
        }

        return .success(Output(
            targetAmount: targetAmount,
            currentSavings: savings,
            stillNeeded: stillNeeded,
            percentComplete: percentComplete,
            monthsOfExpensesCovered: expenses > 0 ? savings / expenses : 0,
            timeToGoal: timeToGoal,
            monthlyContribution: monthlyContribution,
            projectedInterest: projectedInterest,
            targetMonths: targetType == "months" ? value : (expenses > 0 ? targetAmount / expenses : 0)
        ))
    }
}

// MARK: - Local accent + formatting

private extension Color {
    /// Tailwind orange-600 (`text-orange-600`, rgb 234/88/12) — "Time to Goal".
    static let calcOrange = Color(.sRGB, red: 234.0 / 255, green: 88.0 / 255, blue: 12.0 / 255, opacity: 1)
}

private enum EFFormat {
    /// `Number.toLocaleString()` with the default options — grouped, up to 3
    /// fraction digits, no forced minimum (so whole values show no decimals).
    static func localized(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        return f.string(from: NSNumber(value: value.isFinite ? value : 0)) ?? "0"
    }
}

// MARK: - View

struct EmergencyFundCalculatorView: View {
    @State private var monthlyExpenses = ""
    @State private var currentSavings = ""
    @State private var targetType = "months"
    @State private var targetValue = "6"
    @State private var monthlySavings = ""
    @State private var interestRate = "4.5"
    @State private var savingsGoal = "emergency"

    @State private var result: EmergencyFundCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "dollarsign.circle",
            title: "Emergency Fund Calculator",
            description: "Calculate your emergency fund target and how long it will take to reach it",
            calculateTitle: "Calculate Emergency Fund",
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
            CalcField(label: "Monthly Expenses ($)", placeholder: "5000", text: $monthlyExpenses)
            CalcField(label: "Current Emergency Savings ($)", placeholder: "0", text: $currentSavings)
            CalcPicker(label: "Target Type", selection: $targetType, options: [
                ("months", "Months of Expenses"),
                ("amount", "Specific Dollar Amount"),
            ])
            VStack(alignment: .leading, spacing: 6) {
                CalcField(
                    label: targetType == "months" ? "Number of Months" : "Target Amount ($)",
                    placeholder: targetType == "months" ? "6" : "30000",
                    text: $targetValue
                )
                Text(targetType == "months"
                     ? "Recommended: 3–6 months for most people"
                     : "Enter your desired fund total")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundStyle(Theme.mutedForeground)
            }
            CalcField(label: "Monthly Savings Contribution ($)", placeholder: "500", text: $monthlySavings)
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Savings Account APY (%)", placeholder: "4.5", text: $interestRate)
                Text("HYSAs currently offer 4–5% APY")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundStyle(Theme.mutedForeground)
            }
            CalcPicker(label: "Goal Type", selection: $savingsGoal, options: [
                ("emergency", "Emergency Fund"),
                ("vacation", "Vacation Fund"),
                ("home", "Home Down Payment"),
                ("car", "Car Purchase"),
                ("other", "Other Goal"),
            ])
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
                    Text("Emergency Fund Analysis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.foreground)

                    CalcGrid {
                        // Target Emergency Fund (headline, green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Target Emergency Fund")
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundStyle(Theme.mutedForeground)
                            Text("$" + EFFormat.localized(r.targetAmount))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Theme.positive)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("\(CalcFormat.fixed(r.targetMonths, 1)) months of expenses")
                                .font(.system(size: Theme.FontSize.xs))
                                .foregroundStyle(Theme.mutedForeground)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        CalcResult(
                            label: "Still Need to Save",
                            value: "$" + EFFormat.localized(r.stillNeeded),
                            color: Theme.negative
                        )

                        // Progress (blue) with bar
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Progress")
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundStyle(Theme.mutedForeground)
                            Text(CalcFormat.fixed(r.percentComplete, 1) + "%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.primary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Theme.muted)
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Theme.primary)
                                        .frame(width: geo.size.width * CGFloat(min(100, max(0, r.percentComplete)) / 100))
                                }
                            }
                            .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        CalcResult(
                            label: "Current Coverage",
                            value: "\(CalcFormat.fixed(r.monthsOfExpensesCovered, 1)) months"
                        )

                        if r.monthlyContribution > 0 && r.stillNeeded > 0 {
                            CalcResult(
                                label: "Time to Goal",
                                value: timeToGoalText(r.timeToGoal),
                                color: .calcOrange
                            )
                            CalcResult(
                                label: "Interest Earned",
                                value: "$" + CalcFormat.fixed(r.projectedInterest, 2),
                                color: Theme.positive
                            )
                        }
                    }

                    tipsCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func timeToGoalText(_ months: Double) -> String {
        let n = Int(months)
        var text = "\(n) month\(n != 1 ? "s" : "")"
        if months >= 12 {
            text += " (\(CalcFormat.fixed(months / 12, 1)) yrs)"
        }
        return text
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundStyle(Theme.foreground)
            VStack(alignment: .leading, spacing: 4) {
                tip("Keep your fund in a high-yield savings account (HYSA)")
                tip("Automate monthly contributions to stay consistent")
                tip("Only use it for true emergencies — job loss, medical, car")
                tip("Replenish it immediately after any withdrawal")
                tip("Start with a $1,000 starter fund if your goal feels far away")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.system(size: Theme.FontSize.sm))
        .foregroundStyle(Theme.mutedForeground)
    }

    private func calculate() {
        result = EmergencyFundCalc.calculate(
            monthlyExpenses: monthlyExpenses.calcValue,
            currentSavings: currentSavings.calcValue,
            targetType: targetType,
            targetValue: targetValue.calcValue,
            monthlySavings: monthlySavings.calcValue,
            interestRate: interestRate.calcValue
        )
    }
}

#Preview {
    NavigationStack { EmergencyFundCalculatorView() }
}
