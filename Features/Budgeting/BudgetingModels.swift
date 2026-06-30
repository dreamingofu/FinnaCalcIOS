//
//  BudgetingModels.swift
//  FinnaCalcIOS
//
//  Domain models for the Budget Planner, ported from app/budgeting/page.tsx.
//

import Foundation

enum BudgetType: String, Codable, CaseIterable, Identifiable {
    case personal, business
    var id: String { rawValue }
    var title: String { self == .personal ? "Personal" : "Business" }
}

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var title: String { self == .income ? "Income" : "Expense" }
}

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// convertToMonthly multipliers from the web (daily 30, weekly 4.33, monthly 1, yearly 1/12).
    var monthlyMultiplier: Double {
        switch self {
        case .daily: return 30
        case .weekly: return 4.33
        case .monthly: return 1
        case .yearly: return 1.0 / 12.0
        }
    }
}

struct BudgetItem: Identifiable, Codable, Equatable {
    var id: String
    var category: String
    var subcategory: String
    var amount: Double      // always positive
    var frequency: Frequency
    var type: ItemType
    var isFixed: Bool
    var budgetType: BudgetType
    var importDate: String?

    /// convertToMonthly(amount, frequency)
    var monthlyAmount: Double { amount * frequency.monthlyMultiplier }
}

struct SavingsGoal: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: String   // ISO yyyy-MM-dd
    var monthlyContribution: Double
}

struct BudgetHistoryEntry: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var startDate: String
    var endDate: String
    var budgetItems: [BudgetItem]
    var monthlyIncome: Double
    var monthlyExpenses: Double
    var monthlyNet: Double
    var budgetType: BudgetType
}

/// A category total used for charts and the budget-advisor snapshot.
struct CategorySlice: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let value: Double
}

/// Category options per the web `categories` lists.
enum BudgetCategories {
    static func income(_ type: BudgetType) -> [String] {
        switch type {
        case .personal: return ["Salary", "Freelance", "Investments", "Gift", "Other"]
        case .business: return ["Sales Revenue", "Service Revenue", "Subscriptions", "Interest Earned", "Other Fees", "Total Revenue", "Other Revenue"]
        }
    }
    static func expense(_ type: BudgetType) -> [String] {
        switch type {
        case .personal:
            return ["Housing", "Utilities", "Food", "Transportation", "Entertainment", "Healthcare", "Insurance", "Debt Payments", "Savings", "Retirement", "Other"]
        case .business:
            return ["Cost of Goods Sold (COGS)", "Salaries/Wages", "Marketing & Advertising", "Rent/Lease", "Utilities", "Software & Subscriptions", "Supplies", "Repairs & Maintenance", "Insurance", "Professional Fees", "Taxes", "Travel", "Depreciation", "Loan Payments", "Other Operating Costs"]
        }
    }
}
