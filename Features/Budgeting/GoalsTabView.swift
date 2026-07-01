//
//  GoalsTabView.swift
//  FinnaCalcIOS
//
//  The "Savings Goals" tab of the Budget Planner, ported from the `goals`
//  TabsContent in `../FinnaCalc/app/budgeting/page.tsx`.
//
//  Each SavingsGoal renders as a card with a progress bar and per-goal math:
//      progress       = currentAmount / targetAmount * 100
//      remaining      = targetAmount - currentAmount
//      daysLeft       = differenceInDays(targetDate, today)
//      monthsLeft     = daysLeft > 0 ? ceil(daysLeft / 30.44) : 0
//      neededPerMonth = monthsLeft > 0 ? remaining / monthsLeft : remaining
//
//  "Add Funds" opens a sheet that calls store.addFunds(to:amount:). The inline
//  "Add Goal" form calls store.addGoal. Goals delete via a trash button or swipe.
//

import SwiftUI

struct GoalsTabView: View {
    @EnvironmentObject var store: BudgetStore

    // Inline add-goal form (mirrors the web: shown once targetDate is set).
    @State private var showAddForm = false
    @State private var newName = ""
    @State private var newTargetAmount = ""
    @State private var newCurrentAmount = ""
    @State private var newMonthlyContribution = ""
    @State private var newTargetDate = Date()

    // Add-funds sheet.
    @State private var fundsGoal: SavingsGoal?

    // ISO yyyy-MM-dd <-> Date, matching the web's stored targetDate format.
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current // local midnight, matching date-fns parseISO
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // "PPP" long date, e.g. "June 30, 2026".
    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current // local midnight, matching date-fns parseISO
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    var body: some View {
        FCCard {
            FCCardHeader {
                HStack(alignment: .center) {
                    FCCardTitle("Savings Goals")
                    Spacer(minLength: 8)
                    FCButton(size: .sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Add Goal")
                        }
                    } action: {
                        startAddingGoal()
                    }
                }
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 16) {
                    if showAddForm {
                        addGoalForm
                    }

                    if store.goals.isEmpty {
                        Text("No savings goals yet. Add one to start tracking!")
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.goals) { goal in
                                goalCard(goal)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $fundsGoal) { goal in
            AddFundsSheet(goal: goal) { amount in
                store.addFunds(to: goal, amount: amount)
            }
            .environmentObject(store)
        }
    }

    // MARK: - Add Goal form

    private var addGoalForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Savings Goal")
                .font(Theme.sans(Theme.FontSize.xl2 - 4, weight: .semibold))
                .foregroundColor(Theme.foreground)

            field(label: "Goal Name") {
                FCTextField("e.g., New Car Fund, Down Payment", text: $newName)
            }
            field(label: "Target Amount ($)") {
                FCTextField("0.00", text: $newTargetAmount, keyboardType: .decimalPad)
            }
            field(label: "Current Amount Saved ($)") {
                FCTextField("0.00", text: $newCurrentAmount, keyboardType: .decimalPad)
            }
            field(label: "Planned Monthly Contribution ($)") {
                FCTextField("0.00", text: $newMonthlyContribution, keyboardType: .decimalPad)
            }
            field(label: "Target Date") {
                DatePicker("", selection: $newTargetDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Theme.primary)
            }

            HStack(spacing: 8) {
                FCButton(variant: .outline) {
                    Text("Cancel").frame(maxWidth: .infinity)
                } action: {
                    cancelAddingGoal()
                }
                FCButton {
                    Text("Add Goal").frame(maxWidth: .infinity)
                } action: {
                    addGoal()
                }
            }
        }
        .padding(16)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.foreground)
            content()
        }
    }

    // MARK: - Goal card

    @ViewBuilder
    private func goalCard(_ goal: SavingsGoal) -> some View {
        let metrics = GoalMetrics(goal: goal)

        VStack(alignment: .leading, spacing: 8) {
            // Title + actions
            HStack(alignment: .center) {
                Text(goal.name)
                    .font(Theme.sans(Theme.FontSize.xl2 - 6, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    FCButton("Add Funds", variant: .outline, size: .sm) {
                        fundsGoal = goal
                    }
                    FCButton(variant: .ghost, size: .sm) {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.negative)
                    } action: {
                        store.deleteGoal(goal)
                    }
                }
            }

            // Target / Saved
            HStack {
                Text("Target: " + CalcFormat.currency(goal.targetAmount, fraction: 2))
                Spacer(minLength: 8)
                Text("Saved: " + CalcFormat.currency(goal.currentAmount, fraction: 2))
            }
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundColor(Theme.mutedForeground)

            // Progress bar (clamped to 0...1)
            ProgressView(value: min(max(metrics.progress / 100, 0), 1))
                .tint(Theme.primary)
                .padding(.bottom, 2)

            // Remaining / Goal reached
            Group {
                if metrics.progress < 100 {
                    (Text("Remaining: ")
                        + Text(CalcFormat.currency(metrics.remaining, fraction: 2))
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.negative))
                } else {
                    Text("Goal Reached!")
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.positive)
                }
            }
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundColor(Theme.mutedForeground)

            // Detail lines (only while incomplete), mirroring the web.
            if metrics.progress < 100 {
                VStack(alignment: .leading, spacing: 4) {
                    if metrics.daysLeft > 0 {
                        Text("Target Date: \(Self.longFormatter.string(from: metrics.targetDate)) (\(metrics.daysLeft) days left)")
                    }
                    if metrics.monthsLeft > 0 && metrics.remaining > 0 {
                        Text("To reach target by date, need to save: ")
                            + Text(CalcFormat.currency(metrics.neededPerMonth, fraction: 2) + "/month")
                                .fontWeight(.semibold)
                    }
                    if goal.monthlyContribution > 0 {
                        Text("Your planned monthly contribution: ")
                            + Text(CalcFormat.currency(goal.monthlyContribution, fraction: 2))
                                .fontWeight(.semibold)
                    }
                    if goal.monthlyContribution > 0,
                       metrics.neededPerMonth > 0,
                       goal.monthlyContribution < metrics.neededPerMonth {
                        warningAlert
                    }
                }
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(16)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // Destructive Alert shown when the planned contribution falls short.
    private var warningAlert: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text("Warning").fontWeight(.semibold)
            }
            .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
            Text("Your planned monthly contribution is less than what's needed to reach your goal by the target date!")
                .font(Theme.sans(Theme.FontSize.sm))
        }
        .foregroundColor(Theme.negative)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.negative.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.negative.opacity(0.5), lineWidth: 1)
        )
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func startAddingGoal() {
        newTargetDate = Date()   // web seeds targetDate to today to reveal the form
        showAddForm = true
    }

    private func cancelAddingGoal() {
        resetForm()
    }

    private func addGoal() {
        // Web requires name && targetAmount before adding.
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty,
              !newTargetAmount.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let goal = SavingsGoal(
            id: store.newItemID(),
            name: newName,
            targetAmount: newTargetAmount.calcValue,
            currentAmount: newCurrentAmount.calcValue,
            targetDate: Self.isoFormatter.string(from: newTargetDate),
            monthlyContribution: newMonthlyContribution.calcValue
        )
        store.addGoal(goal)
        resetForm()
    }

    private func resetForm() {
        showAddForm = false
        newName = ""
        newTargetAmount = ""
        newCurrentAmount = ""
        newMonthlyContribution = ""
        newTargetDate = Date()
    }
}

