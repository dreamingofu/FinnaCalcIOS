//
//  BudgetTabView.swift
//  FinnaCalcIOS
//
//  The "Budget" tab of the Budget Planner, ported from the `budget` TabsContent
//  in ../FinnaCalc/app/budgeting/page.tsx. Renders (1) the add/edit item form,
//  (2) a category-breakdown chart with an expense/income toggle, (3) the grouped
//  budget-items list with edit + delete, and (4) the budget-analysis feedback
//  cards (generateBudgetAnalysis, ported 1:1).
//
//  The KPI header and the personal/business toggle live in the container, not
//  here. The amber/orange hue the design system lacks is mapped to a local Color.
//

import SwiftUI
import Charts

struct BudgetTabView: View {
    @EnvironmentObject var store: BudgetStore

    // Add/edit form state (mirrors `newItem` / `editingItemId` in the web page).
    @State private var editingItemID: String? = nil
    @State private var formType: ItemType = .expense
    @State private var formCategory: String = ""
    @State private var formSubcategory: String = ""
    @State private var formAmount: String = ""
    @State private var formFrequency: Frequency = .monthly
    @State private var formIsFixed: Bool = false

    // Chart toggle (mirrors `chartView`).
    @State private var chartView: ItemType = .expense

    // amber/orange approximation for the "warning" feedback hue.
    private let amber = Color(red: 0.85, green: 0.55, blue: 0.05)

    var body: some View {
        VStack(spacing: 24) {
            formCard
            chartCard
            itemsCard
            analysisSection
        }
    }

    // MARK: - Helpers

    private var categories: [String] {
        formType == .income
            ? BudgetCategories.income(store.budgetType)
            : BudgetCategories.expense(store.budgetType)
    }

    private func money(_ value: Double) -> String {
        CalcFormat.currency(value, fraction: 2)
    }

    // MARK: - (1) Add / Edit form

