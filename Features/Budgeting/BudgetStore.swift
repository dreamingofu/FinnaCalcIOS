//
//  BudgetStore.swift
//  FinnaCalcIOS
//
//  Observable store for the Budget Planner: persistence (UserDefaults, the iOS
//  analogue of the web's localStorage), the budget math, CRUD, and the Plaid
//  transaction import. Ported from app/budgeting/page.tsx.
//

import Foundation
import SwiftUI

@MainActor
final class BudgetStore: ObservableObject {
    @Published var items: [BudgetItem] = [] { didSet { Self.persist(items, Keys.items) } }
    @Published var goals: [SavingsGoal] = [] { didSet { Self.persist(goals, Keys.goals) } }
    @Published var history: [BudgetHistoryEntry] = [] { didSet { Self.persist(history, Keys.history) } }
    @Published var budgetType: BudgetType = .personal

    private enum Keys {
        static let items = "finnacalc-budget-items"
        static let goals = "finnacalc-savings-goals"
        static let history = "finnacalc-budget-history"
    }

    init() {
        items = Self.load(Keys.items) ?? []
        goals = Self.load(Keys.goals) ?? []
        history = Self.load(Keys.history) ?? []
    }

    // MARK: Derived budget math (scoped to the active budgetType)

    var currentItems: [BudgetItem] { items.filter { $0.budgetType == budgetType } }

    var monthlyIncome: Double {
        currentItems.filter { $0.type == .income }.reduce(0) { $0 + $1.monthlyAmount }
    }
    var monthlyExpenses: Double {
        currentItems.filter { $0.type == .expense }.reduce(0) { $0 + $1.monthlyAmount }
    }
    var monthlyNet: Double { monthlyIncome - monthlyExpenses }

    /// Only "Savings"/"Retirement" expense categories count toward savings rate;
    /// nil when there's no income or no such contributions (matches the web).
    var savingsRate: Double? {
        let saved = currentItems
            .filter { $0.type == .expense && ($0.category == "Savings" || $0.category == "Retirement") }
            .reduce(0) { $0 + $1.monthlyAmount }
        guard monthlyIncome > 0, saved > 0 else { return nil }
        return saved / monthlyIncome * 100
    }

    var expenseByCategory: [CategorySlice] { grouped(.expense) }
    var incomeByCategory: [CategorySlice] { grouped(.income) }

    private func grouped(_ type: ItemType) -> [CategorySlice] {
        var totals: [String: Double] = [:]
        for item in currentItems where item.type == type {
            totals[item.category, default: 0] += item.monthlyAmount
        }
        return totals.map { CategorySlice(name: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    // MARK: CRUD

    func addItem(_ item: BudgetItem) { items.append(item) }

    func updateItem(_ item: BudgetItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
    }

    func deleteItem(_ item: BudgetItem) { items.removeAll { $0.id == item.id } }

    func newItemID() -> String { UUID().uuidString }

    func addGoal(_ goal: SavingsGoal) { goals.append(goal) }
    func deleteGoal(_ goal: SavingsGoal) { goals.removeAll { $0.id == goal.id } }
    func addFunds(to goal: SavingsGoal, amount: Double) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[i].currentAmount += amount
        }
    }

    // MARK: History snapshots

    func saveSnapshot(name: String, startDate: String, endDate: String) {
        let entry = BudgetHistoryEntry(
            id: UUID().uuidString,
            name: name,
            startDate: startDate,
            endDate: endDate,
            budgetItems: currentItems,
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            monthlyNet: monthlyNet,
            budgetType: budgetType
        )
        history.insert(entry, at: 0)
    }

    func deleteSnapshot(_ entry: BudgetHistoryEntry) { history.removeAll { $0.id == entry.id } }

    // MARK: Clear

    func clearBudgetItems() { items.removeAll() }
    func clearAll() {
        items.removeAll(); goals.removeAll(); history.removeAll()
    }

    // MARK: Plaid import

    /// Maps a Plaid personal_finance_category primary to a budget category
    /// (ported 1:1 from mapPlaidCategory in app/budgeting/page.tsx).
    func mapPlaidCategory(_ primary: String, type: ItemType) -> String {
        if type == .income {
            if budgetType == .business { return "Other Revenue" }
            let isIncome = primary.range(of: "INCOME|PAYROLL|DEPOSIT", options: .regularExpression) != nil
            return isIncome ? "Salary" : "Other"
        }
        if budgetType == .business { return "Other Operating Costs" }
        let map: [String: String] = [
            "FOOD_AND_DRINK": "Food",
            "RENT_AND_UTILITIES": "Housing",
            "TRANSPORTATION": "Transportation",
            "TRAVEL": "Transportation",
            "ENTERTAINMENT": "Entertainment",
            "MEDICAL": "Healthcare",
            "LOAN_PAYMENTS": "Debt Payments",
            "INSURANCE": "Insurance",
        ]
        return map[primary] ?? "Other"
    }

    /// Import Plaid transactions as a HISTORY SNAPSHOT only — like the web's
    /// handlePlaidImport, which never mutates the live budget. The snapshot holds
    /// only the imported items, with import-derived totals.
    /// Plaid: positive amount = money out (expense), negative = money in (income).
    func importPlaidTransactions(_ transactions: [BankTransaction], snapshotName: String = "Bank Import (Plaid)") {
        guard !transactions.isEmpty else { return }
        var imported: [BudgetItem] = []
        for txn in transactions {
            let type: ItemType = txn.amount > 0 ? .expense : .income
            imported.append(BudgetItem(
                id: UUID().uuidString,
                category: mapPlaidCategory(txn.category, type: type),
                subcategory: txn.name,
                amount: abs(txn.amount),
                frequency: .monthly,
                type: type,
                isFixed: false,
                budgetType: budgetType,
                importDate: txn.date
            ))
        }
        // Import-only totals (frequency is monthly so monthlyAmount == amount).
        let totalIncome = imported.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let totalExpenses = imported.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let dates = transactions.map(\.date).sorted()
        let entry = BudgetHistoryEntry(
            id: UUID().uuidString,
            name: snapshotName,
            startDate: dates.first ?? "",
            endDate: dates.last ?? "",
            budgetItems: imported,
            monthlyIncome: totalIncome,
            monthlyExpenses: totalExpenses,
            monthlyNet: totalIncome - totalExpenses,
            budgetType: budgetType
        )
        history.insert(entry, at: 0)
    }

    // MARK: Persistence

    private static func persist<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