// MARK: - Per-goal math

/// Computes the savings-goal metrics exactly as the web component does.
private struct GoalMetrics {
    let progress: Double
    let remaining: Double
    let daysLeft: Int
    let monthsLeft: Int
    let neededPerMonth: Double
    let targetDate: Date

    init(goal: SavingsGoal) {
        let target = goal.targetAmount
        let current = goal.currentAmount
        // Web computes current/target*100, which is +Infinity (≥100 → "Goal
        // Reached!") when target is 0 but something is saved.
        progress = target != 0 ? current / target * 100 : (current > 0 ? .infinity : 0)
        remaining = target - current

        let parsed = GoalMetrics.parseISO(goal.targetDate)
        targetDate = parsed ?? Date()

        if let parsed = parsed {
            // differenceInDays(targetDate, now): whole days between, truncated.
            let cal = Calendar(identifier: .gregorian)
            let days = cal.dateComponents([.day], from: Date(), to: parsed).day ?? 0
            daysLeft = days
        } else {
            daysLeft = 0
        }

        monthsLeft = daysLeft > 0 ? Int(ceil(Double(daysLeft) / 30.44)) : 0
        neededPerMonth = monthsLeft > 0 ? remaining / Double(monthsLeft) : remaining
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current // local midnight, matching date-fns parseISO
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}

// MARK: - Add Funds sheet

private struct AddFundsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let goal: SavingsGoal
    let onAdd: (Double) -> Void

    @State private var amount = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter the amount you want to add to this savings goal.")
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount")
                        .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                    FCTextField("0.00", text: $amount, keyboardType: .decimalPad)
                }

                HStack(spacing: 8) {
                    FCButton(variant: .outline) {
                        Text("Cancel").frame(maxWidth: .infinity)
                    } action: {
                        dismiss()
                    }
                    FCButton {
                        Text("Add Funds").frame(maxWidth: .infinity)
                    } action: {
                        submit()
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add Funds to \(goal.name)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submit() {
        // Web requires a non-empty amount before adding.
        guard !amount.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onAdd(amount.calcValue)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let store = BudgetStore()
    store.goals = [
        SavingsGoal(
            id: "1",
            name: "New Car Fund",
            targetAmount: 20000,
            currentAmount: 6500,
            targetDate: "2026-12-31",
            monthlyContribution: 500
        ),
        SavingsGoal(
            id: "2",
            name: "Emergency Fund",
            targetAmount: 10000,
            currentAmount: 10000,
            targetDate: "2026-09-01",
            monthlyContribution: 0
        )
    ]
    return ScrollView {
        GoalsTabView()
            .environmentObject(store)
            .padding(16)
    }
    .background(Theme.background)
}