    private var formCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle(editingItemID != nil ? "Edit Item" : "Add Income or Expense")
                FCCardDescription(
                    editingItemID != nil
                        ? "Update the details of your item below."
                        : "Track your financial inflows and outflows"
                )
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 16) {
                    // Type — segmented
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Type")
                        Picker("Type", selection: $formType) {
                            ForEach(ItemType.allCases) { t in
                                Text(t.title).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: formType) { _ in
                            // Web resets category whenever the type changes.
                            formCategory = ""
                        }
                    }

                    // Category + Frequency
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Category")
                        Picker("Category", selection: $formCategory) {
                            Text("Select category").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.input, lineWidth: 1)
                        )
                        .tint(Theme.foreground)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Frequency")
                        Picker("Frequency", selection: $formFrequency) {
                            ForEach(Frequency.allCases) { f in
                                Text(f.title).tag(f)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.input, lineWidth: 1)
                        )
                        .tint(Theme.foreground)
                    }

                    // Description (subcategory)
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Description")
                        FCTextField("e.g., Rent, Groceries, Netflix", text: $formSubcategory)
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Amount ($)")
                        FCTextField("0.00", text: $formAmount, keyboardType: .decimalPad)
                    }

                    // Fixed toggle
                    Toggle(isOn: $formIsFixed) {
                        Text("Fixed amount (doesn't vary month to month)")
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.foreground)
                    }
                    .tint(Theme.primary)

                    // Submit / cancel
                    HStack(spacing: 8) {
                        if editingItemID != nil {
                            FCButton(variant: .outline) {
                                Text("Cancel").frame(maxWidth: .infinity)
                            } action: { cancelEdit() }
                        }
                        FCButton {
                            Text(editingItemID != nil ? "Update Item" : "Add to Budget")
                                .frame(maxWidth: .infinity)
                        } action: { submit() }
                    }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
            .foregroundColor(Theme.foreground)
    }

    private func submit() {
        if let id = editingItemID {
            // Update existing item, preserving id/budgetType/importDate.
            if var existing = store.items.first(where: { $0.id == id }) {
                existing.category = formCategory
                existing.subcategory = formSubcategory
                existing.amount = formAmount.calcValue
                existing.frequency = formFrequency
                existing.type = formType
                existing.isFixed = formIsFixed
                store.updateItem(existing)
            }
            resetForm()
        } else {
            // Web requires both a category and an amount.
            guard !formCategory.isEmpty, !formAmount.isEmpty else { return }
            let item = BudgetItem(
                id: store.newItemID(),
                category: formCategory,
                subcategory: formSubcategory,
                amount: formAmount.calcValue,
                frequency: formFrequency,
                type: formType,
                isFixed: formIsFixed,
                budgetType: store.budgetType,
                importDate: nil
            )
            store.addItem(item)
            resetForm()
        }
    }

    private func beginEdit(_ item: BudgetItem) {
        editingItemID = item.id
        formType = item.type
        formCategory = item.category
        formSubcategory = item.subcategory
        formAmount = String(item.amount)
        formFrequency = item.frequency
        formIsFixed = item.isFixed
    }

    private func cancelEdit() { resetForm() }

    private func resetForm() {
        editingItemID = nil
        formType = .expense
        formCategory = ""
        formSubcategory = ""
        formAmount = ""
        formFrequency = .monthly
        formIsFixed = false
    }

    // MARK: - (2) Category breakdown chart

    private var chartData: [CategorySlice] {
        chartView == .expense ? store.expenseByCategory : store.incomeByCategory
    }

    private var chartCard: some View {
        FCCard {
            FCCardHeader {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        FCCardTitle(chartView == .expense ? "Expense Summary" : "Income Summary")
                        FCCardDescription(
                            "A visual breakdown of your monthly \(chartView == .expense ? "expense" : "income")s"
                        )
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 8) {
                        FCButton("Expenses", variant: chartView == .expense ? .default : .outline, size: .sm) {
                            chartView = .expense
                        }
                        FCButton("Income", variant: chartView == .income ? .default : .outline, size: .sm) {
                            chartView = .income
                        }
                    }
                }
            }
            FCCardContent {
                if chartData.isEmpty {
                    HStack {
                        Spacer()
                        Text(
                            chartView == .expense
                                ? "Your expense summary chart will appear here."
                                : "Your income summary chart will appear here."
                        )
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(minHeight: 250)
                } else {
                    Chart(chartData) { slice in
                        BarMark(
                            x: .value("Amount", slice.value),
                            y: .value("Category", slice.name)
                        )
                        .foregroundStyle(chartView == .expense ? Theme.negative : Theme.positive)
                        .annotation(position: .trailing) {
                            Text(money(slice.value))
                                .font(Theme.sans(Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(CalcFormat.currency(v, fraction: 0))
                                }
                            }
                        }
                    }
                    .frame(height: max(250, CGFloat(chartData.count) * 44))
                }
            }
        }
    }

    // MARK: - (3) Budget items list (grouped by category)

    /// Preserves category encounter order, like the web `reduce` over filtered items.
    private var groupedItems: [(category: String, items: [BudgetItem])] {
        var order: [String] = []
        var map: [String: [BudgetItem]] = [:]
        for item in store.currentItems {
            if map[item.category] == nil { order.append(item.category) }
            map[item.category, default: []].append(item)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private var itemsCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Budget Items (\(store.currentItems.count))")
                FCCardDescription("All your income and expenses for your \(store.budgetType.rawValue) budget")
            }
            FCCardContent {
                if groupedItems.isEmpty {
                    Text("No budget items yet. Add your first income or expense above!")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedItems, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.category)
                                    .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                                    .foregroundColor(Theme.foreground)
                                ForEach(group.items) { item in
                                    itemRow(item)
                                }
                                Divider().background(Theme.border)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: BudgetItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.subcategory.isEmpty ? "No description" : item.subcategory)
                    .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                    .foregroundColor(Theme.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.frequency.title)
                        .font(Theme.sans(Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                    if item.isFixed {
                        Text("\u{2022}")
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                        FCBadge("Fixed", variant: .secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.type == .income ? "+" : "-")\(money(item.amount))")
                    .font(Theme.sans(Theme.FontSize.sm, weight: .bold))
                    .foregroundColor(item.type == .income ? Theme.positive : Theme.negative)
                Text("\(money(item.monthlyAmount))/month")
                    .font(Theme.sans(Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            FCButton(variant: .ghost, size: .icon) {
                Image(systemName: "pencil")
            } action: { beginEdit(item) }
            FCButton(variant: .ghost, size: .icon) {
                Image(systemName: "trash")
                    .foregroundColor(Theme.destructive)
            } action: { store.deleteItem(item) }
        }
        .padding(12)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    // MARK: - (4) Budget analysis feedback

    private enum FeedbackKind { case success, warning, info, destructive }

    private struct Feedback: Identifiable {
        let id = UUID()
        let kind: FeedbackKind
        let title: String
        let message: String
        let systemImage: String
    }

    /// Ported 1:1 from generateBudgetAnalysis in app/budgeting/page.tsx.
    /// NOTE: this analysis defines its own savings rate as
    /// monthlyNet / monthlyIncome * 100 — distinct from the KPI's
    /// Savings/Retirement-only `store.savingsRate`.
    private var analysisFeedback: [Feedback] {
        let income = store.monthlyIncome
        let net = store.monthlyNet
        let pie = store.expenseByCategory
        var feedback: [Feedback] = []
        let savingsRate = income > 0 ? (net / income) * 100 : 0

        // 1. Net income / savings rate
        if net < 0 {
            feedback.append(Feedback(
                kind: .destructive,
                title: "Spending Alert!",
                message: "You are spending \(money(abs(net))) more than you earn each month. It's crucial to review your expenses to find areas for reduction.",
                systemImage: "exclamationmark.circle"
            ))
        } else if savingsRate < 10 {
            feedback.append(Feedback(
                kind: .warning,
                title: "Low Savings Rate",
                message: "Your current savings rate is \(CalcFormat.fixed(savingsRate, 1))%. While it's great you're in the positive, consider aiming for 10-20% to build a stronger financial future.",
                systemImage: "exclamationmark.circle"
            ))
        } else if savingsRate >= 10 && savingsRate <= 20 {
            feedback.append(Feedback(
                kind: .success,
                title: "Good Job!",
                message: "You're saving \(CalcFormat.fixed(savingsRate, 1))% of your income, which is a healthy amount. Keep up the great work!",
                systemImage: "hand.thumbsup"
            ))
        } else if savingsRate > 20 {
            feedback.append(Feedback(
                kind: .success,
                title: "Excellent Savings Rate!",
                message: "With a savings rate of \(CalcFormat.fixed(savingsRate, 1))%, you are on the fast track to achieving your financial goals. Consider channeling some of these extra funds towards investments.",
                systemImage: "rosette"
            ))
        }

        // 2. Top expense category
        if let topExpense = pie.max(by: { $0.value < $1.value }) {
            let pct = income > 0 ? (topExpense.value / income) * 100 : 0
            feedback.append(Feedback(
                kind: .info,
                title: "Top Expense Insight",
                message: "Your largest expense category is \"\(topExpense.name)\", making up \(CalcFormat.fixed(pct, 1))% of your total income. Reviewing this category could offer significant savings opportunities.",
                systemImage: "lightbulb"
            ))
        }

        // 3. Debt payments
        if let debtItem = store.currentItems.first(where: { $0.category == "Debt Payments" }) {
            let monthlyDebt = debtItem.monthlyAmount
            let dti = income > 0 ? (monthlyDebt / income) * 100 : 0
            if dti > 15 {
                feedback.append(Feedback(
                    kind: .warning,
                    title: "High Debt Payments",
                    message: "Your debt payments make up \(CalcFormat.fixed(dti, 1))% of your income. Consider strategies like the debt snowball or avalanche method to pay this down faster and free up cash flow.",
                    systemImage: "exclamationmark.circle"
                ))
            }
        }

        // 4. Savings goals mismatch
        let totalContributions = store.goals.reduce(0) { $0 + $1.monthlyContribution }
        if totalContributions > 0 && totalContributions > net {
            feedback.append(Feedback(
                kind: .warning,
                title: "Savings Goals Mismatch",
                message: "Your planned monthly savings contributions (\(money(totalContributions))) are higher than your current net income (\(money(net))). You may need to adjust your budget or goals to make them achievable.",
                systemImage: "exclamationmark.circle"
            ))
        }

        return feedback
    }

    @ViewBuilder
    private var analysisSection: some View {
        if !analysisFeedback.isEmpty {
            VStack(spacing: 12) {
                ForEach(analysisFeedback) { fb in
                    feedbackCard(fb)
                }
            }
        }
    }

    private func feedbackColor(_ kind: FeedbackKind) -> Color {
        switch kind {
        case .success:     return Theme.positive
        case .warning:     return amber
        case .info:        return Theme.primary
        case .destructive: return Theme.destructive
        }
    }

    private func feedbackCard(_ fb: Feedback) -> some View {
        let color = feedbackColor(fb.kind)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: fb.systemImage)
                .font(Theme.sans(Theme.FontSize.base))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(fb.title)
                    .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                    .foregroundColor(color)
                Text(fb.message)
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(color.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let store = BudgetStore()
    store.items = [
        BudgetItem(id: "1", category: "Salary", subcategory: "Day job", amount: 5000, frequency: .monthly, type: .income, isFixed: true, budgetType: .personal, importDate: nil),
        BudgetItem(id: "2", category: "Housing", subcategory: "Rent", amount: 1800, frequency: .monthly, type: .expense, isFixed: true, budgetType: .personal, importDate: nil),
        BudgetItem(id: "3", category: "Food", subcategory: "Groceries", amount: 120, frequency: .weekly, type: .expense, isFixed: false, budgetType: .personal, importDate: nil),
        BudgetItem(id: "4", category: "Debt Payments", subcategory: "Student loan", amount: 900, frequency: .monthly, type: .expense, isFixed: true, budgetType: .personal, importDate: nil),
    ]
    return ScrollView {
        BudgetTabView()
            .environmentObject(store)
            .padding(16)
    }
    .background(Theme.background)
}
